"""리워드 발급·조회.

POST /api/rewards/check     현재 시즌 unlocked 책 권수 기반 리워드 발급 검사
                            (3권 → goods, 5권 → ticket).
                            Firestore 트랜잭션으로 중복 발급 방지.

GET  /api/users/me/rewards  보유 리워드 목록.

리워드 ID 규약: '{season}_{threshold}' (예: 'spring_3', 'autumn_5') — 시즌·threshold 별
유니크 → 중복 발급 자연 방지.

코드 값: 'DEMO-{uid앞6}-{reward_id}' — 데모용 가짜 쿠폰 코드.
"""
from datetime import datetime
from typing import Optional

import pytz
from firebase_admin import firestore as fs
from flask import Blueprint, current_app, g, jsonify, request

import repository
from auth import require_firebase_auth
from schemas import RewardCheckResponse, RewardInfo, RewardListResponse

rewards_bp = Blueprint("rewards", __name__)
users_rewards_bp = Blueprint("users_rewards", __name__)
_KST = pytz.timezone("Asia/Seoul")

# (threshold, reward_type)
_REWARD_THRESHOLDS = [
    (3, "goods"),
    (5, "ticket"),
]


def _current_season(now: Optional[datetime] = None) -> str:
    month = (now or datetime.now(_KST)).month
    if 3 <= month <= 5:
        return "spring"
    if 6 <= month <= 8:
        return "summer"
    if 9 <= month <= 11:
        return "autumn"
    return "winter"


def _db_or_503():
    db = current_app.config["SEOULLAND_DB"]
    if db is None:
        return None, (
            jsonify({"error": {"code": "FIRESTORE_UNAVAILABLE", "message": "Firestore 미초기화"}}),
            503,
        )
    return db, None


def _iso(timestamp) -> Optional[str]:
    if timestamp is None:
        return None
    if hasattr(timestamp, "isoformat"):
        return timestamp.isoformat()
    if hasattr(timestamp, "to_pydatetime"):
        return timestamp.to_pydatetime().isoformat()
    return str(timestamp)


def _count_unlocked_books(db, uid: str, season: str) -> int:
    """현재 시즌 챕터들이 요구하는 어트랙션 중 사용자가 발견한 개수."""
    chapter_attraction_ids: set[str] = set()
    for chapter in repository.list_chapters(season=season):
        chapter_attraction_ids.update(chapter.get("required_attraction_ids", []))

    found_count = 0
    for doc in db.collection("users").document(uid).collection("easterEggs").stream():
        if doc.id in chapter_attraction_ids:
            found_count += 1
    return found_count


def _reward_doc_to_info(doc_id: str, data: dict) -> RewardInfo:
    return RewardInfo(
        reward_id=doc_id,
        type=data.get("type", "goods"),
        threshold=int(data.get("threshold", 0)),
        season=data.get("season", "spring"),
        granted_at=_iso(data.get("granted_at")) or "",
        redeemed_at=_iso(data.get("redeemed_at")),
        code=data.get("code"),
    )


# ──────────────────── 리워드 발급 검사 ────────────────────

@rewards_bp.post("/check")
@require_firebase_auth
def post_check():
    db, err = _db_or_503()
    if err:
        return err

    uid = g.current_user["uid"]
    season = _current_season()
    unlocked_count = _count_unlocked_books(db, uid, season)

    newly: list[RewardInfo] = []
    already: list[RewardInfo] = []

    for threshold, reward_type in _REWARD_THRESHOLDS:
        if unlocked_count < threshold:
            continue

        reward_id = f"{season}_{threshold}"
        reward_ref = (
            db.collection("users").document(uid)
            .collection("rewards").document(reward_id)
        )

        # Firestore 트랜잭션 — 동시 호출 시에도 중복 발급 차단
        @fs.transactional
        def _grant_if_absent(transaction, ref, t=threshold, rt=reward_type, s=season, rid=reward_id):
            snapshot = ref.get(transaction=transaction)
            if snapshot.exists:
                return False, snapshot.to_dict() or {}
            new_data = {
                "type": rt,
                "threshold": t,
                "season": s,
                "granted_at": fs.SERVER_TIMESTAMP,
                "code": f"DEMO-{uid[:6]}-{rid}",
                "redeemed_at": None,
            }
            transaction.set(ref, new_data)
            return True, new_data

        transaction = db.transaction()
        granted, data = _grant_if_absent(transaction, reward_ref)
        # SERVER_TIMESTAMP 는 트랜잭션 시점엔 sentinel 이라 ISO 변환 위해 재조회
        snapshot = reward_ref.get()
        info = _reward_doc_to_info(reward_id, snapshot.to_dict() or data)
        (newly if granted else already).append(info)

    response = RewardCheckResponse(
        season=season,
        unlocked_count=unlocked_count,
        newly_granted=newly,
        already_granted=already,
    )
    return jsonify({"data": response.model_dump()})


# ──────────────────── 보유 리워드 조회 ────────────────────

@users_rewards_bp.get("/me/rewards")
@require_firebase_auth
def get_rewards():
    db, err = _db_or_503()
    if err:
        return err

    uid = g.current_user["uid"]
    items: list[RewardInfo] = []
    for doc in db.collection("users").document(uid).collection("rewards").stream():
        items.append(_reward_doc_to_info(doc.id, doc.to_dict() or {}))
    items.sort(key=lambda r: r.granted_at, reverse=True)

    response = RewardListResponse(items=items)
    return jsonify({"data": response.model_dump()})
