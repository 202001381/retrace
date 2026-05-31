"""mock 백엔드 — mock_data.py를 그대로 노출.

repository_firestore.py와 동일한 함수 시그니처를 유지한다.
"""
from typing import Optional

from mock_data import ATTRACTIONS, CHAPTERS, CONGESTION, DISCOUNTS, FACILITIES, ZONES


def list_attractions() -> list[dict]:
    return list(ATTRACTIONS)


def get_attraction(attraction_id: str) -> Optional[dict]:
    for a in ATTRACTIONS:
        if a["id"] == attraction_id:
            return a
    return None


def list_zones() -> list[dict]:
    return list(ZONES)


def get_congestion(zone_id: str) -> int:
    return CONGESTION.get(zone_id, 2)


def get_all_congestion() -> dict[str, int]:
    return dict(CONGESTION)


def list_active_discounts() -> list[dict]:
    return [d for d in DISCOUNTS if d.get("active")]


def list_facilities() -> list[dict]:
    return list(FACILITIES)


def get_facility(facility_id: str) -> Optional[dict]:
    for f in FACILITIES:
        if f["id"] == facility_id:
            return f
    return None


def list_chapters(season: Optional[str] = None) -> list[dict]:
    if season is None:
        return list(CHAPTERS)
    return [c for c in CHAPTERS if c.get("season") == season]


def get_chapter(chapter_id: str) -> Optional[dict]:
    for c in CHAPTERS:
        if c["id"] == chapter_id:
            return c
    return None
