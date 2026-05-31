"""Task 1 — 혼잡도 등급(상/중/하) 기반 할인율 산출.

요일·공휴일·날씨는 이미 XGBoost 모델 입력에서 혼잡도 등급에 반영되므로,
할인율 매핑은 혼잡도 등급에만 의존한다. 혼잡도 하 구간에서만 강수확률을
세분화 인자로 추가 반영한다.
"""

from typing import Literal, TypedDict

CrowdLevel = Literal["상", "중", "하"]


class DiscountResult(TypedDict):
    crowd_level: CrowdLevel
    rain_prob: float
    discount_pct: int
    reason: str


def calc_discount(crowd_level: CrowdLevel, rain_prob: float = 0.0) -> DiscountResult:
    """혼잡도 등급 + 강수확률 → 할인율(%)."""
    rain_prob = max(0.0, min(100.0, float(rain_prob)))

    if crowd_level == "상":
        pct, reason = 0, "성수기·피크 — 할인 없음"
    elif crowd_level == "중":
        if rain_prob >= 50:
            pct, reason = 15, "보통 혼잡 + 강수 우려"
        else:
            pct, reason = 10, "보통 혼잡"
    elif crowd_level == "하":
        if rain_prob >= 70:
            pct, reason = 25, "한산 + 강한 강수"
        elif rain_prob >= 50:
            pct, reason = 22, "한산 + 강수 우려"
        elif rain_prob >= 30:
            pct, reason = 18, "한산 + 약한 강수"
        else:
            pct, reason = 15, "한산"
    else:
        raise ValueError(f"unknown crowd_level: {crowd_level!r}")

    return DiscountResult(
        crowd_level=crowd_level,
        rain_prob=rain_prob,
        discount_pct=pct,
        reason=reason,
    )
