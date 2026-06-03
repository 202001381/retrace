"""Firebase Admin SDK 기반 FCM 발송."""

from __future__ import annotations

import logging
from typing import Iterable

import firebase_admin
from firebase_admin import credentials, messaging

from . import config

logger = logging.getLogger(__name__)

_initialized = False


def init_firebase() -> None:
    global _initialized
    if _initialized:
        return
    if not config.FIREBASE_CREDENTIALS_PATH.exists():
        raise FileNotFoundError(
            f"firebase admin credentials not found at {config.FIREBASE_CREDENTIALS_PATH}"
        )
    cred = credentials.Certificate(str(config.FIREBASE_CREDENTIALS_PATH))
    firebase_admin.initialize_app(cred)
    _initialized = True


def send_topic(
    title: str,
    body: str,
    *,
    topic: str | None = None,
    data: dict[str, str] | None = None,
) -> str:
    """토픽 구독자 전원에게 푸시 발송."""
    init_firebase()
    msg = messaging.Message(
        notification=messaging.Notification(title=title, body=body),
        data=data or {},
        topic=topic or config.FCM_TOPIC,
        android=messaging.AndroidConfig(priority="high"),
        apns=messaging.APNSConfig(
            payload=messaging.APNSPayload(
                aps=messaging.Aps(content_available=True, sound="default")
            )
        ),
    )
    msg_id = messaging.send(msg)
    logger.info("FCM sent: id=%s topic=%s", msg_id, topic or config.FCM_TOPIC)
    return msg_id


def send_to_tokens(
    tokens: Iterable[str],
    title: str,
    body: str,
    *,
    data: dict[str, str] | None = None,
    dry_run: bool = False,
) -> dict[str, int]:
    """다중 토큰 multicast 발송 (v2 백엔드 fcm_sender 부분 도입).

    개별 사용자 대상 푸시(예: 발급된 리워드 알림) 에 사용. 빈 토큰은 자동 필터.
    한 번에 최대 500 개까지 처리 — 그 이상이면 호출부에서 chunk 필요.

    반환: {'success': n, 'failure': n}.
    """
    init_firebase()
    valid = [t for t in tokens if t]
    if not valid:
        return {"success": 0, "failure": 0}
    msg = messaging.MulticastMessage(
        tokens=valid,
        notification=messaging.Notification(title=title, body=body),
        data=data or {},
        android=messaging.AndroidConfig(priority="high"),
        apns=messaging.APNSConfig(
            payload=messaging.APNSPayload(
                aps=messaging.Aps(content_available=True, sound="default")
            )
        ),
    )
    resp = messaging.send_each_for_multicast(msg, dry_run=dry_run)
    logger.info(
        "FCM multicast (dry_run=%s) success=%d failure=%d",
        dry_run, resp.success_count, resp.failure_count,
    )
    return {"success": resp.success_count, "failure": resp.failure_count}
