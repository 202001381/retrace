"""사용자 데이터 엔드포인트 — FCM 토큰 / 이스터에그 / 연대기.

경로 prefix: /api/users/me
모든 엔드포인트 @require_firebase_auth (uid 식별 필수).

엔드포인트:
  POST /fcm-token         FCM 토큰 등록·갱신
  POST /easter-eggs       이스터에그 발견 기록 (idempotent)
  GET  /easter-eggs       발견 목록 + 진행률
  GET  /chronicle?season= 시즌별 챕터·책 상태 (이스터에그 기반 계산)

연대기는 저장하지 않고 GET 시점에 이스터에그 + chapters 정의로 derive.
저장 안 함 → 데이터 정합성 문제 없음, 트리거·동기화 코드 불필요.
"""
from datetime import datetime
from typing import Optional

import pytz
from firebase_admin import firestore as fs
from flask import Blueprint, current_app, g, jsonify, request

import repository
from auth import require_firebase_auth
from schemas import (
    BookStatus,
    ChapterStatus,
    ChronicleResponse,
    EasterEggCreateRequest,
    EasterEggInfo,
    EasterEggListResponse,
    FcmTokenRequest,
    FcmTokenResponse,
)

users_bp = Blueprint("users", __name__)
_KST = pytz.timezone("Asia/Seoul")


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
    """Firestore Timestamp / Python datetime → ISO 8601 문자열."""
    if timestamp is None:
        return None
    if hasattr(timestamp, "isoformat"):
        return timestamp.isoformat()
    if hasattr(timestamp, "to_pydatetime"):
        return timestamp.to_pydatetime().isoformat()
    return str(timestamp)


# ──────────────────── FCM 토큰 등록 ────────────────────

@users_bp.post("/me/fcm-token")
@require_firebase_auth
def post_fcm_token():
    payload = FcmTokenRequest.model_validate(request.get_json(silent=True) or {})
    db, err = _db_or_503()
    if err:
        return err

    uid = g.current_user["uid"]
    db.collection("users").document(uid).set(
        {
            "fcmToken": payload.fcm_token,
            "fcmPlatform": payload.platform,
            "fcmTokenUpdatedAt": fs.SERVER_TIMESTAMP,
        },
        merge=True,
    )
    return jsonify({"data": FcmTokenResponse(status="registered").model_dump()})


# ──────────────────── 이스터에그 ────────────────────

@users_bp.post("/me/easter-eggs")
@require_firebase_auth
def post_easter_egg():
    payload = EasterEggCreateRequest.model_validate(request.get_json(silent=True) or {})
    # 어트랙션 유효성
    attraction = repository.get_attraction(payload.attraction_id)
    if attraction is None:
        return jsonify({
            "error": {"code": "NOT_FOUND", "message": f"존재하지 않는 어트랙션: {payload.attraction_id}"}
        }), 404

    db, err = _db_or_503()
    if err:
        return err

    uid = g.current_user["uid"]
    # doc_id 가 attraction_id → 중복 발견은 자연 idempotent (덮어쓰기지만 found_at 갱신)
    egg_ref = (
        db.collection("users").document(uid)
        .collection("easterEggs").document(payload.attraction_id)
    )
    existing = egg_ref.get()
    if existing.exists:
        # 중복 발견은 200 + 기존 시각 반환 (idempotent)
        return jsonify({"data": {
            "attraction_id": payload.attraction_id,
            "name": attraction["name"],
            "found_at": _iso(existing.to_dict().get("found_at")),
            "newly_recorded": False,
        }})

    egg_ref.set({"found_at": fs.SERVER_TIMESTAMP})
    # 방금 쓴 값을 다시 읽어 ISO 변환
    written = egg_ref.get().to_dict() or {}
    return jsonify({"data": {
        "attraction_id": payload.attraction_id,
        "name": attraction["name"],
        "found_at": _iso(written.get("found_at")),
        "newly_recorded": True,
    }})


@users_bp.get("/me/easter-eggs")
@require_firebase_auth
def get_easter_eggs():
    db, err = _db_or_503()
    if err:
        return err

    uid = g.current_user["uid"]
    attraction_map = {a["id"]: a for a in repository.list_attractions()}

    items: list[EasterEggInfo] = []
    for doc in db.collection("users").document(uid).collection("easterEggs").stream():
        attraction = attraction_map.get(doc.id)
        if attraction is None:
            continue  # 어트랙션이 삭제된 경우 스킵
        items.append(EasterEggInfo(
            attraction_id=doc.id,
            name=attraction["name"],
            found_at=_iso((doc.to_dict() or {}).get("found_at")) or "",
        ))
    items.sort(key=lambda e: e.found_at, reverse=True)

    response = EasterEggListResponse(
        items=items,
        found_count=len(items),
        total_count=len(attraction_map),
    )
    return jsonify({"data": response.model_dump()})


# ──────────────────── 연대기 ────────────────────

@users_bp.get("/me/chronicle")
@require_firebase_auth
def get_chronicle():
    season = request.args.get("season") or _current_season()
    db, err = _db_or_503()
    if err:
        return err

    uid = g.current_user["uid"]
    chapters = repository.list_chapters(season=season)
    attraction_map = {a["id"]: a for a in repository.list_attractions()}

    eggs = {
        doc.id: (doc.to_dict() or {})
        for doc in db.collection("users").document(uid).collection("easterEggs").stream()
    }

    chapter_statuses: list[ChapterStatus] = []
    total_unlocked = 0
    total_books = 0
    for chapter in chapters:
        books: list[BookStatus] = []
        unlocked_in_chapter = 0
        for aid in chapter.get("required_attraction_ids", []):
            attraction = attraction_map.get(aid)
            if attraction is None:
                continue
            found = aid in eggs
            books.append(BookStatus(
                attraction_id=aid,
                name=attraction["name"],
                unlocked=found,
                found_at=_iso(eggs[aid].get("found_at")) if found else None,
            ))
            if found:
                unlocked_in_chapter += 1

        chapter_statuses.append(ChapterStatus(
            chapter_id=chapter["id"],
            name=chapter["name"],
            season=chapter["season"],
            books=books,
            unlocked_count=unlocked_in_chapter,
            total_count=len(books),
        ))
        total_unlocked += unlocked_in_chapter
        total_books += len(books)

    response = ChronicleResponse(
        season=season,
        chapters=chapter_statuses,
        total_unlocked=total_unlocked,
        total_books=total_books,
    )
    return jsonify({"data": response.model_dump()})
