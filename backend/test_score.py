"""backend/score.py 단위 테스트."""

from __future__ import annotations

import pytest

from . import score


def test_perfect_score_low_crowd_sunny_weekday_high_discount():
    """이상적 조건: 한산 + 맑음 + 평일 + 25% 할인 → 90+ 점."""
    r = score.calc_visit_value(
        crowd_level="하", weather="맑음", weekday=2,
        is_holiday=False, discount_pct=25,
    )
    assert r["score"] >= 90


def test_worst_score_high_crowd_rainy_holiday_no_discount():
    """최악 조건: 상 + 강우 + 공휴일 + 0% 할인 → 30점 이하."""
    r = score.calc_visit_value(
        crowd_level="상", weather="강우", weekday=6,
        is_holiday=True, discount_pct=0,
    )
    assert r["score"] <= 30


def test_score_in_valid_range():
    """모든 조합에서 0~100 사이."""
    for crowd in ("상", "중", "하"):
        for weather in ("맑음", "흐림", "소나기", "강우"):
            for wd in range(7):
                for hol in (True, False):
                    for disc in (0, 10, 25, 50):
                        r = score.calc_visit_value(
                            crowd_level=crowd, weather=weather, weekday=wd,
                            is_holiday=hol, discount_pct=disc,
                        )
                        assert 0 <= r["score"] <= 100


def test_breakdown_keys():
    """breakdown 에 crowd/weather/day/discount 4개 키 모두 존재."""
    r = score.calc_visit_value(
        crowd_level="중", weather="흐림", weekday=2,
        is_holiday=False, discount_pct=10,
    )
    assert set(r["breakdown"].keys()) == {"crowd", "weather", "day", "discount"}


def test_breakdown_sums_to_score():
    """breakdown 4개 합 ≈ score (반올림 오차 1 이내)."""
    r = score.calc_visit_value(
        crowd_level="하", weather="맑음", weekday=1,
        is_holiday=False, discount_pct=15,
    )
    bd_sum = sum(r["breakdown"].values())
    assert abs(bd_sum - r["score"]) <= 1


def test_holiday_lowers_day_score():
    """공휴일은 평일보다 day 점수 낮음 (혼잡 ↑)."""
    weekday = score.calc_visit_value(
        crowd_level="중", weather="맑음", weekday=2,
        is_holiday=False, discount_pct=0,
    )
    holiday = score.calc_visit_value(
        crowd_level="중", weather="맑음", weekday=2,
        is_holiday=True, discount_pct=0,
    )
    assert holiday["breakdown"]["day"] < weekday["breakdown"]["day"]


def test_sunday_treated_as_holiday():
    """일요일(weekday=6) 도 30점 처리."""
    sun = score.calc_visit_value(
        crowd_level="중", weather="맑음", weekday=6,
        is_holiday=False, discount_pct=0,
    )
    sat = score.calc_visit_value(
        crowd_level="중", weather="맑음", weekday=5,
        is_holiday=False, discount_pct=0,
    )
    assert sun["breakdown"]["day"] < sat["breakdown"]["day"]


def test_discount_score_capped_at_50():
    """할인 점수는 50점 cap (할인 25%×2 가 cap)."""
    r_25 = score.calc_visit_value(
        crowd_level="중", weather="맑음", weekday=2,
        is_holiday=False, discount_pct=25,
    )
    r_60 = score.calc_visit_value(
        crowd_level="중", weather="맑음", weekday=2,
        is_holiday=False, discount_pct=60,
    )
    # 가중치 0.1 × 50(cap) = 5 가 최대
    assert r_25["breakdown"]["discount"] == r_60["breakdown"]["discount"]
    assert r_25["breakdown"]["discount"] == 5.0


@pytest.mark.parametrize(
    "bad_field, kwargs",
    [
        ("crowd_level", {"crowd_level": "엄청혼잡"}),
        ("weather", {"weather": "눈"}),
    ],
)
def test_invalid_input_raises(bad_field, kwargs):
    defaults = {
        "crowd_level": "중", "weather": "맑음", "weekday": 2,
        "is_holiday": False, "discount_pct": 0,
    }
    defaults.update(kwargs)
    with pytest.raises(ValueError):
        score.calc_visit_value(**defaults)
