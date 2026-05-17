import 'package:latlong2/latlong.dart';

/// 앱 전체(MAP, 추천, Archive) 공통 단일 데이터 소스.
class Attraction {
  final String id;
  final String name;
  final String category;     // '어트랙션' | '음식점'
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
  });

  LatLng get position => LatLng(lat, lng);

  String get crowdLabel {
    if (waitMinutes <= 5) return '여유';
    if (waitMinutes <= 20) return '보통';
    return '혼잡';
  }
}

const List<Attraction> kAttractions = [
  Attraction(
    id: 'galaxy_888',
    name: '은하열차 888',
    category: '어트랙션',
    zone: '미래의 나라',
    lat: 37.4285, lng: 126.9812,
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
    lat: 37.4290, lng: 126.9820,
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
    lat: 37.4275, lng: 126.9805,
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
    lat: 37.4280, lng: 126.9815,
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
    lat: 37.4270, lng: 126.9800,
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
    lat: 37.4268, lng: 126.9795,
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
    lat: 37.4272, lng: 126.9790,
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
    lat: 37.4282, lng: 126.9808,
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
    lat: 37.4288, lng: 126.9818,
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
    lat: 37.4265, lng: 126.9802,
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
    lat: 37.4271, lng: 126.9797,
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
    lat: 37.4269, lng: 126.9793,
    indoor: true, heightLimit: 0, thrillLevel: 0, waitMinutes: 0,
    rating: 3.8, hasEasterEgg: false, chapter: null,
    description: '캘리포니아 피자 키친. 피자·파스타 전문.',
    icon: '🍕', isOperating: true,
  ),
];

/// 챕터별 대상 어트랙션 ID. 챕터 내 이스터에그 어트랙션 전부 발견 → 챕터 완료.
const Map<String, List<String>> kChapterTargets = {
  'spring': ['ferris_wheel', 'carousel', 'bumper_car', 'flying_carpet', 'viking'],
  'summer': ['flume_ride', 'gyro_drop', 'viking', 'bumper_car', 'flying_carpet'],
  'autumn': ['galaxy_888', 'blackhole_2000', 'gyro_swing', 'gyro_drop', 'viking'],
  'winter': ['carousel', 'ferris_wheel', 'bumper_car', 'blackhole_2000', 'flying_carpet'],
};
