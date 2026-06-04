"""backend/pipeline.py 단위 테스트 — 외부 의존(weather/predictor/fcm) mock.

핵심 검증:
- 파이프라인 흐름: weather.fetch_forecast → predictor.predict_one → discount/score → fcm.send_topic
- 발송 조건: crowd_level == "하" OR rain_prob >= 50
"""

from __future__ import annotations

from datetime import date, timedelta
from unittest.mock import patch

import pytest

from . import pipeline
from .predictor import Prediction
from .weather import DailyForecast


def _forecast(rain: float = 20.0, sky: int = 1, pty: int = 0, temp: float = 20.0,
              temp_max: float | None = None, temp_min: float | None = None,
              wind: float = 3.0, snow: float = 0.0, humidity: float = 50.0) -> DailyForecast:
    return DailyForecast(
        target_date=date.today() + timedelta(days=1),
        rain_prob=rain,
        temp_noon=temp,
        temp_max=temp_max if temp_max is not None else temp + 5,
        temp_min=temp_min if temp_min is not None else temp - 5,
        sky_code=sky,
        pty_max=pty,
        wind_speed_max=wind,
        humidity_noon=humidity,
        snow_max=snow,
    )


def _run_with_mocks(forecast: DailyForecast, prediction: Prediction):
    """공통 mock — weather/predictor/fcm 외부 의존 차단."""
    with patch("backend.pipeline.weather.fetch_forecast", return_value=forecast), \
         patch("backend.pipeline.predictor.predict_one", return_value=prediction), \
         patch("backend.pipeline.fcm.send_topic", return_value="mock-message-id") as mock_send:
        result = pipeline.run_pipeline("tomorrow")
    return result, mock_send


def test_low_crowd_triggers_fcm():
    """하 등급 + 강수 적음 → FCM 발송."""
    result, mock_send = _run_with_mocks(
        _forecast(rain=20),
        Prediction(visitor_count=1200, crowd_level="하"),
    )
    d = result.to_dict()
    assert d["crowd_level"] == "하"
    assert d["pushed"] is True
    assert d["discount_pct"] == 15
    mock_send.assert_called_once()


def test_high_crowd_no_rain_skips_fcm():
    """상 등급 + 강수 적음 → FCM 발송 안 함."""
    result, mock_send = _run_with_mocks(
        _forecast(rain=5),
        Prediction(visitor_count=8000, crowd_level="상"),
    )
    d = result.to_dict()
    assert d["crowd_level"] == "상"
    assert d["pushed"] is False
    assert d["discount_pct"] == 0
    mock_send.assert_not_called()


def test_high_crowd_rainy_triggers_fcm():
    """상 등급이라도 강수 50%+ 면 발송."""
    result, mock_send = _run_with_mocks(
        _forecast(rain=80, pty=1),
        Prediction(visitor_count=7500, crowd_level="상"),
    )
    d = result.to_dict()
    assert d["pushed"] is True
    assert "강수확률" in d["push_reason"]
    mock_send.assert_called_once()


def test_mid_crowd_rainy_triggers_fcm():
    """중 등급 + 강수 50%+ → 발송."""
    result, mock_send = _run_with_mocks(
        _forecast(rain=70),
        Prediction(visitor_count=4000, crowd_level="중"),
    )
    d = result.to_dict()
    assert d["pushed"] is True
    mock_send.assert_called_once()


def test_push_reason_mentions_low_crowd():
    """발송 사유에 '혼잡도 하' 라벨 포함."""
    result, _ = _run_with_mocks(
        _forecast(rain=10),
        Prediction(visitor_count=1000, crowd_level="하"),
    )
    assert "혼잡도 하" in result.to_dict()["push_reason"]


def test_push_reason_combines_low_and_rainy():
    """하 등급 + 강수 50%+ → 두 사유 모두 표기."""
    result, _ = _run_with_mocks(
        _forecast(rain=70),
        Prediction(visitor_count=1000, crowd_level="하"),
    )
    reason = result.to_dict()["push_reason"]
    assert "혼잡도 하" in reason
    assert "강수확률" in reason


def test_result_includes_score_in_valid_range():
    """결과의 score 가 0~100 범위."""
    result, _ = _run_with_mocks(
        _forecast(rain=20),
        Prediction(visitor_count=2000, crowd_level="하"),
    )
    assert 0 <= result.to_dict()["score"] <= 100


def test_fcm_failure_does_not_break_pipeline():
    """FCM 발송 실패해도 result 는 반환 (pushed=False)."""
    with patch("backend.pipeline.weather.fetch_forecast", return_value=_forecast(rain=20)), \
         patch("backend.pipeline.predictor.predict_one",
               return_value=Prediction(visitor_count=1200, crowd_level="하")), \
         patch("backend.pipeline.fcm.send_topic", side_effect=RuntimeError("FCM down")):
        result = pipeline.run_pipeline("tomorrow")
    assert result.to_dict()["pushed"] is False


def test_target_today_uses_today_date():
    """target='today' → target_date 가 오늘."""
    with patch("backend.pipeline.weather.fetch_forecast", return_value=_forecast()), \
         patch("backend.pipeline.predictor.predict_one",
               return_value=Prediction(visitor_count=2000, crowd_level="하")), \
         patch("backend.pipeline.fcm.send_topic", return_value="m"):
        result = pipeline.run_pipeline("today")
    from datetime import datetime, timezone, timedelta
    today_kst = datetime.now(timezone(timedelta(hours=9))).date().isoformat()
    assert result.to_dict()["target_date"] == today_kst


def test_narrative_fallback_when_no_api_key(monkeypatch):
    """ANTHROPIC_API_KEY 없으면 룰 기반 fallback 으로 narrative 반환."""
    monkeypatch.delenv('ANTHROPIC_API_KEY', raising=False)
    from backend.narrative import generate_narrative
    # carousel = '빅회전목마' — attractions.json 에 있는 id
    out = generate_narrative(
        attraction_id='carousel',
        companion_type='연인',
        season='spring',
        weather='맑음',
        visit_count=1,
    )
    assert out.attraction_id == 'carousel'
    assert out.attraction_name == '빅회전목마'
    assert '벚꽃' in out.narrative or '발걸음' in out.narrative
    assert '1988년' in out.narrative
