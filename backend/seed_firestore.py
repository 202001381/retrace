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
import random

from mock_data import (
    ATTRACTIONS,
    CHAPTERS,
    CONGESTION,
    DISCOUNTS,
    FACILITIES,
    FNB_COUPONS,
    ZONES,
)

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


def seed_fnb_coupons(db) -> None:
    batch = db.batch()
    for c in FNB_COUPONS:
        batch.set(db.collection("fnb_coupons").document(c["id"]), _strip_id(c))
    batch.commit()
    log.info("fnb_coupons: %d개 적재", len(FNB_COUPONS))


def seed_demo_events(db, n: int = 200) -> None:
    """KPI 검증용 데모 이벤트 200건 시드. uid·type·properties 다양하게 분포.

    A/B 비교가 의미 있도록 recommended 그룹이 control 보다 체류 시간·방문 어트랙션 ↑ 가도록 편향.
    """
    rng = random.Random(42)
    now = datetime.now(_KST)

    # 데모 uid 풀 — 시드 사용자 3 + 가상 uid 12 (그룹별 6:6 분배)
    recommended_uids = [f"sim_rec_{i:02d}" for i in range(6)]
    control_uids = [f"sim_ctl_{i:02d}" for i in range(6)] + ["demo_user_recent"]

    # users 컬렉션에 group 부여 (가상 uid 들은 새로 생성)
    batch = db.batch()
    for uid in recommended_uids:
        batch.set(db.collection("users").document(uid), {
            "group": "recommended", "fcmToken": f"FAKE_{uid}",
            "lastVisitAt": now,
        }, merge=True)
    for uid in control_uids:
        batch.set(db.collection("users").document(uid), {
            "group": "control",
        }, merge=True)
    # 기존 데모 사용자 3명에도 group 부여
    batch.set(db.collection("users").document("demo_user_30d_incomplete"),
              {"group": "recommended"}, merge=True)
    batch.set(db.collection("users").document("demo_user_14d"),
              {"group": "control"}, merge=True)
    batch.commit()

    coupon_pool = [c["id"] for c in FNB_COUPONS] + ["weekday_student", "rainy_day"]
    attraction_pool = [a["id"] for a in ATTRACTIONS]

    # 이벤트 생성
    batch = db.batch()
    written = 0
    for i in range(n):
        uid = rng.choice(recommended_uids + control_uids)
        is_rec = uid in recommended_uids
        ts = now - timedelta(minutes=rng.randint(0, 60 * 24 * 7))  # 최근 7일
        evt_type = rng.choices(
            population=[
                "coupon_click", "ticket_purchase", "visit_arrive", "visit_leave",
                "attraction_select", "coupon_redeem", "fnb_purchase",
            ],
            weights=[18, 8, 25, 22, 10, 7, 10],
            k=1,
        )[0]

        props: dict = {}
        if evt_type in ("coupon_click", "coupon_redeem"):
            props["coupon_id"] = rng.choice(coupon_pool)
        elif evt_type in ("visit_arrive", "visit_leave", "attraction_select", "ticket_purchase"):
            props["attraction_id"] = rng.choice(attraction_pool)
            if evt_type == "attraction_select":
                # recommended 그룹은 rank=1 선택 비율 ↑, control 은 골고루
                if is_rec:
                    props["rank"] = rng.choices([1, 2, 3], weights=[7, 2, 1])[0]
                else:
                    props["rank"] = rng.choices([1, 2, 3], weights=[4, 3, 3])[0]
        elif evt_type == "fnb_purchase":
            # 객단가: recommended 그룹이 약간 ↑
            base = 12_000 if is_rec else 9_000
            props["amount"] = base + rng.randint(-2000, 5000)
            props["outlet_id"] = rng.choice([c["outlet_id"] for c in FNB_COUPONS])

        doc_ref = db.collection("events").document()
        batch.set(doc_ref, {
            "uid": uid,
            "type": evt_type,
            "timestamp": ts,
            "properties": props,
        })
        written += 1
        if written % 100 == 0:
            batch.commit()
            batch = db.batch()
    batch.commit()
    log.info("events: %d건 시드 (recommended %d 명 + control %d 명)",
             n, len(recommended_uids), len(control_uids))


def seed_demo_easter_eggs(db) -> None:
    """KPI 3 (참여율·챕터 완료) 의미 있는 통계 위해 데모 이스터에그 분포."""
    rng = random.Random(7)
    attraction_ids = [a["id"] for a in ATTRACTIONS]

    # 시뮬레이션 사용자 중 일부에게 이스터에그 발견 기록
    test_users = [f"sim_rec_{i:02d}" for i in range(6)] + [f"sim_ctl_{i:02d}" for i in range(6)]
    batch = db.batch()
    for uid in test_users:
        # 평균 4개 발견 (0~10 균등)
        found_n = rng.randint(0, 10)
        sample = rng.sample(attraction_ids, k=min(found_n, len(attraction_ids)))
        for aid in sample:
            batch.set(
                db.collection("users").document(uid)
                  .collection("easterEggs").document(aid),
                {"found_at": datetime.now(_KST) - timedelta(days=rng.randint(0, 30))},
            )
    batch.commit()
    log.info("demo easter eggs: %d 명에게 분포 시드", len(test_users))


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
    seed_fnb_coupons(db)
    seed_demo_users(db)
    seed_demo_easter_eggs(db)
    seed_demo_events(db)
    log.info("✅ 시드 완료")


if __name__ == "__main__":
    main()
