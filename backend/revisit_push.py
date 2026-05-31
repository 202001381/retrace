"""Task 4 — 재방문 FCM 푸시 트리거.

매일 09:00 (KST) 전체 유저 순회 → 조건 평가 → 우선순위 1개만 발송.

우선순위:
  1) 계절 갱신일 (3/1, 6/1, 9/1, 12/1)
  2) 마지막 방문 후 30일 경과 + 미완성 챕터 ≥ 1
  3) 마지막 방문 후 14일 경과 + 모든 챕터 미완성
"""

from __future__ import annotations

import logging
from dataclasses import dataclass
from datetime import date, datetime, timedelta, timezone
from typing import Literal

from firebase_admin import messaging

from . import firestore_client
from .fcm import init_firebase

logger = logging.getLogger(__name__)
KST = timezone(timedelta(hours=9))

SEASON_KEYS: list[str] = ["spring", "summer", "autumn", "winter"]
SEASON_LABEL: dict[str, str] = {
    "spring": "봄",
    "summer": "여름",
    "autumn": "가을",
    "winter": "겨울",
}
SEASON_RENEWAL_MMDD: dict[tuple[int, int], str] = {
    (3, 1): "spring",
    (6, 1): "summer",
    (9, 1): "autumn",
    (12, 1): "winter",
}

TriggerKind = Literal["seasonal", "30day", "14day"]


@dataclass
class PushDecision:
    uid: str
    token: str
    kind: TriggerKind
    title: str
    body: str
    data: dict[str, str]


def _to_dt(v) -> datetime | None:
    if v is None:
        return None
    if isinstance(v, datetime):
        return v if v.tzinfo else v.replace(tzinfo=timezone.utc)
    try:
        # Firestore Timestamp
        return v.to_datetime() if hasattr(v, "to_datetime") else None
    except Exception:
        return None


def _incomplete_chapters(chapter_status: dict) -> list[str]:
    out: list[str] = []
    for k in SEASON_KEYS:
        cs = chapter_status.get(k) or {}
        if not cs.get("completed"):
            out.append(k)
    return out


def evaluate_user(
    uid: str,
    user_doc: dict,
    today: date | None = None,
) -> PushDecision | None:
    today = today or datetime.now(KST).date()
    token = (user_doc.get("fcm_token") or "").strip()
    if not token:
        return None

    chapter_status = user_doc.get("chapter_status") or {}
    last_visit_dt = _to_dt(user_doc.get("last_visit_at"))
    last_visit_date = last_visit_dt.astimezone(KST).date() if last_visit_dt else None
    days_since = (today - last_visit_date).days if last_visit_date else 10**6
    incomplete = _incomplete_chapters(chapter_status)

    # 1) 계절 갱신일 — 항상 1순위
    season_key = SEASON_RENEWAL_MMDD.get((today.month, today.day))
    if season_key:
        label = SEASON_LABEL[season_key]
        return PushDecision(
            uid=uid, token=token, kind="seasonal",
            title=f"새로운 {label} 챕터가 열렸어요",
            body="새로운 이야기를 시작해보세요",
            data={"trigger": "seasonal", "season": season_key},
        )

    # 2) 30일 + 미완성 ≥ 1
    if days_since >= 30 and incomplete:
        first_label = SEASON_LABEL[incomplete[0]]
        return PushDecision(
            uid=uid, token=token, kind="30day",
            title=f"아직 {first_label} 챕터가 미완성이에요",
            body="돌아올 시간이에요 🌙",
            data={"trigger": "30day", "incomplete": ",".join(incomplete)},
        )

    # 3) 14일 + 전부 미완성
    if days_since >= 14 and len(incomplete) == len(SEASON_KEYS):
        return PushDecision(
            uid=uid, token=token, kind="14day",
            title="아직 못 발견한 이야기가 남아있어요",
            body=f"미완성 챕터 {len(incomplete)}개",
            data={"trigger": "14day", "incomplete_count": str(len(incomplete))},
        )

    return None


def _send(decision: PushDecision) -> str:
    msg = messaging.Message(
        notification=messaging.Notification(title=decision.title, body=decision.body),
        data=decision.data,
        token=decision.token,
        android=messaging.AndroidConfig(priority="high"),
        apns=messaging.APNSConfig(
            payload=messaging.APNSPayload(
                aps=messaging.Aps(content_available=True, sound="default")
            )
        ),
    )
    return messaging.send(msg)


def run_revisit_push(today: date | None = None) -> dict:
    """전체 유저 평가 + 발송. 결과 요약 반환."""
    init_firebase()
    counts = {"seasonal": 0, "30day": 0, "14day": 0, "skipped": 0, "errors": 0}
    sent_uids: list[str] = []

    for uid, doc in firestore_client.iter_users():
        decision = evaluate_user(uid, doc, today=today)
        if decision is None:
            counts["skipped"] += 1
            continue
        try:
            _send(decision)
            counts[decision.kind] += 1
            sent_uids.append(uid)
        except Exception:
            counts["errors"] += 1
            logger.exception("FCM send failed for uid=%s", uid)

    summary = {"counts": counts, "sent": len(sent_uids)}
    logger.info("revisit push summary: %s", summary)
    return summary
