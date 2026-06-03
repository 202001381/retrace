"""backend/route.py 단위 테스트 — 동선 추천 로직 회귀 방지.

실행: cd backend && python -m pytest test_route.py -v
"""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from . import route


@pytest.fixture(autouse=True)
def reset_catalog_cache():
    """각 테스트가 자체 카탈로그 로드 — 모듈 캐시 초기화."""
    route._ATTRACTIONS = []  # type: ignore[attr-defined]
    yield
    route._ATTRACTIONS = []  # type: ignore[attr-defined]


@pytest.fixture
def gate_req():
    """정문 위치, 빈 onboarding."""
    return route.RouteRequest(
        uid="guest",
        lat=37.4332,
        lng=127.0174,
        has_gps=False,
        headcount=0,
        members={},
        favorite_type=None,
        purpose=None,
    )


def test_catalog_loads_51_attractions():
    """JSON 파일에 51개 어트랙션이 있어야 함 (extract 스크립트 결과)."""
    data = route._load()
    assert len(data) == 51
    # 필수 필드 sample 검증
    first = data[0]
    for key in ("id", "name", "category", "lat", "lng", "thrill_level"):
        assert key in first, f"missing {key}"


def test_recommend_returns_non_empty_for_default_request(gate_req):
    """기본 요청 시 N=5 stops 가 나와야 함."""
    resp = route.recommend_route(gate_req)
    assert isinstance(resp, route.RouteResponse)
    assert 1 <= len(resp.route) <= 7
    assert resp.total_min > 0
    assert resp.rationale  # 비어 있지 않음
    assert resp.cache_key


def test_picnic_purpose_yields_3_stops(gate_req):
    """picnic 은 N=3 길이로 짧게."""
    gate_req.purpose = route.PURPOSE_PICNIC
    resp = route.recommend_route(gate_req)
    assert len(resp.route) <= 3


def test_rides_purpose_yields_7_stops(gate_req):
    """rides 는 N=7 길이로 길게."""
    gate_req.purpose = route.PURPOSE_RIDES
    resp = route.recommend_route(gate_req)
    assert 5 <= len(resp.route) <= 7


def test_infant_filter_excludes_height_restricted(gate_req):
    """유아 동반 시 height_limit > 0 어트랙션 0개."""
    gate_req.members = {"infant": 1}
    gate_req.headcount = 1
    resp = route.recommend_route(gate_req)
    catalog = {a["id"]: a for a in route._load()}
    for stop in resp.route:
        a = catalog[stop.id]
        assert a["height_limit"] == 0, f"{a['name']} has height limit {a['height_limit']}"


def test_completed_attraction_excluded(gate_req):
    """이미 다녀온 어트랙션은 추천에서 제외."""
    gate_req.completed_attraction_ids = {"galaxy_888", "blackhole_2000"}
    resp = route.recommend_route(gate_req)
    stop_ids = {s.id for s in resp.route}
    assert "galaxy_888" not in stop_ids
    assert "blackhole_2000" not in stop_ids


def test_route_stops_have_sequential_order(gate_req):
    """stop.order 가 1,2,3... 순차적."""
    resp = route.recommend_route(gate_req)
    for i, stop in enumerate(resp.route):
        assert stop.order == i + 1


def test_route_eta_positive(gate_req):
    """각 stop ETA 가 0 이상 (도보 거리 + wait)."""
    resp = route.recommend_route(gate_req)
    for stop in resp.route:
        assert stop.eta_min_from_prev >= 0


def test_thrill_preference_picks_high_thrill(gate_req):
    """thrill 선호 + rides 목적 → 추천된 어트랙션 평균 thrill ≥ 3."""
    gate_req.favorite_type = route.FAVORITE_THRILL
    gate_req.purpose = route.PURPOSE_RIDES
    resp = route.recommend_route(gate_req)
    catalog = {a["id"]: a for a in route._load()}
    attractions = [
        catalog[s.id] for s in resp.route
        if catalog[s.id]["category"] == "어트랙션"
    ]
    assert attractions, "no attractions recommended"
    avg_thrill = sum(a["thrill_level"] for a in attractions) / len(attractions)
    assert avg_thrill >= 3.0, f"avg thrill {avg_thrill:.1f} too low for thrill seeker"


def test_family_preference_picks_low_thrill(gate_req):
    """family 선호 → 추천된 어트랙션 평균 thrill ≤ 3."""
    gate_req.favorite_type = route.FAVORITE_FAMILY
    gate_req.purpose = route.PURPOSE_KIDS_OUTING
    gate_req.members = {"child": 1}
    gate_req.headcount = 1
    resp = route.recommend_route(gate_req)
    catalog = {a["id"]: a for a in route._load()}
    attractions = [
        catalog[s.id] for s in resp.route
        if catalog[s.id]["category"] == "어트랙션"
    ]
    if attractions:
        avg_thrill = sum(a["thrill_level"] for a in attractions) / len(attractions)
        assert avg_thrill <= 3.0, f"avg thrill {avg_thrill:.1f} too high for family"


def test_request_json_parsing():
    """Flutter 가 보내는 toJson() 포맷 그대로 파싱."""
    body = {
        "uid": "test-uid",
        "lat": 37.4332,
        "lng": 127.0174,
        "has_gps": True,
        "onboarding": {
            "headcount": 3,
            "members": {"infant": 1, "adultMale": 1, "adultFemale": 1},
            "favorite_type": "가족·어린이 위주",
            "purpose": "아이 데리고 나들이",
        },
        "completed_attraction_ids": ["galaxy_888"],
        "discovered_eggs": ["blackhole_2000"],
        "request_reason": "manual_refresh",
    }
    req = route.RouteRequest.from_json(body)
    assert req.uid == "test-uid"
    assert req.has_gps is True
    assert req.has_infant is True
    assert req.has_child is False
    assert req.favorite_type == "가족·어린이 위주"
    assert req.purpose == "아이 데리고 나들이"
    assert "galaxy_888" in req.completed_attraction_ids
    assert "blackhole_2000" in req.discovered_eggs


def test_predicted_crowd_high_increases_wait(gate_req):
    """predicted_crowd_level='high' 면 wait 보정으로 total_min 증가."""
    low_resp = route.recommend_route(gate_req, predicted_crowd_level="low")
    high_resp = route.recommend_route(gate_req, predicted_crowd_level="high")
    # 동일 입력 + crowd_level 만 다르면 high 가 항상 ≥ low.
    # (점수 변화로 다른 어트랙션 picking 될 수 있어 정확 비례는 아니지만,
    # 동일 카탈로그라면 같은 후보들에서 wait 만 늘어남.)
    assert high_resp.total_min >= low_resp.total_min


def test_rain_prob_high_boosts_indoor_attractions(gate_req):
    """rain_prob ≥ 60 시 실내 어트랙션 비중 ↑."""
    catalog = {a["id"]: a for a in route._load()}
    gate_req.favorite_type = route.FAVORITE_THRILL
    gate_req.purpose = route.PURPOSE_RIDES
    dry_resp = route.recommend_route(gate_req, rain_prob=0)
    wet_resp = route.recommend_route(gate_req, rain_prob=80)
    indoor_dry = sum(1 for s in dry_resp.route if catalog[s.id].get("indoor"))
    indoor_wet = sum(1 for s in wet_resp.route if catalog[s.id].get("indoor"))
    assert indoor_wet >= indoor_dry, (
        f"비올 때 실내 더 많아야: indoor_dry={indoor_dry} indoor_wet={indoor_wet}"
    )


def test_profile_changed_rationale_priority(gate_req):
    """request_reason=profile_changed 면 사용자 의도가 rationale 1순위."""
    gate_req.request_reason = "profile_changed"
    gate_req.favorite_type = route.FAVORITE_THRILL
    resp = route.recommend_route(gate_req)
    assert "다시" in resp.rationale or "스릴" in resp.rationale, resp.rationale


def test_rain_rationale_overrides_intent(gate_req):
    """비 사유는 사용자 의도(스릴/데이트) 보다 우선 표시 — 안전·상황 중요."""
    gate_req.favorite_type = route.FAVORITE_THRILL
    gate_req.purpose = route.PURPOSE_RIDES
    resp = route.recommend_route(gate_req, rain_prob=80)
    assert "비" in resp.rationale or "실내" in resp.rationale, resp.rationale


def test_lunch_hour_rationale(gate_req):
    """11~13시 hour 면 점심 사유 표시."""
    resp = route.recommend_route(gate_req, hour=12)
    assert "점심" in resp.rationale, resp.rationale


def test_cache_key_includes_time_vars(gate_req):
    """같은 survey 라도 시점 변수 다르면 cache_key 가 달라야 함."""
    r1 = route.recommend_route(gate_req, rain_prob=10, hour=10)
    r2 = route.recommend_route(gate_req, rain_prob=80, hour=12)
    assert r1.cache_key != r2.cache_key


def test_to_dict_serialization(gate_req):
    """RouteResponse.to_dict() 가 Flutter fromJson 과 호환되는 키 셋."""
    resp = route.recommend_route(gate_req)
    d = resp.to_dict()
    assert set(d.keys()) >= {
        "route",
        "total_min",
        "rationale",
        "computed_at",
        "cache_key",
    }
    for stop in d["route"]:
        assert set(stop.keys()) == {"id", "order", "eta_min_from_prev"}
    # JSON 직렬화 가능해야 함
    json.dumps(d, ensure_ascii=False)
