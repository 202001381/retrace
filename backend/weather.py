"""기상청 동네예보(VilageFcst) API 클라이언트.

서울랜드 위치(과천, nx=60 ny=120) 기준으로 당일/내일 예보 조회.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date, datetime, timedelta, timezone
from typing import Literal

import requests

from . import config

KST = timezone(timedelta(hours=9))

# 발표 시각(매일 8회). 발표 후 약 10분부터 조회 가능.
_BASE_TIMES = [200, 500, 800, 1100, 1400, 1700, 2000, 2300]

WeatherCondition = Literal["맑음", "흐림", "소나기", "강우", "폭염", "한파", "폭설", "강풍"]


@dataclass(frozen=True)
class DailyForecast:
    target_date: date
    rain_prob: float       # POP — 그날 시간대별 강수확률 최대값 (%)
    temp_noon: float       # TMP — 정오 기온 (°C)
    temp_max: float        # TMX — 일 최고기온 (°C, 폭염 판정용)
    temp_min: float        # TMN — 일 최저기온 (°C, 한파 판정용)
    sky_code: int          # SKY — 정오 (1 맑음, 3 구름많음, 4 흐림)
    pty_max: int           # PTY — 강수형태 최대 (0 없음, 1 비, 2 비/눈, 3 눈, 4 소나기)
    wind_speed_max: float  # WSD — 일 최대 풍속 (m/s, 강풍 판정용)
    humidity_noon: float   # REH — 정오 습도 (%, 체감온도용)
    snow_max: float        # SNO — 일 적설량 최대 (cm, 폭설 판정용)

    @property
    def weather(self) -> WeatherCondition:
        """시점 가장 두드러진 기상 라벨 — 안전·UX 우선순위.

        극한 기상 → 강수 → 일반 분류.
        """
        # 1순위: 안전 위험 (체감·이동 영향)
        if self.snow_max >= 5 or (self.pty_max in (2, 3) and self.snow_max > 0):
            return "폭설"
        if self.wind_speed_max >= 14:
            return "강풍"
        if self.temp_max >= 33:
            return "폭염"
        if self.temp_min <= -10:
            return "한파"
        # 2순위: 강수
        if self.pty_max == 4:
            return "소나기"
        if self.pty_max in (1, 2, 3):
            return "강우"
        # 3순위: 일반
        if self.sky_code == 1:
            return "맑음"
        return "흐림"

    @property
    def is_extreme(self) -> bool:
        """극한 기상 — push 우선순위 + 할인 가산 트리거."""
        return self.weather in ("폭염", "한파", "폭설", "강풍")

    @property
    def heat_index(self) -> float:
        """단순 체감온도 추정 — temp + humidity 보정 (Steadman 근사).

        습도 60%+ 일 때 1.2배 가중, 그 아래는 평탄.
        """
        if self.humidity_noon >= 60:
            return self.temp_noon + (self.humidity_noon - 60) * 0.15
        return self.temp_noon


def _latest_base(now: datetime) -> tuple[str, str]:
    """now 기준 가장 최근 발표 시각의 (base_date, base_time)."""
    cur = now.hour * 100 + now.minute
    available = [b for b in _BASE_TIMES if b + 10 <= cur]  # 발표 +10분 이후 사용 가능
    if available:
        bt = max(available)
        return now.strftime("%Y%m%d"), f"{bt:04d}"
    yesterday = now - timedelta(days=1)
    return yesterday.strftime("%Y%m%d"), f"{_BASE_TIMES[-1]:04d}"


def _fetch_rows(now: datetime | None = None) -> list[dict]:
    if not config.KMA_SERVICE_KEY:
        raise RuntimeError("KMA_SERVICE_KEY env var is not set")

    now = now or datetime.now(KST)
    base_date, base_time = _latest_base(now)

    params = {
        "serviceKey": config.KMA_SERVICE_KEY,
        "pageNo": 1,
        "numOfRows": 1000,
        "dataType": "JSON",
        "base_date": base_date,
        "base_time": base_time,
        "nx": config.SEOULLAND_NX,
        "ny": config.SEOULLAND_NY,
    }
    with requests.get(
        config.KMA_VILAGE_FCST_URL, params=params, timeout=15
    ) as resp:
        resp.raise_for_status()
        body = resp.json().get("response", {}).get("body", {})
    items = body.get("items", {}).get("item", [])
    if not items:
        raise RuntimeError(f"KMA returned no items (base={base_date}/{base_time})")
    return items


def fetch_forecast(target: date, now: datetime | None = None) -> DailyForecast:
    """특정 날짜(target)의 예보를 집계해 반환."""
    rows = _fetch_rows(now)
    ymd = target.strftime("%Y%m%d")
    same_day = [r for r in rows if r.get("fcstDate") == ymd]
    if not same_day:
        raise RuntimeError(f"no forecast rows for {ymd}")

    def _vals(category: str) -> list[float]:
        out = []
        for r in same_day:
            if r.get("category") != category:
                continue
            try:
                out.append(float(r["fcstValue"]))
            except (TypeError, ValueError):
                continue
        return out

    def _at_noon(category: str) -> float | None:
        for r in same_day:
            if r.get("category") == category and r.get("fcstTime") == "1200":
                try:
                    return float(r["fcstValue"])
                except (TypeError, ValueError):
                    return None
        return None

    pop = _vals("POP")
    pty = _vals("PTY")
    sky = _at_noon("SKY") or 1
    temp = _at_noon("TMP")
    if temp is None:
        tmps = _vals("TMP")
        temp = sum(tmps) / len(tmps) if tmps else 0.0

    tmn_vals = _vals("TMN")
    tmx_vals = _vals("TMX")
    wsd_vals = _vals("WSD")
    sno_vals = _vals("SNO")
    reh_noon = _at_noon("REH") or 50.0
    tmps_all = _vals("TMP")

    return DailyForecast(
        target_date=target,
        rain_prob=max(pop) if pop else 0.0,
        temp_noon=float(temp),
        temp_max=max(tmx_vals) if tmx_vals else (max(tmps_all) if tmps_all else float(temp)),
        temp_min=min(tmn_vals) if tmn_vals else (min(tmps_all) if tmps_all else float(temp)),
        sky_code=int(sky),
        pty_max=int(max(pty)) if pty else 0,
        wind_speed_max=max(wsd_vals) if wsd_vals else 0.0,
        humidity_noon=float(reh_noon),
        snow_max=max(sno_vals) if sno_vals else 0.0,
    )


def fetch_today(now: datetime | None = None) -> DailyForecast:
    now = now or datetime.now(KST)
    return fetch_forecast(now.date(), now)


def fetch_tomorrow(now: datetime | None = None) -> DailyForecast:
    now = now or datetime.now(KST)
    return fetch_forecast(now.date() + timedelta(days=1), now)
