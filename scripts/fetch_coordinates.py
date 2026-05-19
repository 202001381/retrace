#!/usr/bin/env python3
"""서울랜드 어트랙션 좌표 자동 수집기.

Google Maps Places Text Search API 를 우선 사용하고, API 키가 없으면
OpenStreetMap Nominatim 으로 fallback. 결과를 attraction.dart 의
`lat: ..., lng: ...` 라인에 바로 복붙할 수 있는 형식으로 출력한다.

환경변수:
    GOOGLE_MAPS_API_KEY  — 있으면 Google Places Text Search 사용 (권장)
    .env 또는 셸 export 모두 인식.

사용법:
    python scripts/fetch_coordinates.py
    GOOGLE_MAPS_API_KEY=AIza... python scripts/fetch_coordinates.py
"""

from __future__ import annotations

import os
import sys
import time
from pathlib import Path
from typing import Optional

import requests

# python-dotenv 는 선택 의존성 — 없으면 셸 환경변수만 사용.
try:
    from dotenv import load_dotenv
    load_dotenv(Path(__file__).resolve().parent.parent / ".env")
except ImportError:
    pass

GOOGLE_KEY = os.getenv("GOOGLE_MAPS_API_KEY")

# (id, attraction.dart 의 표시명, Places API 검색 쿼리)
PLACES: list[tuple[str, str, str]] = [
    ("galaxy_888",     "은하열차 888",      "서울랜드 은하열차 888"),
    ("blackhole_2000", "블랙홀 2000",      "서울랜드 블랙홀 2000"),
    ("flume_ride",     "후룸라이드",        "서울랜드 후룸라이드"),
    ("gyro_swing",     "자이로스윙",        "서울랜드 자이로스윙"),
    ("ferris_wheel",   "대관람차",         "서울랜드 대관람차"),
    ("carousel",       "회전목마",         "서울랜드 회전목마"),
    ("bumper_car",     "범퍼카",          "서울랜드 범퍼카"),
    ("viking",         "바이킹",          "서울랜드 킹바이킹"),
    ("gyro_drop",      "자이로드롭",        "서울랜드 샷드롭"),
    ("flying_carpet",  "플라잉카펫",        "서울랜드 플라잉카펫"),
    ("cpk_restaurant", "CPK 레스토랑",     "서울랜드 캘리포니아피자키친"),
    ("rose_hill_cafe", "로즈힐 카페",      "서울랜드 로즈힐카페"),
]

GOOGLE_TEXTSEARCH = "https://maps.googleapis.com/maps/api/place/textsearch/json"
NOMINATIM = "https://nominatim.openstreetmap.org/search"

# 서울랜드 영역 bias (대략 200m 반경)
SEOULLAND_BIAS = "37.4278,126.9798"


def google_search(query: str) -> Optional[tuple[float, float]]:
    """Google Places Text Search. (lat, lng) 또는 None."""
    try:
        r = requests.get(
            GOOGLE_TEXTSEARCH,
            params={
                "query": query,
                "key": GOOGLE_KEY,
                "region": "kr",
                "language": "ko",
                "location": SEOULLAND_BIAS,
                "radius": "500",  # 500m 반경 우선
            },
            timeout=15,
        )
    except requests.RequestException as e:
        print(f"    ! network: {e}")
        return None
    if r.status_code != 200:
        print(f"    ! HTTP {r.status_code}: {r.text[:200]}")
        return None
    data = r.json()
    status = data.get("status")
    if status != "OK":
        print(f"    ! status={status} {data.get('error_message', '')}")
        return None
    results = data.get("results") or []
    if not results:
        return None
    loc = (results[0].get("geometry") or {}).get("location") or {}
    lat, lng = loc.get("lat"), loc.get("lng")
    return (lat, lng) if lat and lng else None


def nominatim_search(query: str) -> Optional[tuple[float, float]]:
    """OSM Nominatim — 어트랙션 단위 정밀도 기대 어려움. 보통 서울랜드 자체로 떨어짐."""
    # "서울랜드 X" 보다 "X, Seoul Land, Gwacheon, Korea" 가 영문 OSM 매치 확률 높음
    bare = query.replace("서울랜드 ", "").strip()
    q = f"{bare}, Seoul Land, Gwacheon, Korea"
    try:
        r = requests.get(
            NOMINATIM,
            params={"q": q, "format": "json", "limit": 1, "countrycodes": "kr"},
            headers={"User-Agent": "retrace-app/0.1 (https://example.com)"},
            timeout=15,
        )
    except requests.RequestException as e:
        print(f"    ! network: {e}")
        return None
    if r.status_code != 200:
        print(f"    ! HTTP {r.status_code}")
        return None
    data = r.json()
    if not data:
        return None
    return (float(data[0]["lat"]), float(data[0]["lon"]))


def main() -> int:
    if GOOGLE_KEY:
        source = "Google Places Text Search"
        rate_delay_s = 0.2
    else:
        source = "OpenStreetMap Nominatim (정확도 제한 — 보통 park-level)"
        rate_delay_s = 1.0  # Nominatim 정책: 1초/요청

    print(f"# source: {source}")
    print(f"# bias:   {SEOULLAND_BIAS}")
    print(f"# items:  {len(PLACES)}")
    print()

    rows: list[tuple[str, str, float, float]] = []
    failed: list[tuple[str, str]] = []

    for aid, name, query in PLACES:
        print(f"  ▶ {aid:18s} {query}")
        coord = google_search(query) if GOOGLE_KEY else nominatim_search(query)
        if coord:
            lat, lng = coord
            rows.append((aid, name, lat, lng))
            print(f"    → ({lat:.6f}, {lng:.6f})")
        else:
            failed.append((aid, query))
            print("    → ❌ 검색 결과 없음")
        time.sleep(rate_delay_s)

    # ── 결과 출력 ───────────────────────────────────────────
    print()
    print("─" * 70)
    print(f"# 성공 {len(rows)}/{len(PLACES)}  실패 {len(failed)}")
    print()
    print("# ── 사용자 명세 형식 (id/name/lat/lng) ──")
    for aid, name, lat, lng in rows:
        print(f"{{'id': '{aid}', 'name': '{name}', 'lat': {lat:.4f}, 'lng': {lng:.4f}}},")

    print()
    print("# ── lib/models/attraction.dart 교체용 (4자리) ──")
    for aid, _name, lat, lng in rows:
        print(f"#   {aid:18s}  lat: {lat:.4f}, lng: {lng:.4f},")

    if failed:
        print()
        print("# ── 검색 실패 — 수동 보정 필요 ──")
        for aid, q in failed:
            print(f"#   {aid:18s} {q}")

    return 0 if not failed else 1


if __name__ == "__main__":
    sys.exit(main())
