"""동선 추천 — 백엔드 단일 진실 로직.

설계:
  · 입력: RouteRequest (uid, GPS, onboarding, completed_attraction_ids,
    discovered_eggs, request_reason).
  · 점수: 대기시간 / 거리 / 미발견 에그 / 취향 / 평점 가중.
  · AI hook: predictor.predict_one() 로 시점별 시간대 혼잡도 → 어트랙션
    waitMinutes 보정 (저혼잡 시간대면 점수↑). 모델 없으면 정적 값 그대로.
  · 순서: greedy nearest-neighbor (시작점=현재 위치 or 정문).
  · 출력: RouteResponse (stops with order/eta, total_min, rationale,
    computed_at, cache_key).

기존 Flutter `_generateMock()` 로직을 그대로 옮겨 contract 호환 유지.
"""

from __future__ import annotations

import json
import logging
import math
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable

logger = logging.getLogger(__name__)

# ────────────────────────────────────────────────────────────
# 데이터 로드 — 빌드 시 Flutter kAttractions 에서 추출된 JSON.
# scripts/extract_attractions.py 로 재생성.
# ────────────────────────────────────────────────────────────
_DATA_PATH = Path(__file__).parent / "attractions.json"
_ATTRACTIONS: list[dict] = []


def _load() -> list[dict]:
    global _ATTRACTIONS
    if _ATTRACTIONS:
        return _ATTRACTIONS
    if not _DATA_PATH.exists():
        logger.warning("attractions.json missing at %s", _DATA_PATH)
        return []
    _ATTRACTIONS = json.loads(_DATA_PATH.read_text(encoding="utf-8"))
    return _ATTRACTIONS


# ────────────────────────────────────────────────────────────
# 라벨 (Flutter `FavoriteType` / `VisitPurpose` 와 1:1 매칭)
# ────────────────────────────────────────────────────────────
FAVORITE_THRILL = "스릴 어트랙션 위주"
FAVORITE_FAMILY = "가족·어린이 위주"
FAVORITE_BOTH = "둘 다 괜찮아요"

PURPOSE_RIDES = "놀이기구 즐기기"
PURPOSE_PICNIC = "나들이·피크닉"
PURPOSE_KIDS_OUTING = "아이 데리고 나들이"
PURPOSE_DATE = "데이트"


# ────────────────────────────────────────────────────────────
# 입출력 모델
# ────────────────────────────────────────────────────────────
@dataclass
class RouteRequest:
    uid: str
    lat: float
    lng: float
    has_gps: bool
    headcount: int
    members: dict[str, int]  # MemberCategory.name → count
    favorite_type: str | None
    purpose: str | None
    completed_attraction_ids: set[str] = field(default_factory=set)
    discovered_eggs: set[str] = field(default_factory=set)
    request_reason: str = "initial"

    @classmethod
    def from_json(cls, body: dict) -> "RouteRequest":
        ob = body.get("onboarding") or {}
        return cls(
            uid=body.get("uid", "guest"),
            lat=float(body.get("lat", 37.4332)),
            lng=float(body.get("lng", 127.0174)),
            has_gps=bool(body.get("has_gps", False)),
            headcount=int(ob.get("headcount", 0)),
            members={k: int(v) for k, v in (ob.get("members") or {}).items()},
            favorite_type=ob.get("favorite_type"),
            purpose=ob.get("purpose"),
            completed_attraction_ids=set(body.get("completed_attraction_ids") or []),
            discovered_eggs=set(body.get("discovered_eggs") or []),
            request_reason=body.get("request_reason") or "initial",
        )

    @property
    def has_infant(self) -> bool:
        return self.members.get("infant", 0) > 0

    @property
    def has_child(self) -> bool:
        return self.members.get("child", 0) > 0


@dataclass
class RouteStop:
    id: str
    order: int
    eta_min_from_prev: int


@dataclass
class RouteResponse:
    route: list[RouteStop]
    total_min: int
    rationale: str | None
    computed_at: datetime
    cache_key: str

    def to_dict(self) -> dict:
        return {
            "route": [
                {
                    "id": s.id,
                    "order": s.order,
                    "eta_min_from_prev": s.eta_min_from_prev,
                }
                for s in self.route
            ],
            "total_min": self.total_min,
            "rationale": self.rationale,
            "computed_at": self.computed_at.isoformat(),
            "cache_key": self.cache_key,
        }


# ────────────────────────────────────────────────────────────
# 공식 / 헬퍼
# ────────────────────────────────────────────────────────────
def _haversine_m(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """두 GPS 좌표 사이 거리(미터). 4 km/h 도보 가정 시 div 66.67 분."""
    r = 6_371_000.0
    p1 = math.radians(lat1)
    p2 = math.radians(lat2)
    dp = math.radians(lat2 - lat1)
    dl = math.radians(lng2 - lng1)
    h = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * r * math.atan2(math.sqrt(h), math.sqrt(1 - h))


def _route_length(purpose: str | None) -> int:
    if purpose == PURPOSE_DATE:
        return 4
    if purpose == PURPOSE_PICNIC:
        return 3
    if purpose == PURPOSE_KIDS_OUTING:
        return 5
    if purpose == PURPOSE_RIDES:
        return 7
    return 5


def _clamp(v: float, lo: float, hi: float) -> float:
    return max(lo, min(hi, v))


def _wait_adjustment(base_wait: int, crowd_level: str | None) -> int:
    """AI hook: 예측된 시점 혼잡도로 어트랙션별 wait 보정.

    혼잡도 'low' 면 -30%, 'mid' 0%, 'high' +25%. 음수 방지.
    crowd_level 미지정 시 그대로.
    """
    if not crowd_level:
        return base_wait
    factor = {"low": 0.7, "mid": 1.0, "high": 1.25}.get(crowd_level, 1.0)
    return max(0, round(base_wait * factor))


# ────────────────────────────────────────────────────────────
# 메인 추천 함수
# ────────────────────────────────────────────────────────────
def recommend_route(
    req: RouteRequest,
    *,
    predicted_crowd_level: str | None = None,
) -> RouteResponse:
    """동선 추천 — 룰 기반 스코어링 + 예측 혼잡도 보정 + nearest-neighbor 순서.

    `predicted_crowd_level` (low/mid/high) 가 주어지면 어트랙션 wait 을
    시점 보정. 보통 `predictor.predict_one()` 결과를 endpoint 에서 주입.
    """
    catalog = _load()

    # 1) 운영중 + 미완료
    pool: list[dict] = [
        a
        for a in catalog
        if a["is_operating"] and a["id"] not in req.completed_attraction_ids
    ]

    # 2) 유아 동반 → 키 제한 0인 것만
    if req.has_infant:
        pool = [a for a in pool if a["height_limit"] == 0]

    # 3) 스코어링 (Flutter mock 과 동일 가중)
    scored: list[tuple[dict, float]] = []
    for a in pool:
        score = 0.0
        adj_wait = _wait_adjustment(a["wait_minutes"], predicted_crowd_level)
        # 혼잡도(낮을수록 높은 점수)
        score += _clamp(60 - adj_wait, -20, 60)
        # 거리 (현 위치에서 가까울수록 +)
        dist = _haversine_m(req.lat, req.lng, a["lat"], a["lng"])
        score += _clamp((1200 - dist) / 80, -10, 15)
        # 미발견 이스터에그 보너스
        if a["has_easter_egg"] and a["id"] not in req.discovered_eggs:
            score += 25
        # 선호 어트랙션 가중
        if a["category"] == "어트랙션":
            if req.favorite_type == FAVORITE_THRILL and a["thrill_level"] >= 4:
                score += 25
            if req.favorite_type == FAVORITE_FAMILY and a["thrill_level"] <= 2:
                score += 25
        # 어린이 동반 시 저스릴 어트랙션 우대
        if (
            req.has_child
            and a["category"] == "어트랙션"
            and a["thrill_level"] <= 2
        ):
            score += 15
        # 평점 (음식·카페·포토 분류에 더 큰 영향)
        score += a["rating"] * (1.5 if a["category"] == "어트랙션" else 4.0)
        scored.append((a, score))

    scored.sort(key=lambda t: t[1], reverse=True)

    # 4) 동선 길이
    n = _route_length(req.purpose)

    # 5) 카테고리 다양성 — 어트랙션 60% + 카페/포토/음식 각 1.
    # N=3 처럼 짧을 때 upper bound 가 min 보다 작아지지 않게 가드.
    upper = max(2, n - 1) if n >= 2 else 2
    attraction_count = max(2, min(math.ceil(n * 0.6), upper))

    picked: list[dict] = []
    for a, _ in scored:
        if len(picked) >= attraction_count:
            break
        if a["category"] == "어트랙션":
            picked.append(a)

    extras: list[dict] = []
    for cat in ("카페", "포토스팟", "음식점"):
        for a, _ in scored:
            if a["category"] == cat:
                extras.append(a)
                break
    for a in extras:
        if len(picked) >= n:
            break
        picked.append(a)

    # 6) nearest-neighbor 순서
    ordered = _nearest_neighbor(picked, req.lat, req.lng)

    # 7) ETA / total
    stops: list[RouteStop] = []
    prev_lat, prev_lng = req.lat, req.lng
    total_min = 0
    for i, a in enumerate(ordered):
        dist = _haversine_m(prev_lat, prev_lng, a["lat"], a["lng"])
        walk_min = math.ceil(dist / 66.67)  # 4 km/h
        wait = _wait_adjustment(a["wait_minutes"], predicted_crowd_level)
        eta = walk_min + wait
        stops.append(RouteStop(id=a["id"], order=i + 1, eta_min_from_prev=eta))
        total_min += eta
        prev_lat, prev_lng = a["lat"], a["lng"]

    # 8) rationale
    rationale = _rationale(req, ordered)

    # 9) cache key
    cache_key = (
        f"{req.lat:.3f}_{req.lng:.3f}_"
        f"{len(req.completed_attraction_ids)}_"
        f"{req.purpose or ''}_{req.request_reason}"
    )

    return RouteResponse(
        route=stops,
        total_min=total_min,
        rationale=rationale,
        computed_at=datetime.now(timezone.utc),
        cache_key=cache_key,
    )


def _nearest_neighbor(
    pool: list[dict], start_lat: float, start_lng: float
) -> list[dict]:
    if not pool:
        return []
    remaining = list(pool)
    result: list[dict] = []
    cur_lat, cur_lng = start_lat, start_lng
    while remaining:
        best_idx = 0
        best_dist = float("inf")
        for i, a in enumerate(remaining):
            d = _haversine_m(cur_lat, cur_lng, a["lat"], a["lng"])
            if d < best_dist:
                best_dist = d
                best_idx = i
        pick = remaining.pop(best_idx)
        result.append(pick)
        cur_lat, cur_lng = pick["lat"], pick["lng"]
    return result


def _rationale(req: RouteRequest, route: Iterable[dict]) -> str:
    route_list = list(route)
    if req.has_infant:
        return "유아 동반 — 키 제한 어트랙션 빼고 짰어요 🍼"
    undiscovered = sum(
        1
        for a in route_list
        if a["has_easter_egg"] and a["id"] not in req.discovered_eggs
    )
    if undiscovered >= 2:
        return f"못 찾은 이스터에그 {undiscovered}개 포함했어요 🥚"
    if req.purpose == PURPOSE_DATE:
        return "둘만의 데이트 코스로 짰어요 💑"
    if req.favorite_type == FAVORITE_THRILL:
        return "스릴 위주 — 짜릿하게 즐겨보세요 🎢"
    if req.favorite_type == FAVORITE_FAMILY:
        return "가족이 함께 즐길 어트랙션 위주에요 🎠"
    if req.request_reason == "gps_moved":
        return "이동하신 위치 기준으로 다시 짰어요 📍"
    if req.request_reason == "attraction_completed":
        return "방금 다녀온 코스 빼고 갱신했어요 ✨"
    return "오늘의 추천 동선이에요 ✨"
