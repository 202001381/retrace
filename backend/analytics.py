"""파일럿 테스트·시장 검증용 이벤트 로깅 + KPI 통계.

엔드포인트:
  POST /api/events                                  사용자 행동 이벤트 기록 (uid 자동 첨부)
  GET  /api/admin/stats/coupon-funnel               KPI 1: 쿠폰 클릭률 / 입장 전환율
  GET  /api/admin/stats/route-effectiveness         KPI 2: 추천 그룹 vs 대조 그룹
  GET  /api/admin/stats/easter-eggs                 KPI 3: 참여율 / 챕터 완료율
  GET  /api/admin/stats/fnb                         KPI 4: 쿠폰 사용률 / 객단가
  GET  /api/admin/stats/attraction-distribution     KPI 5: 인기 어트랙션 집중도

관리자 통계는 @require_internal_job (X-Internal-Token) 으로 보호.
이벤트 기록은 @require_firebase_auth (사용자 본인 행동).

이벤트 스키마 (events/{auto_id}):
    uid: str
    type: str (7종 — schemas.py _EVENT_TYPES)
    timestamp: SERVER_TIMESTAMP
    properties: dict (자유 — coupon_id, attraction_id, amount 등)
"""
from collections import Counter, defaultdict
from datetime import datetime, timezone
from typing import Optional

from firebase_admin import firestore as fs
from flask import Blueprint, current_app, g, jsonify, request

import repository
from auth import require_firebase_auth, require_internal_job
from schemas import (
    AttractionDistributionStats,
    CouponFunnelStats,
    EasterEggParticipationStats,
    EventCreateRequest,
    EventCreateResponse,
    FnbStats,
    RouteEffectivenessStats,
)

events_bp = Blueprint("events", __name__)
admin_stats_bp = Blueprint("admin_stats", __name__)


def _db_or_503():
    db = current_app.config["SEOULLAND_DB"]
    if db is None:
        return None, (
            jsonify({"error": {"code": "FIRESTORE_UNAVAILABLE", "message": "Firestore 미초기화"}}),
            503,
        )
    return db, None


def _iso(ts) -> str:
    if ts is None:
        return ""
    if hasattr(ts, "isoformat"):
        return ts.isoformat()
    if hasattr(ts, "to_pydatetime"):
        return ts.to_pydatetime().isoformat()
    return str(ts)


def _safe_rate(num: float, denom: float) -> float:
    return round(num / denom, 4) if denom > 0 else 0.0


# ─────────────────── POST /api/events ───────────────────

@events_bp.post("")
@require_firebase_auth
def post_event():
    payload = EventCreateRequest.model_validate(request.get_json(silent=True) or {})
    db, err = _db_or_503()
    if err:
        return err

    uid = g.current_user["uid"] if g.current_user else "anonymous"
    doc_ref = db.collection("events").document()  # auto-id
    doc_ref.set({
        "uid": uid,
        "type": payload.type,
        "timestamp": fs.SERVER_TIMESTAMP,
        "properties": payload.properties or {},
    })
    written = doc_ref.get().to_dict() or {}
    return jsonify({"data": EventCreateResponse(
        event_id=doc_ref.id,
        type=payload.type,
        recorded_at=_iso(written.get("timestamp")),
    ).model_dump()})


# ─────────────────── 통계 헬퍼 ───────────────────

def _query_events(db, types: list[str], uid: Optional[str] = None) -> list[dict]:
    """events 컬렉션에서 특정 타입(들)의 이벤트를 모두 가져옴.

    데모 단계 — 컬렉션 크기 작아 풀스캔. 운영 단계엔 BigQuery export 권장.
    """
    q = db.collection("events").where(filter=fs.FieldFilter("type", "in", types))
    if uid:
        q = q.where(filter=fs.FieldFilter("uid", "==", uid))
    return [{**d.to_dict(), "id": d.id} for d in q.stream()]


def _user_group(db, uid: str) -> str:
    """users/{uid}.group 조회. 없으면 'control'."""
    doc = db.collection("users").document(uid).get()
    if not doc.exists:
        return "control"
    return (doc.to_dict() or {}).get("group", "control")


# ─────────────────── KPI 1: Luna Pricing ───────────────────

@admin_stats_bp.get("/coupon-funnel")
@require_internal_job
def get_coupon_funnel():
    db, err = _db_or_503()
    if err:
        return err

    coupon_id = request.args.get("coupon_id")  # 없으면 전체 집계

    clicks = _query_events(db, ["coupon_click"])
    purchases = _query_events(db, ["ticket_purchase"])

    if coupon_id:
        clicks = [e for e in clicks if e.get("properties", {}).get("coupon_id") == coupon_id]
        # 입장권 구매는 같은 사용자가 30분 내 click 후 purchase 발생한 경우 카운트
        # 단순화: click 한 uid 중 purchase 한 uid 비율
    click_uids = {e["uid"] for e in clicks}
    purchase_uids = {e["uid"] for e in purchases}
    converted = click_uids & purchase_uids

    stats = CouponFunnelStats(
        coupon_id=coupon_id,
        click_count=len(clicks),
        purchase_count=len(converted),
        click_to_purchase_rate=_safe_rate(len(converted), len(click_uids)),
    )
    return jsonify({"data": stats.model_dump()})


# ─────────────────── KPI 2: My Luna 동선 ───────────────────

@admin_stats_bp.get("/route-effectiveness")
@require_internal_job
def get_route_effectiveness():
    db, err = _db_or_503()
    if err:
        return err

    arrives = _query_events(db, ["visit_arrive"])
    leaves = _query_events(db, ["visit_leave"])

    # uid별 (arrive, leave) 매칭 → 체류 시간 계산
    arrives_by_uid: dict[str, list] = defaultdict(list)
    leaves_by_uid: dict[str, list] = defaultdict(list)
    for e in arrives:
        arrives_by_uid[e["uid"]].append(e)
    for e in leaves:
        leaves_by_uid[e["uid"]].append(e)

    # 사용자별 그룹 미리 조회 (캐시)
    uids = set(arrives_by_uid.keys()) | set(leaves_by_uid.keys())
    user_groups = {uid: _user_group(db, uid) for uid in uids}

    group_stay: dict[str, list[float]] = defaultdict(list)
    group_visits: dict[str, list[int]] = defaultdict(list)

    for uid in uids:
        a_list = sorted(arrives_by_uid[uid], key=lambda e: _iso(e.get("timestamp")))
        l_list = sorted(leaves_by_uid[uid], key=lambda e: _iso(e.get("timestamp")))
        pairs = min(len(a_list), len(l_list))
        stay_total = 0.0
        for i in range(pairs):
            a_ts = a_list[i].get("timestamp")
            l_ts = l_list[i].get("timestamp")
            if a_ts and l_ts:
                a_dt = a_ts.to_pydatetime() if hasattr(a_ts, "to_pydatetime") else a_ts
                l_dt = l_ts.to_pydatetime() if hasattr(l_ts, "to_pydatetime") else l_ts
                delta = (l_dt - a_dt).total_seconds() / 60.0
                if delta > 0:
                    stay_total += delta
        g_key = user_groups.get(uid, "control")
        group_stay[g_key].append(stay_total)
        group_visits[g_key].append(len(a_list))

    def _avg(xs: list[float]) -> float:
        return round(sum(xs) / len(xs), 2) if xs else 0.0

    stats = RouteEffectivenessStats(
        recommended_group_avg_stay_min=_avg(group_stay.get("recommended", [])),
        recommended_group_avg_attractions=_avg([float(x) for x in group_visits.get("recommended", [])]),
        control_group_avg_stay_min=_avg(group_stay.get("control", [])),
        control_group_avg_attractions=_avg([float(x) for x in group_visits.get("control", [])]),
        sample_size_recommended=len(group_stay.get("recommended", [])),
        sample_size_control=len(group_stay.get("control", [])),
    )
    return jsonify({"data": stats.model_dump()})


# ─────────────────── KPI 3: 이스터에그 ───────────────────

@admin_stats_bp.get("/easter-eggs")
@require_internal_job
def get_easter_eggs_stats():
    db, err = _db_or_503()
    if err:
        return err

    # 전체 사용자 수
    user_docs = list(db.collection("users").stream())
    total_users = len(user_docs)

    # 1개 이상 이스터에그 발견한 사용자
    participating = 0
    user_eggs: dict[str, set] = {}
    for u in user_docs:
        eggs = list(
            db.collection("users").document(u.id).collection("easterEggs").stream()
        )
        if eggs:
            participating += 1
            user_eggs[u.id] = {e.id for e in eggs}

    # 챕터 완료율 — 챕터별로 [unlocked_count 평균, total_books]
    chapters = repository.list_chapters()
    chapter_stats = []
    for ch in chapters:
        required = set(ch.get("required_attraction_ids", []))
        per_user_unlocked = []
        for uid, found_set in user_eggs.items():
            per_user_unlocked.append(len(required & found_set))
        avg = round(sum(per_user_unlocked) / len(per_user_unlocked), 2) if per_user_unlocked else 0.0
        chapter_stats.append({
            "chapter_id": ch["id"],
            "name": ch["name"],
            "season": ch["season"],
            "avg_unlocked": avg,
            "total_books": len(required),
            "avg_completion_rate": _safe_rate(avg, len(required)),
        })

    stats = EasterEggParticipationStats(
        total_users=total_users,
        participating_users=participating,
        participation_rate=_safe_rate(participating, total_users),
        chapter_completion=chapter_stats,
    )
    return jsonify({"data": stats.model_dump()})


# ─────────────────── KPI 4: F&B ───────────────────

@admin_stats_bp.get("/fnb")
@require_internal_job
def get_fnb_stats():
    db, err = _db_or_503()
    if err:
        return err

    # F&B 쿠폰 카탈로그
    fnb_coupon_ids = {c["id"] for c in repository.list_fnb_coupons()}

    # 쿠폰 클릭/사용 이벤트 중 properties.coupon_id 가 F&B 카탈로그에 있는 것만
    clicks = _query_events(db, ["coupon_click"])
    redeems = _query_events(db, ["coupon_redeem"])
    purchases = _query_events(db, ["fnb_purchase"])

    fnb_clicks = [e for e in clicks if e.get("properties", {}).get("coupon_id") in fnb_coupon_ids]
    fnb_redeems = [e for e in redeems if e.get("properties", {}).get("coupon_id") in fnb_coupon_ids]

    # 객단가 = fnb_purchase 이벤트의 properties.amount 평균
    amounts = [
        float(e.get("properties", {}).get("amount", 0))
        for e in purchases
        if e.get("properties", {}).get("amount") is not None
    ]
    avg_basket = round(sum(amounts) / len(amounts), 0) if amounts else 0.0

    stats = FnbStats(
        coupon_click_count=len(fnb_clicks),
        coupon_redeem_count=len(fnb_redeems),
        redemption_rate=_safe_rate(len(fnb_redeems), len(fnb_clicks)),
        fnb_purchase_count=len(purchases),
        avg_basket_size=avg_basket,
    )
    return jsonify({"data": stats.model_dump()})


# ─────────────────── KPI 5: 추천 분산 ───────────────────

@admin_stats_bp.get("/attraction-distribution")
@require_internal_job
def get_attraction_distribution():
    db, err = _db_or_503()
    if err:
        return err

    # 방문 이벤트 (어트랙션 도착) 기준으로 집계
    arrives = _query_events(db, ["visit_arrive"])
    counter: Counter = Counter()
    for e in arrives:
        aid = e.get("properties", {}).get("attraction_id")
        if aid:
            counter[aid] += 1

    total = sum(counter.values())
    attraction_map = {a["id"]: a for a in repository.list_attractions()}
    by_attraction = []
    for aid, cnt in counter.most_common():
        by_attraction.append({
            "attraction_id": aid,
            "name": attraction_map.get(aid, {}).get("name", aid),
            "visit_count": cnt,
            "share": _safe_rate(cnt, total),
        })

    # 상위 3개 점유율
    top3 = sum(item["visit_count"] for item in by_attraction[:3])
    top3_concentration = _safe_rate(top3, total)

    # 대체 후보 선택률 = attraction_select 이벤트에서 properties.rank != 1 비율
    selects = _query_events(db, ["attraction_select"])
    if selects:
        alt = sum(1 for e in selects if int(e.get("properties", {}).get("rank", 1)) != 1)
        alt_rate = _safe_rate(alt, len(selects))
    else:
        alt_rate = 0.0

    stats = AttractionDistributionStats(
        by_attraction=by_attraction,
        top3_concentration=top3_concentration,
        alternative_selection_rate=alt_rate,
    )
    return jsonify({"data": stats.model_dump()})
