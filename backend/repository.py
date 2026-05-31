"""데이터 접근 진입점.

환경변수 DATA_BACKEND 로 백엔드 선택:
    firestore (기본)  — repository_firestore
    mock              — repository_mock  (비상 시 / 오프라인 테스트)

pricing.py, recommend.py, story.py 는 이 파일만 import 하므로
백엔드 교체 시 호출부 무수정.
"""
import os

_backend = os.environ.get("DATA_BACKEND", "firestore").lower()

if _backend == "firestore":
    from repository_firestore import (
        get_all_congestion,
        get_attraction,
        get_chapter,
        get_congestion,
        get_facility,
        list_active_discounts,
        list_attractions,
        list_chapters,
        list_facilities,
        list_zones,
    )
elif _backend == "mock":
    from repository_mock import (
        get_all_congestion,
        get_attraction,
        get_chapter,
        get_congestion,
        get_facility,
        list_active_discounts,
        list_attractions,
        list_chapters,
        list_facilities,
        list_zones,
    )
else:
    raise RuntimeError(
        f"알 수 없는 DATA_BACKEND={_backend!r} (허용값: firestore, mock)"
    )

__all__ = [
    "get_all_congestion",
    "get_attraction",
    "get_chapter",
    "get_congestion",
    "get_facility",
    "list_active_discounts",
    "list_attractions",
    "list_chapters",
    "list_facilities",
    "list_zones",
]
