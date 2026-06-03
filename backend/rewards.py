"""Task 5 — 시즌별 보상 (Rewards).

f&b 쿠폰 / 굿즈 / 자유이용권 등을 발급하는 모듈.

설계 핵심:
  - 시즌별 챕터 진행도(발견 어트랙션 수)가 threshold 도달 시 자동 발급.
  - threshold 3 → goods, threshold 5 → ticket (시즌 챕터 완성).
  - reward_id = '{season}_{threshold}' → 동일 시즌·threshold 중복 발급 차단.
  - Firestore 트랜잭션으로 동시 호출 중복 grant 방지.

v2 백엔드(rewards.py)에서 부분 도입. 우리 패턴(blueprint 미사용, pydantic 미사용)에 맞게
얇게 어댑트. Flutter `chapterTargets` 와 동일한 어트랙션 id 목록 유지.
"""

from __future__ import annotations

import logging
from datetime import date, datetime, timedelta, timezone
from typing import Iterable

from . import firestore_client

logger = logging.getLogger(__name__)
KST = timezone(timedelta(hours=9))

# Flutter lib/models/chapter.dart 의 chapterTargets 와 정확히 일치해야 함.
CHAPTER_TARGETS: dict[str, list[str]] = {
    "spring": ["a08", "a14", "a09", "a15", "a07"],
    "summer": ["a03", "a06", "a04", "a05", "a02"],
    "autumn": ["a01", "a07", "a12", "a14", "a08"],
    "winter": ["a13", "a11", "a02", "a10", "a08"],
}

# (threshold, reward_type)
REWARD_THRESHOLDS: list[tuple[int, str]] = [
    (3, "goods"),
    (5, "ticket"),
]


def current_season(today: date | None = None) -> str:
    """KST 기준 현재 시즌."""
    m = (today or datetime.now(KST).date()).month
    if 3 <= m <= 5:
        return "spring"
    if 6 <= m <= 8:
        return "summer"
    if 9 <= m <= 11:
        return "autumn"
    return "winter"


def _iso(ts) -> str | None:
    if ts is None:
        return None
    if isinstance(ts, datetime):
        return ts.isoformat()
    if hasattr(ts, "isoformat"):
        return ts.isoformat()
    if hasattr(ts, "to_datetime"):
        try:
            return ts.to_datetime().isoformat()
        except Exception:
            pass
    return str(ts)


def _doc_to_reward(reward_id: str, data: dict) -> dict:
    return {
        "reward_id": reward_id,
        "type": data.get("type", "goods"),
        "threshold": int(data.get("threshold", 0)),
        "season": data.get("season", "spring"),
        "granted_at": _iso(data.get("granted_at")) or "",
        "redeemed_at": _iso(data.get("redeemed_at")),
        "code": data.get("code"),
    }


def count_unlocked_books(uid: str, season: str, db=None) -> int:
    """현재 시즌의 챕터 타겟 어트랙션 중 사용자가 수집한 개수."""
    targets = set(CHAPTER_TARGETS.get(season, []))
    if not targets:
        return 0
    db = db or firestore_client.db()
    found = 0
    for doc in db.collection("users").document(uid).collection("easterEggs").stream():
        if doc.id in targets:
            found += 1
    return found


def _grant_reward_txn(db, uid: str, reward_id: str, threshold: int,
                      reward_type: str, season: str) -> tuple[bool, dict]:
    """리워드 1건 발급 (idempotent). 반환: (newly_granted, reward_dict)."""
    from firebase_admin import firestore as fs

    reward_ref = (
        db.collection("users").document(uid)
        .collection("rewards").document(reward_id)
    )

    @fs.transactional
    def _do(transaction, ref):
        snap = ref.get(transaction=transaction)
        if snap.exists:
            return False, snap.to_dict() or {}
        payload = {
            "type": reward_type,
            "threshold": threshold,
            "season": season,
            "granted_at": fs.SERVER_TIMESTAMP,
            "code": f"DEMO-{uid[:6]}-{reward_id}",
            "redeemed_at": None,
        }
        transaction.set(ref, payload)
        return True, payload

    granted, data = _do(db.transaction(), reward_ref)
    # SERVER_TIMESTAMP 는 트랜잭션 내부에서 sentinel 이라 재조회로 실제 시각 채움.
    snap = reward_ref.get()
    return granted, _doc_to_reward(reward_id, snap.to_dict() or data)


def check_and_grant(uid: str, today: date | None = None, db=None) -> dict:
    """현재 시즌 진행도 → threshold 도달 시 일괄 발급.

    반환:
      {
        season, unlocked_count,
        newly_granted: [reward, ...],
        already_granted: [reward, ...],
      }
    """
    db = db or firestore_client.db()
    season = current_season(today)
    unlocked = count_unlocked_books(uid, season, db=db)

    newly: list[dict] = []
    already: list[dict] = []
    for threshold, rtype in REWARD_THRESHOLDS:
        if unlocked < threshold:
            continue
        reward_id = f"{season}_{threshold}"
        is_new, reward = _grant_reward_txn(db, uid, reward_id, threshold, rtype, season)
        (newly if is_new else already).append(reward)

    return {
        "season": season,
        "unlocked_count": unlocked,
        "newly_granted": newly,
        "already_granted": already,
    }


def list_rewards(uid: str, db=None) -> list[dict]:
    """사용자 보유 리워드 전부 (최신순)."""
    db = db or firestore_client.db()
    items: list[dict] = []
    for doc in db.collection("users").document(uid).collection("rewards").stream():
        items.append(_doc_to_reward(doc.id, doc.to_dict() or {}))
    items.sort(key=lambda r: r.get("granted_at") or "", reverse=True)
    return items


def redeem_reward(uid: str, reward_id: str, db=None) -> dict | None:
    """사용 처리 — redeemed_at 채움. 이미 사용됐거나 없으면 None.

    실사용은 매장 측 POS 인증 흐름이 필요하지만, 베타 데모는 클라이언트 "사용 완료" 액션만
    기록한다.
    """
    db = db or firestore_client.db()
    ref = db.collection("users").document(uid).collection("rewards").document(reward_id)
    snap = ref.get()
    if not snap.exists:
        return None
    data = snap.to_dict() or {}
    if data.get("redeemed_at"):
        return _doc_to_reward(reward_id, data)
    from firebase_admin import firestore as fs
    ref.update({"redeemed_at": fs.SERVER_TIMESTAMP})
    snap = ref.get()
    return _doc_to_reward(reward_id, snap.to_dict() or {})
