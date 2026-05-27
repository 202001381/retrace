import 'dart:math' as math;

import 'attraction.dart';
import 'luna_recommendation.dart';

/// 백엔드 연동 전 데모용 — 손수 큐레이션한 ~4시간 코스 시나리오.
/// 시나리오 선택 시 RouteService 호출을 우회하고 이 정적 데이터를 사용.
/// 백엔드 붙으면 이 enum 만 제거하면 됨.
enum DemoScenario {
  family(
    emoji: '👨‍👩‍👧',
    title: '가족 4시간',
    subtitle: '어린이 동반, 저강도 위주',
    rationale: '아이가 즐길 수 있는 저스릴 어트랙션과 휴식·점심을 균형있게 배치했어요',
    stopIds: [
      'main_gate_arch',
      'carousel',
      'time_machine_5d',         // 가족형 indoor 어트랙션 (실재)
      'family_coaster',          // TODO: 공식 목록 대조 필요
      'mini_airplane',           // 깜부비행기 — 실재 확인
      'korean_kitchen',          // 점심
      'mini_viking',
      'magic_studio',            // TODO: 공식 목록 대조 필요
      'shooting_adventure',      // 사격장 — 실재 확인 (모험의 나라)
      'flower_garden',
      'spinning_cup',
      'cafe_bene',               // 휴식
      'center_clock_tower',
    ],
  ),
  date(
    emoji: '💑',
    title: '데이트 4시간',
    subtitle: '포토스팟 + 식사 + 야경',
    rationale: '인생샷·식사·야경 흐름으로 데이트 동선을 짰어요',
    stopIds: [
      'seoulland_sign',
      'carousel',
      'flume_ride',
      'lake_bridge',             // TODO: 공식 목록 대조 필요
      'santa_restaurant',        // 점심 — 365 크리스마스 타운 (실재)
      'rose_garden',
      'world_flag_plaza',        // 세계의 광장 (실재)
      'tunnel_of_lights',        // TODO: 공식 목록 대조 필요 (계절 가능)
      'cafe_bene',               // 디저트 — 실재 카페
      'fantasy_castle',          // TODO: 공식 목록 대조 필요
      'night_view_deck',         // TODO: 공식 목록 대조 필요
      'fountain_plaza',
    ],
  ),
  thrill(
    emoji: '🎢',
    title: '스릴 4시간',
    subtitle: '롤러코스터 + 액티비티 집중',
    rationale: '서울랜드 대표 스릴 어트랙션 위주로 짜고 중간에 식사·카페로 호흡 조절',
    stopIds: [
      'main_gate_arch',
      'blackhole_2000',
      'galaxy_888',
      'viking',
      'sky_x',
      'lava_twister',
      'galbi_house',             // 점심
      'shot_drop',
      'x_flyer',
      'gyro_swing',              // 알포스윙 — 실재 확인 (캐릭터타운)
      'tom_n_toms',              // TODO: 공식 목록 대조 필요
      'night_view_deck',         // TODO: 공식 목록 대조 필요
    ],
  );

  final String emoji;
  final String title;
  final String subtitle;
  final String rationale;
  final List<String> stopIds;

  const DemoScenario({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.rationale,
    required this.stopIds,
  });

  /// id → Attraction 해석. 누락된 id 는 건너뜀.
  List<Attraction> resolveStops() {
    final byId = {for (final a in kAttractions) a.id: a};
    return stopIds.map((id) => byId[id]).whereType<Attraction>().toList();
  }

  /// LunaRecommendation 으로 패키징. 총 시간 = origin→첫스팟→...→마지막 누적.
  LunaRecommendation toRecommendation({
    required double originLat,
    required double originLng,
    DateTime? lockedAt,
  }) {
    final spots = resolveStops();
    final totalMin = _computeTotalMin(originLat, originLng, spots);
    return LunaRecommendation(
      spots: spots,
      totalMin: totalMin,
      rationale: rationale,
      lockedAt: lockedAt ?? DateTime.now(),
    );
  }
}

// 평균 도보 속도 80m/min (MyLunaScreen 과 동일 기준).
// TODO: RouteService(66.67m/min)와 거리 계산식 통일 검토 필요.
const double _kWalkSpeedMpm = 80;

int _computeTotalMin(double oLat, double oLng, List<Attraction> spots) {
  double total = 0;
  double prevLat = oLat;
  double prevLng = oLng;
  for (final s in spots) {
    total += _haversine(prevLat, prevLng, s.lat, s.lng) / _kWalkSpeedMpm;
    total += _activityMinutes(s);
    prevLat = s.lat;
    prevLng = s.lng;
  }
  return total.ceil();
}

int _activityMinutes(Attraction a) {
  switch (a.category) {
    case '음식점':
      return 35;       // 식사
    case '카페':
      return 20;       // 휴식
    case '포토스팟':
      return 8;        // 사진
    default:
      // 어트랙션 = 대기 + 탑승. waitMinutes < 12 면 최소 12분 보장.
      final w = a.waitMinutes < 12 ? 12 : a.waitMinutes;
      return w + 5;
  }
}

double _haversine(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371000.0;
  final p1 = lat1 * math.pi / 180;
  final p2 = lat2 * math.pi / 180;
  final dp = (lat2 - lat1) * math.pi / 180;
  final dl = (lng2 - lng1) * math.pi / 180;
  final h = math.sin(dp / 2) * math.sin(dp / 2) +
      math.cos(p1) * math.cos(p2) * math.sin(dl / 2) * math.sin(dl / 2);
  return 2 * r * math.atan2(math.sqrt(h), math.sqrt(1 - h));
}
