"""Task 1 — 혼잡도 등급(상/중/하) + 다양한 기상 변수 기반 할인율 산출.

혼잡도 등급은 XGBoost 모델이 요일·공휴일·날씨를 모두 반영해서 산출.
할인은 추가로 시점 기상 신호 (비/눈/폭염/한파/강풍) 마다 세분화 가산.

기본 정책:
  상 → 0% (성수기 피크 — 어차피 사람 많아서 할인 의미 없음)
  중 → 10% baseline + 강수/극한 시 +5
  하 → 15% baseline + 강수 단계별 + 극한 가산 (최대 25% 캡)
"""

from typing import Literal, TypedDict

CrowdLevel = Literal["상", "중", "하"]


class DiscountResult(TypedDict):
    crowd_level: CrowdLevel
    rain_prob: float
    discount_pct: int
    reason: str


def calc_discount(
    crowd_level: CrowdLevel,
    rain_prob: float = 0.0,
    *,
    temp_max: float | None = None,
    temp_min: float | None = None,
    wind_speed_max: float | None = None,
    snow_max: float | None = None,
    pty_max: int | None = None,
) -> DiscountResult:
    """혼잡도 등급 + 다중 기상 변수 → 할인율(%).

    추가 변수 (모두 옵션 — None 이면 무시):
      temp_max: 일 최고기온 (°C) — ≥33 폭염
      temp_min: 일 최저기온 (°C) — ≤-10 한파
      wind_speed_max: 일 최대 풍속 (m/s) — ≥14 강풍
      snow_max: 일 적설량 (cm) — ≥5 폭설
      pty_max: 강수형태 코드 (2/3 이면 눈/진눈깨비)

    할인율은 25% 캡.
    """
    rain_prob = max(0.0, min(100.0, float(rain_prob)))

    if crowd_level == "상":
        return DiscountResult(
            crowd_level=crowd_level,
            rain_prob=rain_prob,
            discount_pct=0,
            reason="성수기·피크 — 할인 없음",
        )

    # 극한 기상 판정 (둘 이상이면 안전 우선순위 1개만 reason 으로)
    heat_wave = temp_max is not None and temp_max >= 33
    cold_wave = temp_min is not None and temp_min <= -10
    heavy_snow = (snow_max is not None and snow_max >= 5) or (
        pty_max in (2, 3) and snow_max is not None and snow_max > 0
    )
    strong_wind = wind_speed_max is not None and wind_speed_max >= 14

    extreme_reason: str | None = None
    extreme_bonus = 0
    if heavy_snow:
        extreme_reason, extreme_bonus = "폭설 안전 알림", 5
    elif strong_wind:
        extreme_reason, extreme_bonus = "강풍 — 일부 어트랙션 중단 가능", 3
    elif heat_wave:
        extreme_reason, extreme_bonus = "폭염 — 실내 위주 권장", 5
    elif cold_wave:
        extreme_reason, extreme_bonus = "한파 — 실내·휴식 자주", 4

    # baseline + 강수 단계
    if crowd_level == "중":
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

    # 극한 보너스 가산 (캡 25%) + reason 우선순위
    if extreme_reason:
        pct = min(25, pct + extreme_bonus)
        reason = f"{reason} · {extreme_reason}"

    return DiscountResult(
        crowd_level=crowd_level,
        rain_prob=rain_prob,
        discount_pct=pct,
        reason=reason,
    )
