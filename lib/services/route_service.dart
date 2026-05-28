import 'dart:async';
import 'dart:math' as math;

import '../models/attraction.dart';
import '../models/route_response.dart';
import 'onboarding_service.dart';

/// 동선 추천 서비스. 현재는 목업 — 백엔드 URL 확정 시 `_useMock=false` + HTTP 구현 추가.
class RouteService {
  RouteService._();
  static final RouteService instance = RouteService._();

  // 백엔드 붙으면 false 로 전환.
  static const bool _useMock = true;

  // 단순 메모리 캐시 — 같은 cache_key 면 재사용.
  RouteResponse? _cached;
  String? _cachedKey;

  Future<RouteResponse> fetchRoute(RouteRequest req) async {
    if (_useMock) return _generateMock(req);
    // TODO: HTTP — http.post('$baseUrl/api/route', body: jsonEncode(req.toJson()))
    throw UnimplementedError('백엔드 URL 미설정');
  }

  RouteResponse? get cached => _cached;

  // ── 목업 ────────────────────────────────────────────────
  Future<RouteResponse> _generateMock(RouteRequest req) async {
    await Future.delayed(const Duration(milliseconds: 350));

    // 1) 운영중 + 미완료 어트랙션만
    Iterable<Attraction> pool = kAttractions
        .where((a) => a.isOperating)
        .where((a) => !req.completedIds.contains(a.id));

    // 2) 유아 동반 → 키 제한 어트랙션 제외
    if (req.onboarding.hasInfant) {
      pool = pool.where((a) => a.heightLimit == 0);
    }

    // 3) 스코어링
    final scored = pool.map((a) {
      double score = 0;

      // 혼잡도 (대기 짧을수록 높음, 음식점·카페·포토는 0이라 영향 적음)
      score += (60 - a.waitMinutes).clamp(-20, 60).toDouble();

      // 거리 (현재 위치에서 가까울수록 +)
      final dist = _hav(req.lat, req.lng, a.lat, a.lng);
      score += ((1200 - dist) / 80).clamp(-10, 15);

      // 미발견 이스터에그 보너스
      if (a.hasEasterEgg && !req.discoveredEggs.contains(a.id)) score += 25;

      // 선호 어트랙션 가중
      if (a.category == '어트랙션') {
        if (req.onboarding.favoriteType == FavoriteType.thrill && a.thrillLevel >= 4) score += 25;
        if (req.onboarding.favoriteType == FavoriteType.family && a.thrillLevel <= 2) score += 25;
      }

      // 어린이 동반 시 저스릴 어트랙션 우대
      if (req.onboarding.hasChild && a.category == '어트랙션' && a.thrillLevel <= 2) {
        score += 15;
      }

      // 평점 (음식·카페·포토 분류에 더 큰 영향)
      score += a.rating * (a.category == '어트랙션' ? 1.5 : 4);

      return (a: a, score: score);
    }).toList()
      ..sort((x, y) => y.score.compareTo(x.score));

    // 4) 동선 길이 — purpose 따라
    final N = _routeLength(req.onboarding.purpose);

    // 5) 카테고리 다양성 — 어트랙션 60%, 나머지는 카페/포토/음식점 각 1.
    // N=3 (picnic) 같이 짧은 동선에서 clamp(min, max) 의 max(N-2)가 min(2)보다
    // 작아져 ArgumentError 가 발생하던 버그 → 상한을 max(min, N-1)로 보호.
    final upper = (N - 1).clamp(2, N);
    final attractionCount = (N * 0.6).ceil().clamp(2, upper);
    final picked = <Attraction>[];
    picked.addAll(scored.where((s) => s.a.category == '어트랙션').take(attractionCount).map((s) => s.a));
    final addedCafe = scored.where((s) => s.a.category == '카페').take(1).toList();
    final addedPhoto = scored.where((s) => s.a.category == '포토스팟').take(1).toList();
    final addedFood = scored.where((s) => s.a.category == '음식점').take(1).toList();
    for (final s in [...addedCafe, ...addedPhoto, ...addedFood]) {
      if (picked.length >= N) break;
      picked.add(s.a);
    }

    // 6) Nearest-neighbor 순서
    final ordered = _nearestNeighbor(picked, req.lat, req.lng);

    // 7) ETA / total
    final stops = <RouteStop>[];
    double prevLat = req.lat, prevLng = req.lng;
    int totalMin = 0;
    for (var i = 0; i < ordered.length; i++) {
      final a = ordered[i];
      final dist = _hav(prevLat, prevLng, a.lat, a.lng);
      final walkMin = (dist / 66.67).ceil(); // 4 km/h
      final eta = walkMin + a.waitMinutes;
      stops.add(RouteStop(id: a.id, order: i + 1, etaMinFromPrev: eta));
      totalMin += eta;
      prevLat = a.lat;
      prevLng = a.lng;
    }

    // 8) Mock rationale
    final rationale = _mockRationale(req, ordered);

    // 9) cache key
    final cacheKey = '${req.lat.toStringAsFixed(3)}_${req.lng.toStringAsFixed(3)}_'
        '${req.completedIds.length}_${req.onboarding.purpose ?? ''}_${req.requestReason}';

    final resp = RouteResponse(
      route: stops,
      totalMin: totalMin,
      rationale: rationale,
      computedAt: DateTime.now(),
      cacheKey: cacheKey,
    );
    _cached = resp;
    _cachedKey = cacheKey;
    return resp;
  }

  int _routeLength(String? purpose) {
    switch (purpose) {
      case VisitPurpose.date:
        return 4;
      case VisitPurpose.picnic:
        return 3;
      case VisitPurpose.kidsOuting:
        return 5;
      case VisitPurpose.rides:
        return 7;
      default:
        return 5;
    }
  }

  String _mockRationale(RouteRequest req, List<Attraction> route) {
    if (req.onboarding.hasInfant) return '유아 동반 — 키 제한 어트랙션 빼고 짰어요 🍼';
    final undiscoveredEggs =
        route.where((a) => a.hasEasterEgg && !req.discoveredEggs.contains(a.id)).length;
    if (undiscoveredEggs >= 2) return '못 찾은 이스터에그 $undiscoveredEggs개 포함했어요 🥚';
    if (req.onboarding.purpose == VisitPurpose.date) return '둘만의 데이트 코스로 짰어요 💑';
    if (req.onboarding.favoriteType == FavoriteType.thrill) return '스릴 위주 — 짜릿하게 즐겨보세요 🎢';
    if (req.onboarding.favoriteType == FavoriteType.family) return '가족이 함께 즐길 어트랙션 위주에요 🎠';
    if (req.requestReason == 'gps_moved') return '이동하신 위치 기준으로 다시 짰어요 📍';
    if (req.requestReason == 'attraction_completed') return '방금 다녀온 코스 빼고 갱신했어요 ✨';
    return '오늘의 추천 동선이에요 ✨';
  }

  List<Attraction> _nearestNeighbor(List<Attraction> pool, double startLat, double startLng) {
    if (pool.isEmpty) return const [];
    final remaining = [...pool];
    final result = <Attraction>[];
    double curLat = startLat, curLng = startLng;
    while (remaining.isNotEmpty) {
      var bestIdx = 0;
      var bestDist = double.infinity;
      for (var i = 0; i < remaining.length; i++) {
        final d = _hav(curLat, curLng, remaining[i].lat, remaining[i].lng);
        if (d < bestDist) {
          bestDist = d;
          bestIdx = i;
        }
      }
      final pick = remaining.removeAt(bestIdx);
      result.add(pick);
      curLat = pick.lat;
      curLng = pick.lng;
    }
    return result;
  }

  static double _hav(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000.0;
    final p1 = lat1 * math.pi / 180;
    final p2 = lat2 * math.pi / 180;
    final dp = (lat2 - lat1) * math.pi / 180;
    final dl = (lng2 - lng1) * math.pi / 180;
    final h = math.sin(dp / 2) * math.sin(dp / 2) +
        math.cos(p1) * math.cos(p2) * math.sin(dl / 2) * math.sin(dl / 2);
    return 2 * r * math.atan2(math.sqrt(h), math.sqrt(1 - h));
  }
}
