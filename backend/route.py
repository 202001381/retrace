"""POST /api/route — GPS·구성원·가용시간 기반 동선 추천.

알고리즘은 route_planner.plan() 에서 그리디 휴리스틱으로 순서 결정.
이후 llm_client.generate_route_narrative() 가 자연어 안내문 추가 (실패/키없음 시 null).
"""
from dataclasses import asdict

from flask import Blueprint, jsonify, request

from auth import require_firebase_auth
from llm_client import generate_route_narrative
from route_planner import plan as plan_route
from schemas import LatLng, RouteRequest, RouteResponse, RouteStep

route_bp = Blueprint("route", __name__)


@route_bp.post("")
@require_firebase_auth
def post_route():
    payload = RouteRequest.model_validate(request.get_json(silent=True) or {})

    steps = plan_route(
        current_location=payload.current_location.model_dump(),
        members=[m.model_dump() for m in payload.members],
        available_minutes=payload.available_minutes,
    )

    step_dicts = [asdict(s) for s in steps]
    narrative = generate_route_narrative(
        steps=step_dicts,
        members=[m.model_dump() for m in payload.members],
        available_minutes=payload.available_minutes,
    )

    response_steps = [
        RouteStep(
            order=s.order,
            poi_id=s.poi_id,
            name=s.name,
            type=s.type,
            location=LatLng(**s.location),
            travel_minutes=s.travel_minutes,
            wait_minutes=s.wait_minutes,
            stay_minutes=s.stay_minutes,
            arrival_minute_from_start=s.arrival_minute_from_start,
            score=s.score,
            reason=s.reason,
        )
        for s in steps
    ]
    total = (
        steps[-1].arrival_minute_from_start + steps[-1].wait_minutes + steps[-1].stay_minutes
        if steps
        else 0
    )
    response = RouteResponse(
        steps=response_steps,
        total_minutes=total,
        available_minutes=payload.available_minutes,
        narrative=narrative,
    )
    return jsonify({"data": response.model_dump()})
