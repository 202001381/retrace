import 'package:latlong2/latlong.dart';

/// 추천 화면 전용 어트랙션 모델.
/// SeoulLandSpots 의 Spot 과는 별개로, 명세된 필드만 압축한 구조.
class Attraction {
  final String id;
  final String name;
  final String zone;
  final double lat;
  final double lng;
  final bool indoor;
  /// 키 제한(cm). 0 = 제한 없음.
  final int heightLimit;
  /// 스릴 강도 1~5.
  final int thrillLevel;
  /// 예상 대기시간(분).
  final int estimatedWaitMin;
  final String emoji;

  const Attraction({
    required this.id,
    required this.name,
    required this.zone,
    required this.lat,
    required this.lng,
    required this.indoor,
    required this.heightLimit,
    required this.thrillLevel,
    required this.estimatedWaitMin,
    required this.emoji,
  });

  LatLng get position => LatLng(lat, lng);

  String get crowdLabel {
    if (estimatedWaitMin <= 5) return '여유';
    if (estimatedWaitMin <= 20) return '보통';
    return '혼잡';
  }
}

/// 서울랜드 실측 어트랙션 15종. 추천/지도 마커 공용.
const List<Attraction> kAttractions = [
  Attraction(
    id: 'a01', name: '은하열차 888', zone: '월드 광장',
    lat: 37.4291, lng: 126.9782,
    indoor: false, heightLimit: 120, thrillLevel: 5, estimatedWaitMin: 25,
    emoji: '🎢',
  ),
  Attraction(
    id: 'a02', name: '블랙홀 2000', zone: '미래의 나라',
    lat: 37.4285, lng: 126.9809,
    indoor: true, heightLimit: 120, thrillLevel: 5, estimatedWaitMin: 30,
    emoji: '🌀',
  ),
  Attraction(
    id: 'a03', name: '후룸라이드', zone: '모험의 나라',
    lat: 37.4273, lng: 126.9792,
    indoor: false, heightLimit: 110, thrillLevel: 3, estimatedWaitMin: 15,
    emoji: '🌊',
  ),
  Attraction(
    id: 'a04', name: '자이로스윙', zone: '모험의 나라',
    lat: 37.4269, lng: 126.9804,
    indoor: false, heightLimit: 130, thrillLevel: 5, estimatedWaitMin: 20,
    emoji: '🎡',
  ),
  Attraction(
    id: 'a05', name: '킹바이킹', zone: '환상의 나라',
    lat: 37.4276, lng: 126.9816,
    indoor: false, heightLimit: 130, thrillLevel: 4, estimatedWaitMin: 5,
    emoji: '⛵',
  ),
  Attraction(
    id: 'a06', name: '급류타기', zone: '모험의 나라',
    lat: 37.4281, lng: 126.9789,
    indoor: false, heightLimit: 110, thrillLevel: 4, estimatedWaitMin: 18,
    emoji: '🚤',
  ),
  Attraction(
    id: 'a07', name: '대관람차', zone: '월드 광장',
    lat: 37.4295, lng: 126.9795,
    indoor: false, heightLimit: 0, thrillLevel: 1, estimatedWaitMin: 5,
    emoji: '🎠',
  ),
  Attraction(
    id: 'a08', name: '회전목마', zone: '환상의 나라',
    lat: 37.4279, lng: 126.9800,
    indoor: false, heightLimit: 0, thrillLevel: 1, estimatedWaitMin: 3,
    emoji: '🐴',
  ),
  Attraction(
    id: 'a09', name: '범퍼카', zone: '환상의 나라',
    lat: 37.4271, lng: 126.9798,
    indoor: false, heightLimit: 100, thrillLevel: 2, estimatedWaitMin: 10,
    emoji: '🚗',
  ),
  Attraction(
    id: 'a10', name: '해적소굴', zone: '모험의 나라',
    lat: 37.4267, lng: 126.9796,
    indoor: true, heightLimit: 0, thrillLevel: 2, estimatedWaitMin: 8,
    emoji: '🏴‍☠️',
  ),
  Attraction(
    id: 'a11', name: '타임머신 5D 360', zone: '미래의 나라',
    lat: 37.4288, lng: 126.9813,
    indoor: true, heightLimit: 0, thrillLevel: 2, estimatedWaitMin: 12,
    emoji: '🎬',
  ),
  Attraction(
    id: 'a12', name: '스카이X', zone: '미래의 나라',
    lat: 37.4293, lng: 126.9820,
    indoor: false, heightLimit: 140, thrillLevel: 5, estimatedWaitMin: 22,
    emoji: '🪂',
  ),
  Attraction(
    id: 'a13', name: 'VR게이트', zone: '미래의 나라',
    lat: 37.4283, lng: 126.9822,
    indoor: true, heightLimit: 120, thrillLevel: 3, estimatedWaitMin: 14,
    emoji: '🥽',
  ),
  Attraction(
    id: 'a14', name: '빅회전목마', zone: '환상의 나라',
    lat: 37.4275, lng: 126.9808,
    indoor: false, heightLimit: 0, thrillLevel: 1, estimatedWaitMin: 4,
    emoji: '🎪',
  ),
  Attraction(
    id: 'a15', name: '코끼리 열차', zone: '환상의 나라',
    lat: 37.4282, lng: 126.9779,
    indoor: false, heightLimit: 0, thrillLevel: 1, estimatedWaitMin: 6,
    emoji: '🐘',
  ),
];
