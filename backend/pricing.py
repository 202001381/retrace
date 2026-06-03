"""POST /api/pricing — 날씨·할인·방문가치 스코어·혼잡도 통합 응답."""
from datetime import datetime

import pytz
from flask import Blueprint, current_app, jsonify, request

import repository
from auth import require_firebase_auth
from schemas import DiscountInfo, PricingRequest, PricingResponse, WeatherInfo
from weather_client import fetch_features
from xgboost_model import VisitValueModel

pricing_bp = Blueprint("pricing", __name__)
_KST = pytz.timezone("Asia/Seoul")


def _condition_label(features: dict) -> str:
    pty = int(features.get("pty", 0))
    sky = int(features.get("sky", 1))
    if pty in (1, 2, 4):
        return "rainy"
    if pty == 3:
        return "snowy"
    if sky == 4:
        return "cloudy"
    return "sunny"


def _compute_dynamic_pricing(congestion_by_zone: dict[str, int]) -> tuple[str, float]:
    """구역별 혼잡도 평균 → 등급 + 동적 할인율.

    수요 분산 원칙: 한산할수록 할인율 ↑ (방문 유도), 혼잡할수록 할인 ↓.
    """
    if not congestion_by_zone:
        return "보통", 0.10
    avg = sum(congestion_by_zone.values()) / len(congestion_by_zone)
    if avg <= 1.5:
        return "낮음", 0.30
    if avg <= 3.0:
        return "보통", 0.15
    return "혼잡", 0.0


def _discount_matches(discount: dict, weather_label: str, now: datetime) -> bool:
    cond = discount.get("condition", {})
    ctype = cond.get("type")
    cvalue = cond.get("value")
    if ctype == "weather":
        return weather_label == cvalue
    if ctype == "time":
        if cvalue == "weekday":
            return now.weekday() < 5
        if cvalue == "weekend":
            return now.weekday() >= 5
    if ctype == "season":
        month = now.month
        if cvalue == "spring":
            return month in (3, 4, 5)
        if cvalue == "summer":
            return month in (6, 7, 8)
        if cvalue == "autumn":
            return month in (9, 10, 11)
        if cvalue == "winter":
            return month in (12, 1, 2)
    return False


@pricing_bp.post("")
@require_firebase_auth
def post_pricing():
    PricingRequest.model_validate(request.get_json(silent=True) or {})

    config = current_app.config["SEOULLAND_CONFIG"]
    model: VisitValueModel = current_app.config["SEOULLAND_MODEL"]

    features = fetch_features(config)
    score = round(model.predict(features))
    weather_label = _condition_label(features)
    now = datetime.now(_KST)

    matched_discounts = [
        DiscountInfo(id=d["id"], title=d["title"], rate=d["rate"])
        for d in repository.list_active_discounts()
        if _discount_matches(d, weather_label, now)
    ]

    congestion = repository.get_all_congestion()
    grade, dyn_rate = _compute_dynamic_pricing(congestion)

    response = PricingResponse(
        weather=WeatherInfo(condition=weather_label, temp_c=features["temp_c"]),
        discounts=matched_discounts,
        visit_value_score=score,
        congestion_by_zone=congestion,
        congestion_grade=grade,
        dynamic_discount_rate=dyn_rate,
    )
    return jsonify({"data": response.model_dump()})
