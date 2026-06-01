import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import '../models/attraction.dart';
import '../models/route_response.dart';
import 'onboarding_service.dart';

/// 동선 추천 서비스 — 백엔드 `POST /api/route` 호출, 미설정·실패 시 mock fallback.
///
/// baseUrl 주입: 빌드 시 `--dart-define=API_BASE_URL=http://localhost:5000` 으로
/// 환경별 분리. 빈 문자열이면 mock 모드.
class RouteService {
  RouteService._();
  static final RouteService instance = RouteService._();

  /// 환경별 백엔드 baseUrl. dart-define 으로 주입.
  ///   flutter run --dart-define=API_BASE_URL=http://localhost:5000
  static const String _baseUrl = String.fromEnvironment('API_BASE_URL');

  /// baseUrl 비어있으면 mock 모드. const String.isEmpty 는 const eval 불가하여
  /// length 비교로 우회.
  static const bool _useMock = _baseUrl.length == 0;

  /// 단순 메모리 캐시 — 같은 cache_key 면 재사용.
  RouteResponse? _cached;
  String? _cachedKey;

  /// HTTP 호출 timeout. 백엔드 predict 가 첫 호출 시 모델 로드 ~2s 들 수 있어 넉넉히.
  static const Duration _timeout = Duration(seconds: 8);

  Future<RouteResponse> fetchRoute(RouteRequest req) async {
    if (_useMock) return _generateMock(req);
    try {
      final resp = await _fetchFromBackend(req).timeout(_timeout);
      _cached = resp;
      _cachedKey = resp.cacheKey;
      return resp;
    } catch (e, st) {
      // 네트워크·타임아웃·5xx — mock 으로 graceful fallback.
      developer.log(
        'route backend failed, falling back to mock',
        error: e,
        stackTrace: st,
        name: 'RouteService',
      );
      return _generateMock(req);
    }
  }

  RouteResponse? get cached => _cached;

  // ── HTTP ────────────────────────────────────────────────
  Future<RouteResponse> _fetchFromBackend(RouteRequest req) async {
    final uri = Uri.parse('$_baseUrl/api/route');
    final resp = await http.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(req.toJson()),
    );
    if (resp.statusCode >= 400) {
      throw HttpException('route api ${resp.statusCode}: ${resp.body}');
    }
    final body = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, Object?>;
    return RouteResponse.fromJson(body);
  }

  // ── 목업 (백엔드 없을 때 fallback) ──────────────────────
  Future<RouteResponse> _generateMock(RouteRequest req) async {
    await Future.delayed(const Duration(milliseconds: 350));

    Iterable<Attraction> pool = kAttractions
        .where((a) => a.isOperating)
        .where((a) => !req.completedIds.contains(a.id));

    if (req.onboarding.hasInfant) {
      pool = pool.where((a) => a.heightLimit == 0);
    }

    final scored = pool.map((a) {
      double score = 0;
      score += (60 - a.waitMinutes).clamp(-20, 60).toDouble();
      final dist = _hav(req.lat, req.lng, a.lat, a.lng);
      score += ((1200 - dist) / 80).clamp(-10, 15);
      if (a.hasEasterEgg && !req.discoveredEggs.contains(a.id)) score += 25;
      if (a.category == '어트랙션') {
        if (req.onboarding.favoriteType == FavoriteType.thrill && a.thrillLevel >= 4) score += 25;
        if (req.onboarding.favoriteType == FavoriteType.family && a.thrillLevel <= 2) score += 25;
      }
      if (req.onboarding.hasChild && a.category == '어트랙션' && a.thrillLevel <= 2) {
        score += 15;
      }
      score += a.rating * (a.category == '어트랙션' ? 1.5 : 4);
      return (a: a, score: score);
    }).toList()
      ..sort((x, y) => y.score.compareTo(x.score));

    final N = _routeLength(req.onboarding.purpose);
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

    final ordered = _nearestNeighbor(picked, req.lat, req.lng);

    final stops = <RouteStop>[];
    double prevLat = req.lat, prevLng = req.lng;
    int totalMin = 0;
    for (var i = 0; i < ordered.length; i++) {
      final a = ordered[i];
      final dist = _hav(prevLat, prevLng, a.lat, a.lng);
      final walkMin = (dist / 66.67).ceil();
      final eta = walkMin + a.waitMinutes;
      stops.add(RouteStop(id: a.id, order: i + 1, etaMinFromPrev: eta));
      totalMin += eta;
      prevLat = a.lat;
      prevLng = a.lng;
    }

    final rationale = _mockRationale(req, ordered);
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

class HttpException implements Exception {
  final String message;
  const HttpException(this.message);
  @override
  String toString() => 'HttpException: $message';
}
