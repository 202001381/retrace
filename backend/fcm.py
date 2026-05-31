"""Firebase Admin SDK 기반 FCM 발송."""

from __future__ import annotations

import logging

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
