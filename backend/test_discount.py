"""backend/discount.py 단위 테스트."""

from __future__ import annotations

import pytest

from . import discount


# ── 정상 케이스 ─────────────────────────────────────────────
@pytest.mark.parametrize(
    "crowd_level, rain_prob, expected_pct, reason_contains",
    [
        ("상", 0, 0, "성수기"),
        ("상", 80, 0, "성수기"),  # 상 등급은 강수 무관 0%
        ("중", 0, 10, "보통"),
        ("중", 49, 10, "보통"),
        ("중", 50, 15, "보통 혼잡 + 강수 우려"),
        ("중", 90, 15, "보통 혼잡 + 강수 우려"),
        ("하", 0, 15, "한산"),
        ("하", 29, 15, "한산"),
        ("하", 30, 18, "약한 강수"),
        ("하", 49, 18, "약한 강수"),
        ("하", 50, 22, "강수 우려"),
        ("하", 69, 22, "강수 우려"),
        ("하", 70, 25, "강한 강수"),
        ("하", 100, 25, "강한 강수"),
    ],
)
def test_discount_table(crowd_level, rain_prob, expected_pct, reason_contains):
    result = discount.calc_discount(crowd_level, rain_prob)
    assert result["discount_pct"] == expected_pct, (
        f"{crowd_level} + {rain_prob}% → got {result['discount_pct']}, expected {expected_pct}"
    )
    assert reason_contains in result["reason"]
    assert result["crowd_level"] == crowd_level
    assert result["rain_prob"] == rain_prob


# ── 경계 / 입력 검증 ─────────────────────────────────────────
def test_invalid_crowd_level_raises():
    with pytest.raises(ValueError, match="unknown crowd_level"):
        discount.calc_discount("매우상", 0)  # type: ignore[arg-type]


def test_rain_prob_negative_clamped_to_zero():
    """음수 강수확률은 0으로 정규화."""
    result = discount.calc_discount("하", -50)
    assert result["rain_prob"] == 0.0
    assert result["discount_pct"] == 15  # rain 0 기준


def test_rain_prob_over_100_clamped_to_100():
    result = discount.calc_discount("하", 250)
    assert result["rain_prob"] == 100.0
    assert result["discount_pct"] == 25  # rain 100 → 강한 강수


def test_rain_prob_default_is_zero():
    """rain_prob 미지정 시 0으로 동작."""
    result = discount.calc_discount("하")
    assert result["rain_prob"] == 0.0
    assert result["discount_pct"] == 15


def test_discount_pct_monotonic_in_rain_for_low_crowd():
    """하 등급에선 강수가 늘수록 할인율 단조 증가."""
    pcts = [discount.calc_discount("하", r)["discount_pct"] for r in (0, 30, 50, 70, 100)]
    assert pcts == sorted(pcts), f"not monotonic: {pcts}"


def test_pricing_now_endpoint(monkeypatch):
    """`/api/pricing/now` 가 날씨 fetch 실패 시에도 graceful 응답."""
    from backend.app import create_app
    app = create_app()
    client = app.test_client()
    resp = client.get('/api/pricing/now')
    assert resp.status_code == 200
    body = resp.get_json()
    assert body['discount_pct'] in (0, 10, 15, 18, 22, 25)
    assert body['crowd_level'] in ('상', '중', '하')
    assert 'weather' in body
    assert 'temp' in body
    assert 'computed_at' in body
