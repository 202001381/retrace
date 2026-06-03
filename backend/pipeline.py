"""기상청 → XGBoost → FCM 자동화 파이프라인.

매일 두 번 실행:
  - 전날 22:00: 다음날(target=tomorrow) 예보 기반 알림
  - 당일 07:00: 당일(target=today) 예보 기반 알림
"""

from __future__ import annotations

import logging
from dataclasses import asdict, dataclass
from datetime import date, datetime, timedelta, timezone
from typing import Literal

from . import discount as _discount
from . import fcm, predictor, score, weather

logger = logging.getLogger(__name__)
KST = timezone(timedelta(hours=9))


@dataclass
class PipelineResult:
    target_date: str
    crowd_level: str
    visitor_count: float
    discount_pct: int
    score: int
    rain_prob: float
    weather: str
    pushed: bool
    push_reason: str

    def to_dict(self) -> dict:
        return asdict(self)


def _is_holiday(d: date) -> bool:
    # MVP: 단순 일요일 체크. 공휴일 캘린더는 KASI 특일정보 API 추후 통합.
    return d.weekday() == 6


def _representative_hour() -> int:
    """입장객 시간대 피처 — 보고서 §2.2: 오전 11시~정오 피크. 12 로 고정."""
    return 12


def _pre_sales_stub(target: date) -> int:
    """입장권 사전 판매량 — Firestore 또는 운영 DB에서 가져올 필요. 임시 0."""
    return 0


def run_pipeline(target: Literal["today", "tomorrow"]) -> PipelineResult:
    now = datetime.now(KST)
    target_date = now.date() if target == "today" else now.date() + timedelta(days=1)

    fcst = weather.fetch_forecast(target_date, now=now)

    features = {
        "hour": _representative_hour(),
        "weekday": target_date.weekday(),
        "is_holiday": int(_is_holiday(target_date)),
        "temp": fcst.temp_noon,
        "rain_prob": fcst.rain_prob,
        "is_event": 0,
        "pre_sales": _pre_sales_stub(target_date),
    }
    pred = predictor.predict_one(features)

    disc = _discount.calc_discount(
        pred.crowd_level,
        fcst.rain_prob,
        temp_max=fcst.temp_max,
        temp_min=fcst.temp_min,
        wind_speed_max=fcst.wind_speed_max,
        snow_max=fcst.snow_max,
        pty_max=fcst.pty_max,
    )
    sc = score.calc_visit_value(
        crowd_level=pred.crowd_level,
        weather=fcst.weather,
        weekday=target_date.weekday(),
        is_holiday=_is_holiday(target_date),
        discount_pct=disc["discount_pct"],
    )

    # push 조건: 한산 OR 강수 우려 OR 극한 기상 (안전 알림)
    should_push = (
        pred.crowd_level == "하"
        or fcst.rain_prob >= 50.0
        or fcst.is_extreme
    )
    reason_parts = []
    if pred.crowd_level == "하":
        reason_parts.append("혼잡도 하")
    if fcst.rain_prob >= 50.0:
        reason_parts.append(f"강수확률 {fcst.rain_prob:.0f}%")
    if fcst.is_extreme:
        reason_parts.append(f"기상특보({fcst.weather})")
    push_reason = " + ".join(reason_parts) if reason_parts else "조건 미충족"

    pushed = False
    if should_push:
        # 극한 기상은 안전 알림 톤, 나머지는 추천 톤
        if fcst.is_extreme:
            title_map = {
                "폭염": "오늘 폭염주의 — 실내 어트랙션 추천",
                "한파": "오늘 한파주의 — 따뜻하게 입고 오세요",
                "폭설": "오늘 폭설 — 안전 운영 안내",
                "강풍": "오늘 강풍 — 일부 어트랙션 운영 변경",
            }
            base = title_map.get(fcst.weather, f"오늘 {fcst.weather} 주의")
            title = base if target == "today" else base.replace("오늘", "내일")
        elif target == "today":
            title = "오늘 서울랜드, 한산해요"
        else:
            title = "내일 서울랜드, 한산해요"
        body = (
            f"방문 가치 {sc['score']}점 | {disc['discount_pct']}% 할인 쿠폰 발급됨"
        )
        try:
            fcm.send_topic(
                title=title,
                body=body,
                data={
                    "target_date": target_date.isoformat(),
                    "crowd_level": pred.crowd_level,
                    "discount_pct": str(disc["discount_pct"]),
                    "score": str(sc["score"]),
                    "weather": fcst.weather,
                    "rain_prob": f"{fcst.rain_prob:.0f}",
                    "temp_max": f"{fcst.temp_max:.1f}",
                    "temp_min": f"{fcst.temp_min:.1f}",
                    "wind_speed_max": f"{fcst.wind_speed_max:.1f}",
                    "snow_max": f"{fcst.snow_max:.1f}",
                    "is_extreme": str(fcst.is_extreme).lower(),
                    "reason": push_reason,
                },
            )
            pushed = True
        except Exception:
            logger.exception("FCM send failed")

    result = PipelineResult(
        target_date=target_date.isoformat(),
        crowd_level=pred.crowd_level,
        visitor_count=round(pred.visitor_count, 1),
        discount_pct=disc["discount_pct"],
        score=sc["score"],
        rain_prob=fcst.rain_prob,
        weather=fcst.weather,
        pushed=pushed,
        push_reason=push_reason,
    )
    logger.info("pipeline %s result: %s", target, result.to_dict())
    return result
