"""Flutter `lib/models/attraction.dart` 의 kAttractions 데이터를 백엔드용 JSON 으로 추출.

사용:
    python scripts/extract_attractions.py
    → backend/attractions.json 생성

프론트는 그대로 단일 진실 소스로 유지, 백엔드는 빌드 시 파생 JSON 만 사용.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "lib" / "models" / "attraction.dart"
OUT = ROOT / "backend" / "attractions.json"


# Attraction(...) 블록 하나당 dict 한 개.
# 각 필드를 일정한 형식으로 뽑기 위해 키별로 정규식.
PATTERNS = {
    "id":             re.compile(r"id:\s*'([^']+)'"),
    "name":           re.compile(r"name:\s*'([^']+)'"),
    "category":       re.compile(r"category:\s*'([^']+)'"),
    "zone":           re.compile(r"zone:\s*'([^']+)'"),
    "lat":            re.compile(r"lat:\s*([0-9.]+)"),
    "lng":            re.compile(r"lng:\s*([0-9.]+)"),
    "indoor":         re.compile(r"indoor:\s*(true|false)"),
    "heightLimit":    re.compile(r"heightLimit:\s*(\d+)"),
    "thrillLevel":    re.compile(r"thrillLevel:\s*(\d+)"),
    "waitMinutes":    re.compile(r"waitMinutes:\s*(\d+)"),
    "rating":         re.compile(r"rating:\s*([0-9.]+)"),
    "hasEasterEgg":   re.compile(r"hasEasterEgg:\s*(true|false)"),
    "chapter":        re.compile(r"chapter:\s*(?:'([^']+)'|null)"),
    "description":    re.compile(r"description:\s*'([^']+)'"),
    "icon":           re.compile(r"icon:\s*'([^']+)'"),
    "isOperating":    re.compile(r"isOperating:\s*(true|false)"),
}

# camelCase → snake_case 매핑 (백엔드 컨벤션 정렬용)
RENAME = {
    "heightLimit":  "height_limit",
    "thrillLevel":  "thrill_level",
    "waitMinutes":  "wait_minutes",
    "hasEasterEgg": "has_easter_egg",
    "isOperating":  "is_operating",
}

INT_KEYS = {"heightLimit", "thrillLevel", "waitMinutes"}
FLOAT_KEYS = {"lat", "lng", "rating"}
BOOL_KEYS = {"indoor", "hasEasterEgg", "isOperating"}


def parse_block(block: str) -> dict | None:
    out: dict = {}
    for key, pat in PATTERNS.items():
        m = pat.search(block)
        if not m:
            if key in {"chapter"}:
                out[RENAME.get(key, key)] = None
                continue
            return None  # 필수 필드 누락
        raw = m.group(1)
        if key in INT_KEYS:
            val: object = int(raw)
        elif key in FLOAT_KEYS:
            val = float(raw)
        elif key in BOOL_KEYS:
            val = raw == "true"
        else:
            val = raw
        out[RENAME.get(key, key)] = val
    return out


def main() -> int:
    if not SRC.exists():
        print(f"source not found: {SRC}", file=sys.stderr)
        return 1

    text = SRC.read_text(encoding="utf-8")

    # `const List<Attraction> kAttractions = [ ... ];` 안의 Attraction(...) 블록만 추출.
    # 각 블록은 `Attraction(` 로 시작해서 균형 잡힌 `),` 로 끝남.
    start_marker = "const List<Attraction> kAttractions"
    si = text.find(start_marker)
    if si < 0:
        print("kAttractions list not found", file=sys.stderr)
        return 2
    list_start = text.index("[", si)
    list_end = text.index("];", list_start)
    list_body = text[list_start + 1 : list_end]

    # 단순 split — 'Attraction(' 으로 split 후 각 chunk 가 한 엔트리.
    chunks = list_body.split("Attraction(")[1:]  # 첫 chunk 는 prefix
    attractions = []
    for ch in chunks:
        # 다음 'Attraction(' 까지가 본 블록의 끝. split 으로 이미 잘림.
        parsed = parse_block(ch)
        if parsed is None:
            print(f"WARN: skipped malformed block starting: {ch[:60]!r}", file=sys.stderr)
            continue
        attractions.append(parsed)

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(
        json.dumps(attractions, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"wrote {len(attractions)} attractions → {OUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
