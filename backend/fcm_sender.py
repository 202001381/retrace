"""FCM multicast 발송 래퍼."""
import logging
from typing import Dict, Iterable, Optional

from firebase_admin import messaging

log = logging.getLogger(__name__)


def send_to_tokens(
    tokens: Iterable[str],
    title: str,
    body: str,
    data: Optional[Dict[str, str]] = None,
    dry_run: bool = False,
) -> Dict[str, int]:
    """다중 토큰 발송. {'success': n, 'failure': n} 반환.

    send_each_for_multicast는 한 번에 500 토큰까지 처리.
    """
    tokens = [t for t in tokens if t]
    if not tokens:
        return {"success": 0, "failure": 0}

    message = messaging.MulticastMessage(
        tokens=tokens,
        notification=messaging.Notification(title=title, body=body),
        data=data or {},
    )
    response = messaging.send_each_for_multicast(message, dry_run=dry_run)
    log.info(
        "FCM 발송 (dry_run=%s) success=%d failure=%d",
        dry_run, response.success_count, response.failure_count,
    )
    return {"success": response.success_count, "failure": response.failure_count}
