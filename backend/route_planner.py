"""GPS 기반 동선 추천 — 그리디 휴리스틱.

알고리즘 개요:
    1. 현재 위치에서 시작
    2. 매 단계: 미방문 POI 중 효용 점수가 가장 높은 곳 선택
    3. 그곳까지 걸어가는 시간 + 대기 + 체류 만큼 시각 진행
    4. 가용 시간 내에 더 갈 수 있는 POI 없으면 종료

가중치 (합 1.0, 어트랙션):
    - 스릴 매칭 0.40
    - 가족 적합도 0.25
    - 혼잡도 여유 0.35
    + 어트랙션 base bonus 0.15  → 부대시설보다 우선

부대시설 별도 처리:
    - 입구(entrance) — 동선에서 항상 제외 (시작점 의미)
    - 식당(restaurant) — 마지막 식사 후 180분 cooldown
    - 화장실(restroom) — 90분 초과 시 강제 1순위
    - 포토존(photo_spot) — 첫 1회 가산점, 이후 약화

가정:
    - 보행 속도 4 km/h ≈ 67 m/min
    - 위도 1° ≈ 111 km, 위도 37° 에서 경도 1° ≈ 88 km
"""
import math
from dataclasses import dataclass
from datetime import datetime, timedelta
from typing import Optional

import pytz

import repository

_KST = pytz.timezone("Asia/Seoul")

_WALK_MPM = 67.0  # m/min
_LAT_DEG_M = 111_000.0
_LNG_DEG_M = 88_000.0  # 위도 37° 기준 근사

# 어트랙션 점수 가중치 (합 1.0)
_W_THRILL = 0.40
_W_FAMILY = 0.25
_W_CONGESTION = 0.35
# 어트랙션이 부대시설보다 일반적으로 우선되도록 하는 base bonus
_ATTRACTION_BASE = 0.15

# 부대시설 점수 가중치
_W_TYPE_FACILITY = 0.55
_W_CONGESTION_FACILITY = 0.20

# 식당 cooldown — 마지막 식사 후 이만큼 분 동안 식당 후보에서 제외
_MEAL_COOLDOWN_MIN = 180

# 화장실 강제 우선 임계 — 마지막 화장실 이후 이 분을 넘으면 강제 1순위
_RESTROOM_FORCE_MIN = 90

# 화장실 강제 시 점수 (다른 모든 점수보다 큰 값)
_RESTROOM_FORCE_SCORE = 10.0


@dataclass
class PlanStep:
    order: int
    poi_id: str
    name: str
    type: str
    location: dict  # {lat, lng}
    travel_minutes: int
    wait_minutes: int
    stay_minutes: int
    arrival_minute_from_start: int
    score: float
    reason: str


def _distance_m(a: dict, b: dict) -> float:
    dx = (a["lat"] - b["lat"]) * _LAT_DEG_M
    dy = (a["lng"] - b["lng"]) * _LNG_DEG_M
    return math.sqrt(dx * dx + dy * dy)


def _travel_minutes(a: dict, b: dict) -> int:
    return max(1, round(_distance_m(a, b) / _WALK_MPM))


def _wait_minutes(poi: dict, congestion: dict[str, int]) -> int:
    """어트랙션 대기 시간 — 구역 혼잡도(0-5) × 5분. 부대시설은 0."""
    if poi.get("zone_id") is None:
        return 0
    level = congestion.get(poi["zone_id"], 2)
    return level * 5


def _thrill_match_score(poi: dict, avg_pref: float) -> float:
    diff = abs(poi.get("thrill_level", 3) - avg_pref)
    return max(0.0, 1.0 - diff / 5.0)


def _family_score(poi: dict, has_kids: bool) -> float:
    if not has_kids:
        return 0.7
    return 1.0 if poi.get("thrill_level", 3) <= 2 else 0.2


def _congestion_score(poi: dict, congestion: dict[str, int]) -> float:
    zone = poi.get("zone_id")
    if zone is None:
        return 1.0
    return 1.0 - congestion.get(zone, 2) / 5.0


def _type_bonus(
    poi: dict,
    now_minute_of_day: int,
    photo_count_so_far: int,
) -> float:
    """부대시설 시점 보너스 (0~1). 식당·화장실 cooldown 은 호출부에서 별도 처리."""
    t = poi.get("type")
    if t == "restaurant":
        meal_lunch = 11 * 60 <= now_minute_of_day <= 14 * 60
        meal_dinner = 17 * 60 <= now_minute_of_day <= 20 * 60
        return 1.0 if (meal_lunch or meal_dinner) else 0.2
    if t == "restroom":
        return 0.4  # 평소 점수, 강제는 호출부에서 별도
    if t == "photo_spot":
        return 0.6 if photo_count_so_far == 0 else 0.15
    return 0.0


def _attraction_score(
    poi: dict,
    avg_thrill_pref: float,
    has_kids: bool,
    congestion: dict[str, int],
) -> float:
    return (
        _W_THRILL * _thrill_match_score(poi, avg_thrill_pref)
        + _W_FAMILY * _family_score(poi, has_kids)
        + _W_CONGESTION * _congestion_score(poi, congestion)
        + _ATTRACTION_BASE
    )


def _build_reason(poi: dict, score_breakdown: dict[str, float], forced_restroom: bool) -> str:
    t = poi.get("type")
    parts = []
    if forced_restroom:
        parts.append("화장실 권장 시점")
    elif t == "restaurant" and score_breakdown.get("type", 0) >= 0.8:
        parts.append("식사 시각 근접")
    elif t == "photo_spot" and score_breakdown.get("type", 0) >= 0.5:
        parts.append("인기 포토존")
    if score_breakdown.get("congestion", 0) >= 0.7:
        parts.append("한산한 구역")
    if score_breakdown.get("thrill", 0) >= 0.8:
        parts.append("취향에 잘 맞음")
    if score_breakdown.get("family", 0) >= 0.9:
        parts.append("어린이 동반 적합")
    return ", ".join(parts) or "동선 효율 우수"


def plan(
    current_location: dict,
    members: list[dict],
    available_minutes: int,
    start_time: Optional[datetime] = None,
) -> list[PlanStep]:
    """그리디 동선 계산."""
    if start_time is None:
        start_time = datetime.now(_KST)

    avg_thrill = sum(m["thrill_pref"] for m in members) / max(1, len(members))
    has_kids = any(m.get("has_kids_role") for m in members) or any(
        m["age"] < 12 for m in members
    )
    congestion = repository.get_all_congestion()
    pois = repository.list_attractions() + repository.list_facilities()

    visited: set[str] = set()
    plan_steps: list[PlanStep] = []
    cursor = dict(current_location)
    elapsed_minutes = 0
    last_meal_at: Optional[int] = None
    last_restroom_at: Optional[int] = None
    photo_count = 0

    while elapsed_minutes < available_minutes:
        now_minute_of_day = (start_time.hour * 60 + start_time.minute) + elapsed_minutes
        # 화장실 강제: 마지막 방문 이후 90분 초과 OR 시작 후 90분 동안 한 번도 안 감
        restroom_overdue = (
            (last_restroom_at is None and elapsed_minutes >= _RESTROOM_FORCE_MIN)
            or (
                last_restroom_at is not None
                and (elapsed_minutes - last_restroom_at) >= _RESTROOM_FORCE_MIN
            )
        )

        best_candidate = None
        best_total_score = -1.0
        best_breakdown: dict = {}
        best_forced_restroom = False

        for poi in pois:
            if poi["id"] in visited:
                continue
            poi_type = poi.get("type")

            # 입구는 동선 step 에 절대 안 들어감 (시작점 의미)
            if poi_type == "entrance":
                continue

            # 식당 cooldown
            if poi_type == "restaurant" and last_meal_at is not None:
                if elapsed_minutes - last_meal_at < _MEAL_COOLDOWN_MIN:
                    continue

            travel = _travel_minutes(cursor, poi["location"])
            wait = _wait_minutes(poi, congestion)
            stay = poi.get("stay_minutes", 10)
            total_time = travel + wait + stay
            if elapsed_minutes + total_time > available_minutes:
                continue

            type_b = _type_bonus(poi, now_minute_of_day, photo_count)
            forced = restroom_overdue and poi_type == "restroom"

            if forced:
                # 화장실 90분 초과 시 강제 1순위
                base_score = _RESTROOM_FORCE_SCORE
            elif poi_type in {"restaurant", "restroom", "photo_spot"}:
                base_score = (
                    _W_TYPE_FACILITY * type_b
                    + _W_CONGESTION_FACILITY * 1.0
                )
            else:
                base_score = _attraction_score(poi, avg_thrill, has_kids, congestion)

            # 거리 페널티
            time_pressure = elapsed_minutes / max(1, available_minutes)
            distance_penalty = (travel / 30.0) * (0.2 + 0.2 * time_pressure)
            total_score = base_score - distance_penalty

            if total_score > best_total_score:
                best_total_score = total_score
                best_candidate = (poi, travel, wait, stay)
                best_breakdown = {
                    "thrill": _thrill_match_score(poi, avg_thrill),
                    "family": _family_score(poi, has_kids),
                    "congestion": _congestion_score(poi, congestion),
                    "type": type_b,
                }
                best_forced_restroom = forced

        if best_candidate is None:
            break

        poi, travel, wait, stay = best_candidate
        elapsed_minutes += travel
        arrival_minute = elapsed_minutes
        elapsed_minutes += wait + stay

        visited.add(poi["id"])
        poi_type_chosen = poi.get("type")
        if poi_type_chosen == "restaurant":
            last_meal_at = arrival_minute
        elif poi_type_chosen == "restroom":
            last_restroom_at = arrival_minute
        elif poi_type_chosen == "photo_spot":
            photo_count += 1

        plan_steps.append(
            PlanStep(
                order=len(plan_steps) + 1,
                poi_id=poi["id"],
                name=poi["name"],
                type=poi_type_chosen or "attraction",
                location=poi["location"],
                travel_minutes=travel,
                wait_minutes=wait,
                stay_minutes=stay,
                arrival_minute_from_start=arrival_minute,
                score=round(best_total_score, 3),
                reason=_build_reason(poi, best_breakdown, best_forced_restroom),
            )
        )
        cursor = poi["location"]

    return plan_steps
