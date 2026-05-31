"""Firestore 초기 시드 스크립트.

mock_data.py 의 ATTRACTIONS, ZONES, CONGESTION, DISCOUNTS 를 Firestore 에 적재.
+ 재방문 푸시 트리거 검증용 데모 사용자 3명.

실행: py -3.13 seed_firestore.py
멱등: 같은 doc id 로 덮어쓰므로 반복 실행 안전.
"""
import logging
from datetime import datetime, timedelta

import pytz
from firebase_admin import firestore as fs

from config import load_config
from firestore_client import get_db, init_firebase
from mock_data import ATTRACTIONS, CHAPTERS, CONGESTION, DISCOUNTS, FACILITIES, ZONES

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s — %(message)s")
log = logging.getLogger("seed")
_KST = pytz.timezone("Asia/Seoul")


def _strip_id(doc: dict) -> dict:
    """id 는 Firestore document id 로 사용하므로 본문에서 제외."""
    return {k: v for k, v in doc.items() if k != "id"}


def seed_attractions(db) -> None:
    batch = db.batch()
    for a in ATTRACTIONS:
        batch.set(db.collection("attractions").document(a["id"]), _strip_id(a))
    batch.commit()
    log.info("attractions: %d개 적재", len(ATTRACTIONS))


def seed_zones(db) -> None:
    batch = db.batch()
    for z in ZONES:
        batch.set(db.collection("zones").document(z["id"]), _strip_id(z))
    batch.commit()
    log.info("zones: %d개 적재", len(ZONES))


def seed_congestion(db) -> None:
    batch = db.batch()
    for zone_id, level in CONGESTION.items():
        batch.set(
            db.collection("congestion").document(zone_id),
            {"level": level, "updated_at": fs.SERVER_TIMESTAMP},
        )
    batch.commit()
    log.info("congestion: %d개 적재", len(CONGESTION))


def seed_discounts(db) -> None:
    batch = db.batch()
    for d in DISCOUNTS:
        batch.set(db.collection("discounts").document(d["id"]), _strip_id(d))
    batch.commit()
    log.info("discounts: %d개 적재", len(DISCOUNTS))


def seed_facilities(db) -> None:
    batch = db.batch()
    for f in FACILITIES:
        batch.set(db.collection("facilities").document(f["id"]), _strip_id(f))
    batch.commit()
    log.info("facilities: %d개 적재", len(FACILITIES))


def seed_chapters(db) -> None:
    batch = db.batch()
    for c in CHAPTERS:
        batch.set(db.collection("chapters").document(c["id"]), _strip_id(c))
    batch.commit()
    log.info("chapters: %d개 적재", len(CHAPTERS))


def seed_demo_users(db) -> None:
    """재방문 푸시 트리거 검증용. FCM 토큰은 더미 — FCM_DRY_RUN=true 에서만 안전."""
    now = datetime.now(_KST)
    users = [
        {
            "id": "demo_user_30d_incomplete",
            "fcmToken": "FAKE_TOKEN_DEMO_30D_INCOMPLETE",
            "lastVisitAt": now - timedelta(days=35),
            "hasIncompleteChapter": True,
        },
        {
            "id": "demo_user_14d",
            "fcmToken": "FAKE_TOKEN_DEMO_14D",
            "lastVisitAt": now - timedelta(days=20),
            "hasIncompleteChapter": False,
        },
        {
            "id": "demo_user_recent",
            "fcmToken": "FAKE_TOKEN_DEMO_RECENT",
            "lastVisitAt": now - timedelta(days=5),
            "hasIncompleteChapter": True,
        },
    ]
    batch = db.batch()
    for u in users:
        batch.set(db.collection("users").document(u["id"]), _strip_id(u))
    batch.commit()
    log.info("demo users: %d명 적재", len(users))


def main() -> None:
    config = load_config()
    init_firebase(config)
    db = get_db()

    seed_attractions(db)
    seed_zones(db)
    seed_congestion(db)
    seed_discounts(db)
    seed_facilities(db)
    seed_chapters(db)
    seed_demo_users(db)
    log.info("✅ 시드 완료")


if __name__ == "__main__":
    main()
