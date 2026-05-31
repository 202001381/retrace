import 'package:latlong2/latlong.dart';

import '../models/spot_model.dart';

enum CompanionGroup {
  toddler,    // 7세 미만 동반
  elementary, // 초등 (7~13세) 동반
  adultOnly,  // 성인/청소년만
}

class AttractionScore {
  final Spot spot;
  final double score;
  final double distanceMeters;
  final int waitMinutes;
  const AttractionScore({
    required this.spot,
    required this.score,
    required this.distanceMeters,
    required this.waitMinutes,
  });
}

class RecommendationService {
  static const _kElementaryHeightCm = 110;
  static const _distance = Distance();

  /// 정수 분 단위 wait 추출. '5분', '15분', '대기없음', null → 0/N.
  static int _parseWait(String? raw) {
    if (raw == null) return 0;
    final m = RegExp(r'(\d+)').firstMatch(raw);
    if (m == null) return 0;
    return int.parse(m.group(1)!);
  }

  static double _crowdScore(int waitMin) {
    // wait 0분=100, 5분=90, 30분=40 ... 음수 clamp
    final s = 100.0 - waitMin * 2.0;
    return s.clamp(0.0, 100.0);
  }

  static double _distanceScore(double meters) {
    // 0m=100, 500m=0
    final s = 100.0 - meters / 5.0;
    return s.clamp(0.0, 100.0);
  }

  static bool _passesHardFilter(Spot s, CompanionGroup g) {
    final h = s.heightLimitCm;
    switch (g) {
      case CompanionGroup.toddler:
        return h == null;
      case CompanionGroup.elementary:
        return h == null || h <= _kElementaryHeightCm;
      case CompanionGroup.adultOnly:
        return true;
    }
  }

  /// Top-3 어트랙션 추천. food/photo 제외, 운영중·필터 통과만.
  static List<AttractionScore> recommendTop3({
    required CompanionGroup companion,
    required LatLng currentLocation,
    Map<String, int>? waitMinutes,
    DateTime? now,
    List<Spot>? source,
  }) {
    final ts = now ?? DateTime.now();
    final pool = (source ?? SeoulLandSpots.all)
        .where((s) => s.category == SpotCategory.attraction)
        .where((s) => s.isOperating)
        .where((s) => _passesHardFilter(s, companion))
        .toList();

    final scored = <AttractionScore>[];
    for (final s in pool) {
      final wait = waitMinutes?[s.id] ?? _parseWait(s.waitTime);
      final dist = _distance.as(LengthUnit.Meter, currentLocation, s.position);

      double score = _crowdScore(wait) + _distanceScore(dist);

      switch (companion) {
        case CompanionGroup.toddler:
          if (s.indoor) score += 30.0;
          score += _distanceScore(dist) * 0.20; // 거리 가중치 +20점 (max)
          break;
        case CompanionGroup.elementary:
          score += _distanceScore(dist) * 0.10; // +10점 (max)
          break;
        case CompanionGroup.adultOnly:
          if (s.thrillLevel >= 4) score += 20.0;
          // 오후 시간대(13시~) 혼잡 회피
          if (ts.hour >= 13 && wait >= 15) score -= 10.0;
          break;
      }

      scored.add(AttractionScore(
        spot: s,
        score: score,
        distanceMeters: dist,
        waitMinutes: wait,
      ));
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(3).toList();
  }
}
