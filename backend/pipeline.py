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

    disc = _discount.calc_discount(pred.crowd_level, fcst.rain_prob)
    sc = score.calc_visit_value(
        crowd_level=pred.crowd_level,
        weather=fcst.weather,
        weekday=target_date.weekday(),
        is_holiday=_is_holiday(target_date),
        discount_pct=disc["discount_pct"],
    )

    should_push = pred.crowd_level == "하" or fcst.rain_prob >= 50.0
    reason_parts = []
    if pred.crowd_level == "하":
        reason_parts.append("혼잡도 하")
    if fcst.rain_prob >= 50.0:
        reason_parts.append(f"강수확률 {fcst.rain_prob:.0f}%")
    push_reason = " + ".join(reason_parts) if reason_parts else "조건 미충족"

    pushed = False
    if should_push:
        title = "오늘 서울랜드, 한산해요" if target == "today" else "내일 서울랜드, 한산해요"
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
