"""Task 2 — 방문 가치 스코어 (0~100) 산출.

가중합산 방식:
  최종 = 0.40*혼잡 + 0.30*날씨 + 0.20*요일 + 0.10*할인
0~100으로 clamp.
"""

from __future__ import annotations

from typing import Literal, TypedDict

CrowdLevel = Literal["상", "중", "하"]
WeatherCond = Literal["맑음", "흐림", "소나기", "강우"]

WEIGHTS = {"crowd": 0.40, "weather": 0.30, "day": 0.20, "discount": 0.10}

_CROWD_SCORES: dict[str, int] = {"하": 100, "중": 60, "상": 20}
_WEATHER_SCORES: dict[str, int] = {"맑음": 100, "흐림": 70, "소나기": 40, "강우": 20}


class ScoreBreakdown(TypedDict):
    crowd: float
    weather: float
    day: float
    discount: float


class ScoreResult(TypedDict):
    score: int
    breakdown: ScoreBreakdown
    inputs: dict


def _crowd_score(level: CrowdLevel) -> int:
    if level not in _CROWD_SCORES:
        raise ValueError(f"unknown crowd_level: {level!r}")
    return _CROWD_SCORES[level]


def _weather_score(cond: WeatherCond) -> int:
    if cond not in _WEATHER_SCORES:
        raise ValueError(f"unknown weather: {cond!r}")
    return _WEATHER_SCORES[cond]


def _day_score(weekday: int, is_holiday: bool) -> int:
    """weekday: Monday=0 ... Sunday=6."""
    if is_holiday or weekday == 6:
        return 30
    if weekday == 5:
        return 60
    return 100


def _discount_score(pct: float) -> float:
    """할인율(%) × 2, 최대 50점."""
    return min(max(float(pct), 0.0) * 2.0, 50.0)


def calc_visit_value(
    crowd_level: CrowdLevel,
    weather: WeatherCond,
    weekday: int,
    is_holiday: bool,
    discount_pct: float,
) -> ScoreResult:
    parts = {
        "crowd": _crowd_score(crowd_level),
        "weather": _weather_score(weather),
        "day": _day_score(weekday, is_holiday),
        "discount": _discount_score(discount_pct),
    }
    raw = sum(parts[k] * WEIGHTS[k] for k in parts)
    score = int(round(max(0.0, min(100.0, raw))))

    return ScoreResult(
        score=score,
        breakdown=ScoreBreakdown(**{k: round(parts[k] * WEIGHTS[k], 2) for k in parts}),
        inputs={
            "crowd_level": crowd_level,
            "weather": weather,
            "weekday": weekday,
            "is_holiday": is_holiday,
            "discount_pct": discount_pct,
        },
    )
