"""mock 데이터 — Firestore 풀리기 전 임시 데이터 소스.

데이터 구조는 Firestore 스키마와 1:1 매칭. repository_mock.py 가 그대로 노출.

좌표: 서울랜드 부지를 약 500m × 500m 정사각형으로 가정, 중심 37.4357 / 127.0064.
어트랙션은 ±150m, 부대시설은 부지 곳곳에 분산. 실제 정확한 위치는 운영 시 보정 필요.
"""

# ────────────────────────────────────────────────────────────────────
#  ATTRACTIONS — 어트랙션 18개
#  필드:
#    id, name, type(coaster|family|water|swing|spinner|drop_tower|interactive|observation|kids_ride)
#    location {lat, lng}, zone_id, thrill_level(1-5), capacity, min_height_cm
#    stay_minutes  — 1회 탑승 시간 (대기 제외)
# ────────────────────────────────────────────────────────────────────

ATTRACTIONS: list[dict] = [
    {
        "id": "carousel",
        "name": "회전목마",
        "type": "family",
        "location": {"lat": 37.4358, "lng": 127.0063},
        "zone_id": "central",
        "thrill_level": 1,
        "capacity": 60,
        "min_height_cm": None,
        "stay_minutes": 5,
    },
    {
        "id": "blackhole_2000",
        "name": "블랙홀 2000",
        "type": "coaster",
        "location": {"lat": 37.4352, "lng": 127.0069},
        "zone_id": "thrill",
        "thrill_level": 5,
        "capacity": 24,
        "min_height_cm": 130,
        "stay_minutes": 4,
    },
    {
        "id": "flume_ride",
        "name": "후룸라이드",
        "type": "water",
        "location": {"lat": 37.4361, "lng": 127.0072},
        "zone_id": "thrill",
        "thrill_level": 3,
        "capacity": 40,
        "min_height_cm": 110,
        "stay_minutes": 6,
    },
    {
        "id": "shot_drop",
        "name": "샷드롭",
        "type": "drop_tower",
        "location": {"lat": 37.4355, "lng": 127.0058},
        "zone_id": "thrill",
        "thrill_level": 5,
        "capacity": 20,
        "min_height_cm": 130,
        "stay_minutes": 3,
    },
    {
        "id": "double_rock_spin",
        "name": "더블락스핀",
        "type": "spinner",
        "location": {"lat": 37.4360, "lng": 127.0060},
        "zone_id": "thrill",
        "thrill_level": 4,
        "capacity": 24,
        "min_height_cm": 120,
        "stay_minutes": 4,
    },
    {
        "id": "viking",
        "name": "바이킹",
        "type": "swing",
        "location": {"lat": 37.4354, "lng": 127.0066},
        "zone_id": "thrill",
        "thrill_level": 3,
        "capacity": 50,
        "min_height_cm": 110,
        "stay_minutes": 4,
    },
    {
        "id": "bumper_car",
        "name": "범퍼카",
        "type": "interactive",
        "location": {"lat": 37.4357, "lng": 127.0061},
        "zone_id": "central",
        "thrill_level": 2,
        "capacity": 30,
        "min_height_cm": 100,
        "stay_minutes": 5,
    },
    {
        "id": "spinning_swing",
        "name": "회전그네",
        "type": "swing",
        "location": {"lat": 37.4359, "lng": 127.0065},
        "zone_id": "family",
        "thrill_level": 2,
        "capacity": 32,
        "min_height_cm": 100,
        "stay_minutes": 4,
    },
    {
        "id": "ferris_wheel",
        "name": "대관람차",
        "type": "observation",
        "location": {"lat": 37.4350, "lng": 127.0070},
        "zone_id": "central",
        "thrill_level": 1,
        "capacity": 80,
        "min_height_cm": None,
        "stay_minutes": 12,
    },
    {
        "id": "mini_viking",
        "name": "미니바이킹",
        "type": "swing",
        "location": {"lat": 37.4362, "lng": 127.0067},
        "zone_id": "kids",
        "thrill_level": 1,
        "capacity": 20,
        "min_height_cm": 90,
        "stay_minutes": 4,
    },
    {
        "id": "biryong_train",
        "name": "비룡열차",
        "type": "coaster",
        "location": {"lat": 37.4356, "lng": 127.0073},
        "zone_id": "family",
        "thrill_level": 2,
        "capacity": 28,
        "min_height_cm": 100,
        "stay_minutes": 5,
    },
    {
        "id": "magic_swing",
        "name": "매직스윙",
        "type": "swing",
        "location": {"lat": 37.4353, "lng": 127.0062},
        "zone_id": "thrill",
        "thrill_level": 4,
        "capacity": 24,
        "min_height_cm": 120,
        "stay_minutes": 4,
    },
    {
        "id": "dokkaebi_academy",
        "name": "도깨비 아카데미",
        "type": "kids_ride",
        "location": {"lat": 37.4363, "lng": 127.0064},
        "zone_id": "kids",
        "thrill_level": 1,
        "capacity": 16,
        "min_height_cm": None,
        "stay_minutes": 6,
    },
    {
        "id": "jumping_fly",
        "name": "점핑플라이",
        "type": "drop_tower",
        "location": {"lat": 37.4351, "lng": 127.0067},
        "zone_id": "thrill",
        "thrill_level": 4,
        "capacity": 20,
        "min_height_cm": 110,
        "stay_minutes": 3,
    },
    {
        "id": "disco_coaster",
        "name": "디스코드 코스터",
        "type": "coaster",
        "location": {"lat": 37.4358, "lng": 127.0070},
        "zone_id": "family",
        "thrill_level": 3,
        "capacity": 24,
        "min_height_cm": 110,
        "stay_minutes": 4,
    },
    {
        "id": "spinning_boat",
        "name": "회전 보트",
        "type": "water",
        "location": {"lat": 37.4364, "lng": 127.0071},
        "zone_id": "kids",
        "thrill_level": 1,
        "capacity": 20,
        "min_height_cm": 90,
        "stay_minutes": 5,
    },
    {
        "id": "eighty_eight_train",
        "name": "88 열차",
        "type": "coaster",
        "location": {"lat": 37.4349, "lng": 127.0062},
        "zone_id": "family",
        "thrill_level": 2,
        "capacity": 32,
        "min_height_cm": 100,
        "stay_minutes": 6,
    },
    {
        "id": "mini_carousel",
        "name": "미니 회전목마",
        "type": "kids_ride",
        "location": {"lat": 37.4365, "lng": 127.0062},
        "zone_id": "kids",
        "thrill_level": 1,
        "capacity": 24,
        "min_height_cm": None,
        "stay_minutes": 4,
    },
]

# ────────────────────────────────────────────────────────────────────
#  FACILITIES — 부대시설 12개 (식당 5·화장실 3·포토존 3·입구 1)
#  필드:
#    id, name, type(restaurant|restroom|photo_spot|entrance)
#    location {lat, lng}, stay_minutes, description?
# ────────────────────────────────────────────────────────────────────

FACILITIES: list[dict] = [
    {
        "id": "main_entrance",
        "name": "메인 입구",
        "type": "entrance",
        "location": {"lat": 37.4346, "lng": 127.0058},
        "stay_minutes": 0,
        "description": "서울랜드 정문 — 일반 GPS 시작점",
    },
    # ── 식당 5 ──
    {
        "id": "korean_diner",
        "name": "한식관",
        "type": "restaurant",
        "location": {"lat": 37.4356, "lng": 127.0060},
        "stay_minutes": 35,
        "description": "비빔밥·돈가스 등 식사류",
    },
    {
        "id": "food_court",
        "name": "푸드코트",
        "type": "restaurant",
        "location": {"lat": 37.4360, "lng": 127.0064},
        "stay_minutes": 30,
        "description": "다양한 메뉴 한 곳에",
    },
    {
        "id": "dessert_cafe",
        "name": "디저트 카페",
        "type": "restaurant",
        "location": {"lat": 37.4361, "lng": 127.0058},
        "stay_minutes": 20,
        "description": "음료·케이크·아이스크림",
    },
    {
        "id": "chicken_shop",
        "name": "치킨 샵",
        "type": "restaurant",
        "location": {"lat": 37.4350, "lng": 127.0073},
        "stay_minutes": 25,
        "description": "치킨·감자튀김 단품",
    },
    {
        "id": "snack_kiosk",
        "name": "간이매점",
        "type": "restaurant",
        "location": {"lat": 37.4363, "lng": 127.0068},
        "stay_minutes": 10,
        "description": "핫도그·츄러스·음료",
    },
    # ── 화장실 3 ──
    {
        "id": "restroom_central",
        "name": "화장실 (중앙)",
        "type": "restroom",
        "location": {"lat": 37.4357, "lng": 127.0064},
        "stay_minutes": 5,
    },
    {
        "id": "restroom_north",
        "name": "화장실 (북쪽)",
        "type": "restroom",
        "location": {"lat": 37.4364, "lng": 127.0066},
        "stay_minutes": 5,
    },
    {
        "id": "restroom_south",
        "name": "화장실 (남쪽)",
        "type": "restroom",
        "location": {"lat": 37.4348, "lng": 127.0063},
        "stay_minutes": 5,
    },
    # ── 포토존 3 ──
    {
        "id": "entrance_gate_photo",
        "name": "입구 게이트 포토존",
        "type": "photo_spot",
        "location": {"lat": 37.4347, "lng": 127.0059},
        "stay_minutes": 5,
        "description": "정문 아치 앞 기념 촬영",
    },
    {
        "id": "character_statue",
        "name": "캐릭터 동상",
        "type": "photo_spot",
        "location": {"lat": 37.4358, "lng": 127.0067},
        "stay_minutes": 5,
        "description": "마스코트 동상과 함께",
    },
    {
        "id": "lake_view_photo",
        "name": "호수 전망 포토존",
        "type": "photo_spot",
        "location": {"lat": 37.4366, "lng": 127.0064},
        "stay_minutes": 8,
        "description": "북쪽 호수 풍경 배경",
    },
]


# ────────────────────────────────────────────────────────────────────
#  ZONES / CONGESTION / DISCOUNTS — 변경 없음
# ────────────────────────────────────────────────────────────────────

ZONES: list[dict] = [
    {"id": "central", "name": "중앙광장"},
    {"id": "thrill", "name": "스릴 존"},
    {"id": "family", "name": "패밀리 존"},
    {"id": "kids", "name": "어린이 존"},
]

# 0-5 (0: 매우 한산, 5: 매우 혼잡). 실제로는 5분마다 갱신될 데이터.
CONGESTION: dict[str, int] = {
    "central": 3,
    "thrill": 4,
    "family": 2,
    "kids": 1,
}

# ────────────────────────────────────────────────────────────────────
#  CHAPTERS — 연대기 챕터 8개 (4시즌 × 2챕터, 챕터당 3책 = 24슬롯)
#  필드:
#    id, name, season(spring|summer|autumn|winter),
#    required_attraction_ids — 이 어트랙션에서 이스터에그를 발견하면 책 unlock
#
#  attractions 가 18개라 일부 인기 어트랙션이 여러 챕터에 재등장.
# ────────────────────────────────────────────────────────────────────

CHAPTERS: list[dict] = [
    # ── 봄 ──
    {
        "id": "chapter_spring_intro",
        "name": "봄 인사 — 첫 만남의 챕터",
        "season": "spring",
        "required_attraction_ids": ["carousel", "spinning_swing", "mini_carousel"],
    },
    {
        "id": "chapter_spring_family",
        "name": "봄 산책 — 가족의 챕터",
        "season": "spring",
        "required_attraction_ids": ["ferris_wheel", "bumper_car", "biryong_train"],
    },
    # ── 여름 ──
    {
        "id": "chapter_summer_water",
        "name": "여름 물결 — 시원함의 챕터",
        "season": "summer",
        "required_attraction_ids": ["flume_ride", "spinning_boat", "double_rock_spin"],
    },
    {
        "id": "chapter_summer_thrill",
        "name": "여름 폭풍 — 스릴의 챕터",
        "season": "summer",
        "required_attraction_ids": ["shot_drop", "jumping_fly", "magic_swing"],
    },
    # ── 가을 ──
    {
        "id": "chapter_autumn_coaster",
        "name": "가을 질주 — 코스터의 챕터",
        "season": "autumn",
        "required_attraction_ids": ["blackhole_2000", "disco_coaster", "eighty_eight_train"],
    },
    {
        "id": "chapter_autumn_swing",
        "name": "가을 바람 — 흔들림의 챕터",
        "season": "autumn",
        "required_attraction_ids": ["viking", "mini_viking", "magic_swing"],
    },
    # ── 겨울 ──
    {
        "id": "chapter_winter_kids",
        "name": "겨울 동화 — 어린이의 챕터",
        "season": "winter",
        "required_attraction_ids": ["dokkaebi_academy", "mini_carousel", "spinning_swing"],
    },
    {
        "id": "chapter_winter_indoor",
        "name": "겨울 온실 — 실내의 챕터",
        "season": "winter",
        "required_attraction_ids": ["blackhole_2000", "ferris_wheel", "bumper_car"],
    },
]


DISCOUNTS: list[dict] = [
    {
        "id": "rainy_day",
        "title": "비 오는 날 자유이용권 20% 할인",
        "rate": 0.20,
        "active": True,
        "condition": {"type": "weather", "value": "rainy"},
    },
    {
        "id": "cloudy_special",
        "title": "흐린 날 자유이용권 10% 할인",
        "rate": 0.10,
        "active": True,
        "condition": {"type": "weather", "value": "cloudy"},
    },
    {
        "id": "weekday_student",
        "title": "평일 학생 할인",
        "rate": 0.15,
        "active": True,
        "condition": {"type": "time", "value": "weekday"},
    },
    {
        "id": "winter_special",
        "title": "겨울 시즌 패키지",
        "rate": 0.25,
        "active": True,
        "condition": {"type": "season", "value": "winter"},
    },
]
