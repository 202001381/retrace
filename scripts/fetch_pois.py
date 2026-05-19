#!/usr/bin/env python3
"""서울랜드 POI 수집기 — 카카오 로컬 검색 API.

지정된 rect 영역에서 카테고리별로 POI 를 끌어와 assets/data/pois.json 으로 저장한다.

.env 필수 키:
    KAKAO_REST_API_KEY=...  # 카카오 개발자 콘솔 REST 키

사용법:
    python scripts/fetch_pois.py
"""

from __future__ import annotations

import json
import os
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterator

import requests
from dotenv import load_dotenv

# ─── 설정 ──────────────────────────────────────────────────
ROOT = Path(__file__).resolve().parent.parent
load_dotenv(ROOT / ".env")

API_KEY = os.getenv("KAKAO_REST_API_KEY")
if not API_KEY:
    sys.exit("ERROR: KAKAO_REST_API_KEY missing in .env (.env.example 참고)")

# 서울랜드 영역 (사용자 확정 범위)
RECT = "127.018,37.432,127.030,37.438"

# 카카오는 query 만 받는 keyword.json 과 category_group_code 단독을 받는 category.json 으로 분리됨.
ENDPOINT_KEYWORD = "https://dapi.kakao.com/v2/local/search/keyword.json"
ENDPOINT_CATEGORY = "https://dapi.kakao.com/v2/local/search/category.json"
HEADERS = {"Authorization": f"KakaoAK {API_KEY}"}

DELAY_MS = 200
PAGE_SIZE = 15  # 카카오 keyword/category 둘 다 1~15

OUT = ROOT / "assets" / "data" / "pois.json"

# (label, query, category_group_code)
# query 있으면 keyword.json, 없으면 category.json 으로 분기.
QUERIES: list[tuple[str, str | None, str | None]] = [
    ("어트랙션", "서울랜드", "AT4"),
    ("음식점",   None,       "FD6"),
    ("카페",     None,       "CE7"),
    ("편의점",   None,       "CS2"),
    ("굿즈샵",   "서울랜드 기프트샵", None),
]


# ─── 페치 ──────────────────────────────────────────────────
def fetch(label: str, query: str | None, code: str | None) -> Iterator[dict]:
    """label/query/code 조합으로 page 1~3 순회. is_end 시 조기 종료."""
    if query:
        url = ENDPOINT_KEYWORD
    elif code:
        url = ENDPOINT_CATEGORY
    else:
        print(f"  [{label}] query/code 모두 없음 — skip")
        return

    total = 0
    for page in range(1, 4):
        params: dict[str, object] = {"rect": RECT, "page": page, "size": PAGE_SIZE}
        if query:
            params["query"] = query
        if code:
            params["category_group_code"] = code

        try:
            r = requests.get(url, headers=HEADERS, params=params, timeout=15)
        except requests.RequestException as e:
            print(f"  [{label}] page={page} 네트워크 에러: {e}")
            return

        if r.status_code != 200:
            print(f"  [{label}] page={page} HTTP {r.status_code}: {r.text[:200]}")
            return

        data = r.json()
        docs = data.get("documents", []) or []
        for d in docs:
            yield d
        total += len(docs)

        is_end = data.get("meta", {}).get("is_end", True)
        if is_end:
            break
        time.sleep(DELAY_MS / 1000)

    print(f"  [{label}] {total}개 (page≤{page})")


def to_poi(doc: dict) -> dict:
    """카카오 응답 → 표준 POI dict. x=lng, y=lat 순서 주의."""
    return {
        "kakao_id": doc.get("id", ""),
        "place_name": doc.get("place_name", ""),
        "category_group_code": doc.get("category_group_code", ""),
        "category_name": doc.get("category_name", ""),
        "address_name": doc.get("address_name", ""),
        "road_address_name": doc.get("road_address_name", ""),
        "phone": doc.get("phone", ""),
        "place_url": doc.get("place_url", ""),
        "lat": float(doc.get("y", "0") or 0),
        "lng": float(doc.get("x", "0") or 0),
    }


# ─── 메인 ──────────────────────────────────────────────────
def main() -> int:
    print(f"rect={RECT}")
    print(f"out ={OUT.relative_to(ROOT)}")
    print("─" * 60)

    # ${place_name}_${x}_${y} 키로 중복 제거 (좌표는 소수점 7자리에서 자름)
    deduped: dict[str, dict] = {}
    label_counts: dict[str, int] = {}

    for label, query, code in QUERIES:
        print(f"▶ {label}  query={query!r}  code={code!r}")
        for doc in fetch(label, query, code):
            poi = to_poi(doc)
            key = f"{poi['place_name']}_{poi['lng']:.7f}_{poi['lat']:.7f}"
            if key in deduped:
                continue
            poi["_collected_via"] = label  # 어느 쿼리로 수집됐는지 기록
            deduped[key] = poi
            label_counts[label] = label_counts.get(label, 0) + 1
        time.sleep(DELAY_MS / 1000)

    pois = list(deduped.values())
    pois.sort(key=lambda p: (p["category_group_code"], p["place_name"]))

    print("─" * 60)
    print(f"수집 결과 (중복 제거 후): {len(pois)}개")
    for lbl, n in label_counts.items():
        print(f"  {lbl:8s}  {n}")
    print()
    # 범위 외 항목 검증
    out_of_rect = [p for p in pois if not (37.432 <= p["lat"] <= 37.438 and 127.018 <= p["lng"] <= 127.030)]
    if out_of_rect:
        print(f"⚠️  rect 범위 밖: {len(out_of_rect)}개 (확인 필요)")
        for p in out_of_rect[:5]:
            print(f"    - {p['place_name']}  ({p['lat']:.5f}, {p['lng']:.5f})  {p['address_name']}")

    OUT.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "fetched_at": datetime.now(timezone.utc).isoformat(),
        "rect": RECT,
        "source": "kakao_local_v2",
        "pois": pois,
    }
    OUT.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"✓ 저장 완료: {OUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
