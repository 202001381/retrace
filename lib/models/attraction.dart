import 'package:latlong2/latlong.dart';

/// 앱 전체(MAP, 추천, Archive) 공통 단일 데이터 소스.
class Attraction {
  final String id;
  final String name;
  final String category;     // '어트랙션' | '음식점' | '카페' | '포토스팟'
  final String zone;
  final double lat;
  final double lng;
  final bool indoor;
  /// 키 제한(cm). 0 = 제한 없음.
  final int heightLimit;
  /// 스릴 강도 1~5. (음식점은 0)
  final int thrillLevel;
  /// 예상 대기시간(분).
  final int waitMinutes;
  final double rating;
  final bool hasEasterEgg;
  /// 'spring' | 'summer' | 'autumn' | 'winter' | null
  final String? chapter;
  final String description;
  final String icon;
  final bool isOperating;
  /// 좌표 실측 검증 여부. false = zone-level 추정값 (베타 전 보정 필요).
  final bool coordsVerified;

  const Attraction({
    required this.id,
    required this.name,
    required this.category,
    required this.zone,
    required this.lat,
    required this.lng,
    required this.indoor,
    required this.heightLimit,
    required this.thrillLevel,
    required this.waitMinutes,
    required this.rating,
    required this.hasEasterEgg,
    required this.chapter,
    required this.description,
    required this.icon,
    required this.isOperating,
    this.coordsVerified = false,
  });

  LatLng get position => LatLng(lat, lng);

  String get crowdLabel {
    if (waitMinutes <= 5) return '여유';
    if (waitMinutes <= 20) return '보통';
    return '혼잡';
  }
}

// 좌표: 서울랜드 실제 위치(37.4279, 127.0247) 기준 테마존 추정값.
// 각 엔트리 coordsVerified=false → 베타 출시 전 현장 GPS / 운영팀 데이터로 보정 필요.
const List<Attraction> kAttractions = [
  Attraction(
    id: 'galaxy_888',
    name: '은하열차 888',
    category: '어트랙션',
    zone: '미래의 나라',
    lat: 37.4357, lng: 127.0209,
    indoor: false, heightLimit: 110, thrillLevel: 4, waitMinutes: 15,
    rating: 4.5, hasEasterEgg: true, chapter: 'autumn',
    description: '서울랜드 대표 스릴 어트랙션. 빠른 속도의 롤러코스터.',
    icon: '🎢', isOperating: true,
  ),
  Attraction(
    id: 'blackhole_2000',
    name: '블랙홀 2000',
    category: '어트랙션',
    zone: '미래의 나라',
    lat: 37.4354, lng: 127.0199,
    indoor: true, heightLimit: 120, thrillLevel: 5, waitMinutes: 25,
    rating: 4.7, hasEasterEgg: true, chapter: 'autumn',
    description: '어둠 속 스크류 코스터. 서울랜드 최고 스릴 어트랙션.',
    icon: '🌀', isOperating: true,
  ),
  Attraction(
    id: 'flume_ride',
    name: '후룸라이드',
    category: '어트랙션',
    zone: '세계의 광장',
    lat: 37.434, lng: 127.0193,
    indoor: false, heightLimit: 110, thrillLevel: 3, waitMinutes: 20,
    rating: 4.3, hasEasterEgg: true, chapter: 'summer',
    description: '물길을 따라 내려오는 보트 어트랙션.',
    icon: '🌊', isOperating: true,
  ),
  Attraction(
    id: 'gyro_swing',
    name: '자이로스윙',
    category: '어트랙션',
    zone: '모험의 나라',
    lat: 37.4336, lng: 127.0203,
    indoor: false, heightLimit: 130, thrillLevel: 4, waitMinutes: 30,
    rating: 4.4, hasEasterEgg: false, chapter: 'autumn',
    description: '360도 회전하는 스윙 어트랙션.',
    icon: '🎡', isOperating: true,
  ),
  Attraction(
    id: 'ferris_wheel',
    name: '대관람차',
    category: '어트랙션',
    zone: '세계의 광장',
    lat: 37.4338, lng: 127.0186,
    indoor: false, heightLimit: 0, thrillLevel: 1, waitMinutes: 10,
    rating: 4.2, hasEasterEgg: true, chapter: 'spring',
    description: '서울랜드 전경을 한눈에 볼 수 있는 대형 관람차.',
    icon: '🎠', isOperating: true,
  ),
  Attraction(
    id: 'carousel',
    name: '회전목마',
    category: '어트랙션',
    zone: '캐릭터 타운',
    lat: 37.4333, lng: 127.0181,
    indoor: false, heightLimit: 0, thrillLevel: 1, waitMinutes: 5,
    rating: 4.0, hasEasterEgg: true, chapter: 'spring',
    description: '1988년 개장 당시부터 함께한 서울랜드의 상징.',
    icon: '🎠', isOperating: true,
  ),
  Attraction(
    id: 'bumper_car',
    name: '범퍼카',
    category: '어트랙션',
    zone: '캐릭터 타운',
    lat: 37.433, lng: 127.0185,
    indoor: true, heightLimit: 0, thrillLevel: 2, waitMinutes: 15,
    rating: 4.1, hasEasterEgg: false, chapter: 'spring',
    description: '남녀노소 즐길 수 있는 실내 범퍼카.',
    icon: '🚗', isOperating: true,
  ),
  Attraction(
    id: 'viking',
    name: '바이킹',
    category: '어트랙션',
    zone: '모험의 나라',
    lat: 37.4339, lng: 127.02,
    indoor: false, heightLimit: 120, thrillLevel: 3, waitMinutes: 20,
    rating: 4.2, hasEasterEgg: true, chapter: 'summer',
    description: '좌우로 크게 흔들리는 해적선 어트랙션.',
    icon: '⚓', isOperating: true,
  ),
  Attraction(
    id: 'gyro_drop',
    name: '자이로드롭',
    category: '어트랙션',
    zone: '미래의 나라',
    lat: 37.4351, lng: 127.0204,
    indoor: false, heightLimit: 140, thrillLevel: 5, waitMinutes: 35,
    rating: 4.6, hasEasterEgg: false, chapter: 'autumn',
    description: '높은 곳에서 자유낙하하는 스릴 어트랙션.',
    icon: '⬇️', isOperating: true,
  ),
  Attraction(
    id: 'flying_carpet',
    name: '플라잉카펫',
    category: '어트랙션',
    zone: '세계의 광장',
    lat: 37.4335, lng: 127.019,
    indoor: false, heightLimit: 0, thrillLevel: 2, waitMinutes: 10,
    rating: 4.0, hasEasterEgg: true, chapter: 'spring',
    description: '하늘을 나는 양탄자 콘셉트의 가족형 어트랙션.',
    icon: '🌟', isOperating: true,
  ),
  Attraction(
    id: 'rose_hill_cafe',
    name: '로즈힐 카페',
    category: '음식점',
    zone: '세계의 광장',
    lat: 37.4336, lng: 127.0188,
    indoor: true, heightLimit: 0, thrillLevel: 0, waitMinutes: 0,
    rating: 4.0, hasEasterEgg: false, chapter: null,
    description: '서울랜드 대표 카페. 다양한 음료와 디저트.',
    icon: '☕', isOperating: true,
  ),
  Attraction(
    id: 'cpk_restaurant',
    name: 'CPK 레스토랑',
    category: '음식점',
    zone: '세계의 광장',
    lat: 37.4333, lng: 127.0186,
    indoor: true, heightLimit: 0, thrillLevel: 0, waitMinutes: 0,
    rating: 3.8, hasEasterEgg: false, chapter: null,
    description: '캘리포니아 피자 키친. 피자·파스타 전문.',
    icon: '🍕', isOperating: true,
  ),
  // ─── 추가 어트랙션 (5) ──────────────────────────────────
  Attraction(
    id: 'sky_x',
    name: '스카이엑스',
    category: '어트랙션',
    zone: '미래의 나라',
    lat: 37.4355, lng: 127.0193,
    indoor: false, heightLimit: 130, thrillLevel: 5, waitMinutes: 30,
    rating: 4.6, hasEasterEgg: false, chapter: 'autumn',
    description: '70m 상공에서 자유낙하하는 익스트림 라이드.',
    icon: '🪂', isOperating: true,
  ),
  Attraction(
    id: 'time_machine_5d',
    name: '타임머신 5D 360',
    category: '어트랙션',
    zone: '미래의 나라',
    lat: 37.4346, lng: 127.0198,
    indoor: true, heightLimit: 0, thrillLevel: 2, waitMinutes: 12,
    rating: 4.0, hasEasterEgg: false, chapter: 'winter',
    description: '5D 입체 영상과 360도 회전 모션 체험.',
    icon: '🎬', isOperating: true,
  ),
  Attraction(
    id: 'ghost_cave',
    name: '귀신동굴',
    category: '어트랙션',
    zone: '캐릭터 타운',
    lat: 37.4340, lng: 127.0185,
    indoor: true, heightLimit: 0, thrillLevel: 3, waitMinutes: 10,
    rating: 3.9, hasEasterEgg: true, chapter: 'winter',
    description: '으스스한 분위기의 다크 라이드.',
    icon: '👻', isOperating: true,
  ),
  Attraction(
    id: 'magic_studio',
    name: '매직스튜디오',
    category: '어트랙션',
    zone: '캐릭터 타운',
    lat: 37.4332, lng: 127.0187,
    indoor: true, heightLimit: 0, thrillLevel: 1, waitMinutes: 8,
    rating: 4.1, hasEasterEgg: false, chapter: 'spring',
    description: '마법쇼와 실내 체험관.',
    icon: '🎩', isOperating: true,
  ),
  Attraction(
    id: 'lava_twister',
    name: '라바트위스터',
    category: '어트랙션',
    zone: '모험의 나라',
    lat: 37.4342, lng: 127.0207,
    indoor: false, heightLimit: 120, thrillLevel: 4, waitMinutes: 18,
    rating: 4.3, hasEasterEgg: true, chapter: 'summer',
    description: '회전하는 용암 컵에 올라타는 스릴 라이드.',
    icon: '🌋', isOperating: true,
  ),
  // ─── 추가 음식점 (4) ────────────────────────────────────
  Attraction(
    id: 'santa_restaurant',
    name: '산타레스토랑',
    category: '음식점',
    zone: '캐릭터 타운',
    lat: 37.4329, lng: 127.0193,
    indoor: true, heightLimit: 0, thrillLevel: 0, waitMinutes: 0,
    rating: 4.2, hasEasterEgg: false, chapter: null,
    description: '한식·양식 코스 메뉴.',
    icon: '🍽️', isOperating: true,
  ),
  Attraction(
    id: 'korean_kitchen',
    name: '한밥상',
    category: '음식점',
    zone: '세계의 광장',
    lat: 37.4334, lng: 127.0177,
    indoor: true, heightLimit: 0, thrillLevel: 0, waitMinutes: 0,
    rating: 4.0, hasEasterEgg: false, chapter: null,
    description: '한식 정식 전문.',
    icon: '🍚', isOperating: true,
  ),
  Attraction(
    id: 'rabat_pizza',
    name: '라바피자',
    category: '음식점',
    zone: '모험의 나라',
    lat: 37.4344, lng: 127.0211,
    indoor: true, heightLimit: 0, thrillLevel: 0, waitMinutes: 0,
    rating: 3.9, hasEasterEgg: false, chapter: null,
    description: '화덕 피자·파스타.',
    icon: '🍕', isOperating: true,
  ),
  Attraction(
    id: 'food_court',
    name: '월드푸드코트',
    category: '음식점',
    zone: '세계의 광장',
    lat: 37.4337, lng: 127.0197,
    indoor: true, heightLimit: 0, thrillLevel: 0, waitMinutes: 0,
    rating: 3.8, hasEasterEgg: false, chapter: null,
    description: '다국적 요리 한 자리에.',
    icon: '🍱', isOperating: true,
  ),
  // ─── 카페 (5) ───────────────────────────────────────────
  Attraction(
    id: 'cafe_bene',
    name: '카페베네 서울랜드점',
    category: '카페',
    zone: '캐릭터 타운',
    lat: 37.4326, lng: 127.0177,
    indoor: true, heightLimit: 0, thrillLevel: 0, waitMinutes: 0,
    rating: 4.0, hasEasterEgg: false, chapter: null,
    description: '호수 뷰 베이커리 카페.',
    icon: '☕', isOperating: true,
  ),
  Attraction(
    id: 'tom_n_toms',
    name: '탐앤탐스',
    category: '카페',
    zone: '세계의 광장',
    lat: 37.4343, lng: 127.0202,
    indoor: true, heightLimit: 0, thrillLevel: 0, waitMinutes: 0,
    rating: 3.9, hasEasterEgg: false, chapter: null,
    description: '프레즐과 커피.',
    icon: '🥨', isOperating: true,
  ),
  Attraction(
    id: 'luna_dessert',
    name: '루나 디저트',
    category: '카페',
    zone: '캐릭터 타운',
    lat: 37.4332, lng: 127.0192,
    indoor: true, heightLimit: 0, thrillLevel: 0, waitMinutes: 0,
    rating: 4.4, hasEasterEgg: false, chapter: null,
    description: '계절 한정 디저트 카페.',
    icon: '🍰', isOperating: true,
  ),
  Attraction(
    id: 'ice_cream_stand',
    name: '아이스크림 매대',
    category: '카페',
    zone: '모험의 나라',
    lat: 37.4340, lng: 127.0204,
    indoor: false, heightLimit: 0, thrillLevel: 0, waitMinutes: 0,
    rating: 3.7, hasEasterEgg: false, chapter: null,
    description: '소프트콘과 슬러시.',
    icon: '🍦', isOperating: true,
  ),
  Attraction(
    id: 'churros_truck',
    name: '츄러스 푸드트럭',
    category: '카페',
    zone: '미래의 나라',
    lat: 37.4350, lng: 127.0196,
    indoor: false, heightLimit: 0, thrillLevel: 0, waitMinutes: 0,
    rating: 4.1, hasEasterEgg: false, chapter: null,
    description: '갓 튀긴 츄러스와 핫초코.',
    icon: '🥯', isOperating: true,
  ),
  // ─── 포토스팟 (5) ───────────────────────────────────────
  Attraction(
    id: 'fountain_plaza',
    name: '중앙 분수 광장',
    category: '포토스팟',
    zone: '세계의 광장',
    lat: 37.4344, lng: 127.0195,
    indoor: false, heightLimit: 0, thrillLevel: 0, waitMinutes: 0,
    rating: 4.5, hasEasterEgg: true, chapter: 'summer',
    description: '시원한 물줄기 배경의 인생샷 명소.',
    icon: '⛲', isOperating: true,
  ),
  Attraction(
    id: 'flower_garden',
    name: '꽃 정원',
    category: '포토스팟',
    zone: '세계의 광장',
    lat: 37.4348, lng: 127.0190,
    indoor: false, heightLimit: 0, thrillLevel: 0, waitMinutes: 0,
    rating: 4.6, hasEasterEgg: false, chapter: 'spring',
    description: '계절꽃이 만개하는 정원.',
    icon: '🌷', isOperating: true,
  ),
  Attraction(
    id: 'character_statue',
    name: '루나 캐릭터 동상',
    category: '포토스팟',
    zone: '캐릭터 타운',
    lat: 37.4334, lng: 127.0184,
    indoor: false, heightLimit: 0, thrillLevel: 0, waitMinutes: 0,
    rating: 4.3, hasEasterEgg: false, chapter: null,
    description: '서울랜드 마스코트와 인증샷.',
    icon: '🗿', isOperating: true,
  ),
  Attraction(
    id: 'lake_bridge',
    name: '호숫가 다리',
    category: '포토스팟',
    zone: '세계의 광장',
    lat: 37.4337, lng: 127.0179,
    indoor: false, heightLimit: 0, thrillLevel: 0, waitMinutes: 0,
    rating: 4.4, hasEasterEgg: false, chapter: 'autumn',
    description: '단풍 시즌 인생샷 명소.',
    icon: '🌉', isOperating: true,
  ),
  Attraction(
    id: 'night_view_deck',
    name: '미래의 나라 전망대',
    category: '포토스팟',
    zone: '미래의 나라',
    lat: 37.4357, lng: 127.0214,
    indoor: false, heightLimit: 0, thrillLevel: 0, waitMinutes: 0,
    rating: 4.7, hasEasterEgg: true, chapter: 'winter',
    description: '야경과 불빛쇼 명소.',
    icon: '🌃', isOperating: true,
  ),
];

/// 챕터별 대상 어트랙션 ID. 챕터 내 이스터에그 어트랙션 전부 발견 → 챕터 완료.
const Map<String, List<String>> kChapterTargets = {
  'spring': ['ferris_wheel', 'carousel', 'bumper_car', 'flying_carpet', 'viking'],
  'summer': ['flume_ride', 'gyro_drop', 'viking', 'bumper_car', 'flying_carpet'],
  'autumn': ['galaxy_888', 'blackhole_2000', 'gyro_swing', 'gyro_drop', 'viking'],
  'winter': ['carousel', 'ferris_wheel', 'bumper_car', 'blackhole_2000', 'flying_carpet'],
};
