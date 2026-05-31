"""POST /api/recommend — 구성원 정보 기반 Top-3 어트랙션 추천.

스코어링 = 0.25 * 거리 + 0.30 * 스릴매칭 + 0.20 * 가족적합도 + 0.25 * 혼잡도여유.
"""
import math
from typing import Optional

from flask import Blueprint, jsonify, request

import repository
from auth import require_firebase_auth
from schemas import LatLng, RecommendRequest, RecommendResponse, RecommendedAttraction

recommend_bp = Blueprint("recommend", __name__)

# 가중치 (조정 가능, 합 1.0)
_W_DIST = 0.25
_W_THRILL = 0.30
_W_FAMILY = 0.20
_W_CONGESTION = 0.25


def _distance_score(attraction: dict, loc: Optional[LatLng]) -> float:
    """0-1. 가까울수록 높음. 위치 없으면 중립값 0.5."""
    if loc is None:
        return 0.5
    dx = attraction["location"]["lat"] - loc.lat
    dy = attraction["location"]["lng"] - loc.lng
    dist = math.sqrt(dx * dx + dy * dy)
    return max(0.0, 1.0 - dist * 500)  # 500은 서울랜드 부지 규모 기반 정규화 계수


def _thrill_match(attraction: dict, avg_pref: float) -> float:
    """평균 선호도와 어트랙션 스릴 레벨 차이 → 작을수록 높음."""
    diff = abs(attraction["thrill_level"] - avg_pref)
    return max(0.0, 1.0 - diff / 5.0)


def _family_friendly(attraction: dict, has_kids: bool) -> float:
    """어린이 동반 시 thrill_level 낮을수록 가점, 아니면 중립."""
    if not has_kids:
        return 0.7
    return 1.0 if attraction["thrill_level"] <= 2 else 0.2


def _congestion_score(zone_id: str) -> float:
    """혼잡도 낮을수록 가점 (0-5 → 1.0-0.0)."""
    return 1.0 - repository.get_congestion(zone_id) / 5.0


def _build_reason(s_thrill: float, s_family: float, s_congestion: float, has_kids: bool) -> str:
    parts = []
    if s_congestion >= 0.7:
        parts.append("한산한 구역")
    if s_thrill >= 0.8:
        parts.append("취향에 잘 맞음")
    if has_kids and s_family >= 0.9:
        parts.append("어린이 동반 적합")
    return ", ".join(parts) or "종합 점수 우수"


@recommend_bp.post("")
@require_firebase_auth
def post_recommend():
    payload = RecommendRequest.model_validate(request.get_json(silent=True) or {})
    members = payload.members

    avg_thrill_pref = sum(m.thrill_pref for m in members) / len(members)
    has_kids = any(m.has_kids_role for m in members) or any(m.age < 12 for m in members)

    scored = []
    for a in repository.list_attractions():
        s_dist = _distance_score(a, payload.current_location)
        s_thrill = _thrill_match(a, avg_thrill_pref)
        s_family = _family_friendly(a, has_kids)
        s_cong = _congestion_score(a["zone_id"])
        total = (
            _W_DIST * s_dist
            + _W_THRILL * s_thrill
            + _W_FAMILY * s_family
            + _W_CONGESTION * s_cong
        )
        scored.append({
            "id": a["id"],
            "name": a["name"],
            "score": round(total * 100, 1),
            "reason": _build_reason(s_thrill, s_family, s_cong, has_kids),
        })

    scored.sort(key=lambda x: x["score"], reverse=True)
    top3 = [RecommendedAttraction(**s) for s in scored[:3]]
    return jsonify({"data": RecommendResponse(top=top3).model_dump()})
