"""backend/predictor.py 단위 테스트 — 학습된 stub 모델 기반.

artifacts/crowd_model.pkl 이 있어야 통과. 없으면 `python backend/train_stub.py` 먼저.
"""

from __future__ import annotations

import pytest

from . import config, predictor


def _trained_model_available() -> bool:
    return config.MODEL_PATH.exists()


pytestmark = pytest.mark.skipif(
    not _trained_model_available(),
    reason="artifacts/crowd_model.pkl missing — run backend/train_stub.py first",
)


# ── to_crowd_level (모델 없이 동작하는 순수 함수) ──────────────
@pytest.mark.parametrize(
    "vc, expected",
    [
        (0, "하"),
        (1000, "하"),
        (2500, "하"),       # low_max
        (2501, "중"),
        (5500, "중"),       # mid_max
        (5501, "상"),
        (15000, "상"),
    ],
)
def test_to_crowd_level_thresholds(vc, expected):
    assert predictor.to_crowd_level(vc) == expected


# ── predict_one ────────────────────────────────────────────
def test_predict_one_returns_valid_prediction():
    features = {
        "hour": 14, "weekday": 2, "is_holiday": 0, "temp": 22,
        "rain_prob": 30, "is_event": 0, "pre_sales": 1000,
    }
    pred = predictor.predict_one(features)
    assert pred.visitor_count >= 0
    assert pred.crowd_level in {"상", "중", "하"}


def test_weekday_rainy_predicts_low_crowd():
    """평일 + 추운 날 + 강수 80% → 하 등급."""
    features = {
        "hour": 11, "weekday": 1, "is_holiday": 0, "temp": 3,
        "rain_prob": 85, "is_event": 0, "pre_sales": 50,
    }
    pred = predictor.predict_one(features)
    assert pred.crowd_level == "하", f"got {pred.crowd_level} (vc={pred.visitor_count:.0f})"


def test_weekend_sunny_event_predicts_high_crowd():
    """주말 + 맑음 + 이벤트 + 사전판매 많음 → 상 등급."""
    features = {
        "hour": 14, "weekday": 6, "is_holiday": 0, "temp": 22,
        "rain_prob": 5, "is_event": 1, "pre_sales": 3000,
    }
    pred = predictor.predict_one(features)
    assert pred.crowd_level == "상", f"got {pred.crowd_level} (vc={pred.visitor_count:.0f})"


def test_predict_batch_matches_predict_one():
    features = [
        {"hour": 14, "weekday": 6, "is_holiday": 0, "temp": 22,
         "rain_prob": 5, "is_event": 1, "pre_sales": 2500},
        {"hour": 11, "weekday": 2, "is_holiday": 0, "temp": 5,
         "rain_prob": 80, "is_event": 0, "pre_sales": 100},
    ]
    batch = predictor.predict_batch(features)
    singles = [predictor.predict_one(f) for f in features]
    for b, s in zip(batch, singles):
        assert abs(b.visitor_count - s.visitor_count) < 0.01
        assert b.crowd_level == s.crowd_level


def test_visitor_count_is_non_negative():
    """모델이 음수 예측해도 max(0, ·) 로 보호."""
    features = {
        "hour": 18, "weekday": 1, "is_holiday": 0, "temp": -5,
        "rain_prob": 100, "is_event": 0, "pre_sales": 0,
    }
    pred = predictor.predict_one(features)
    assert pred.visitor_count >= 0
