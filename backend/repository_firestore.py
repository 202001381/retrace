"""Firestore 백엔드 — repository_mock.py와 동일한 함수 시그니처.

컬렉션 구조 (mock_data.py와 1:1):
    attractions/{id}    name, type, location {lat,lng}, zone_id, thrill_level, capacity, min_height_cm
    zones/{id}          name
    congestion/{zone_id} level (0-5)
    discounts/{id}      title, rate, active, condition {type, value}

각 함수는 문서를 dict로 변환하면서 doc.id를 'id' 키로 합쳐 mock과 동일한 모양을 반환한다.
"""
from typing import Optional

from firestore_client import get_db


def _doc_to_dict(doc) -> dict:
    return {**doc.to_dict(), "id": doc.id}


def list_attractions() -> list[dict]:
    return [_doc_to_dict(d) for d in get_db().collection("attractions").stream()]


def get_attraction(attraction_id: str) -> Optional[dict]:
    doc = get_db().collection("attractions").document(attraction_id).get()
    if not doc.exists:
        return None
    return _doc_to_dict(doc)


def list_zones() -> list[dict]:
    return [_doc_to_dict(d) for d in get_db().collection("zones").stream()]


def get_congestion(zone_id: str) -> int:
    doc = get_db().collection("congestion").document(zone_id).get()
    if not doc.exists:
        return 2  # 기본값 — 운영 데이터 누락 시 중간 혼잡도로 가정
    return int((doc.to_dict() or {}).get("level", 2))


def get_all_congestion() -> dict[str, int]:
    return {
        d.id: int((d.to_dict() or {}).get("level", 2))
        for d in get_db().collection("congestion").stream()
    }


def list_active_discounts() -> list[dict]:
    # active 필터는 Python에서 처리 (할인룰 수가 적어 풀스캔 비용 무시 가능)
    return [
        _doc_to_dict(d)
        for d in get_db().collection("discounts").stream()
        if (d.to_dict() or {}).get("active")
    ]


def list_facilities() -> list[dict]:
    return [_doc_to_dict(d) for d in get_db().collection("facilities").stream()]


def get_facility(facility_id: str) -> Optional[dict]:
    doc = get_db().collection("facilities").document(facility_id).get()
    if not doc.exists:
        return None
    return _doc_to_dict(doc)


def list_chapters(season: Optional[str] = None) -> list[dict]:
    if season is None:
        return [_doc_to_dict(d) for d in get_db().collection("chapters").stream()]
    # season 필터는 Python에서 (챕터 수가 적어 풀스캔 비용 무시 가능)
    return [
        _doc_to_dict(d)
        for d in get_db().collection("chapters").stream()
        if (d.to_dict() or {}).get("season") == season
    ]


def get_chapter(chapter_id: str) -> Optional[dict]:
    doc = get_db().collection("chapters").document(chapter_id).get()
    if not doc.exists:
        return None
    return _doc_to_dict(doc)
