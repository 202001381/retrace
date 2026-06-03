/// OSRM 도보 경로 — OpenStreetMap 데이터 기반 실제 walkable path.
///
/// 공개 인스턴스 `router.project-osrm.org` 디폴트. 자체 호스팅 시
/// `--dart-define=OSRM_BASE_URL=https://your-osrm.example.com` 으로 override.
///
/// 실패/타임아웃 시 PathGraph (호수 우회 그래프) → 그것도 실패하면 직선 fallback.
/// 60m 미만 짧은 거리는 API 호출 스킵하고 직선.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'path_graph.dart';

class OsrmRouter {
  OsrmRouter._();

  static const String _baseUrl = String.fromEnvironment(
    'OSRM_BASE_URL',
    defaultValue: 'https://router.project-osrm.org',
  );
  static const Duration _timeout = Duration(seconds: 5);
  static const double _skipThresholdMeters = 60;

  /// In-memory cache — 같은 (origin, dest) 페어 재호출 시 즉시 반환.
  /// 키: lat/lng 4자리 반올림 (≈11m 그리드).
  static final Map<String, RouteResult> _cache = {};

  static String _cacheKey(LatLng a, LatLng b) {
    String r(double v) => v.toStringAsFixed(4);
    return '${r(a.latitude)},${r(a.longitude)}->${r(b.latitude)},${r(b.longitude)}';
  }

  /// `origin → dest` 도보 경로. 실패 시 그래프 → 직선 fallback.
  static Future<RouteResult> route(LatLng origin, LatLng dest) async {
    final straight = _haversine(origin, dest);
    if (straight < _skipThresholdMeters) {
      return RouteResult(
        points: [origin, dest],
        meters: straight,
        routed: false,
      );
    }
    final key = _cacheKey(origin, dest);
    final cached = _cache[key];
    if (cached != null) return cached;

    try {
      final uri = Uri.parse(
        '$_baseUrl/route/v1/foot/'
        '${origin.longitude},${origin.latitude};'
        '${dest.longitude},${dest.latitude}'
        '?overview=full&geometries=geojson',
      );
      final resp = await http.get(uri).timeout(_timeout);
      if (resp.statusCode != 200) {
        developer.log('osrm http ${resp.statusCode}', name: 'OsrmRouter');
        return _fallback(origin, dest);
      }
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      final routes = body['routes'] as List?;
      if (routes == null || routes.isEmpty) return _fallback(origin, dest);
      final route = routes.first as Map<String, dynamic>;
      final geom = route['geometry'] as Map<String, dynamic>?;
      final coords = geom?['coordinates'] as List?;
      if (coords == null || coords.isEmpty) return _fallback(origin, dest);

      final points = <LatLng>[];
      for (final c in coords) {
        if (c is! List || c.length < 2) continue;
        final lng = (c[0] as num).toDouble();
        final lat = (c[1] as num).toDouble();
        points.add(LatLng(lat, lng));
      }
      if (points.length < 2) return _fallback(origin, dest);

      final meters = (route['distance'] as num?)?.toDouble() ?? straight;
      final result = RouteResult(points: points, meters: meters, routed: true);
      _cache[key] = result;
      return result;
    } catch (e, st) {
      developer.log('osrm failed', error: e, stackTrace: st, name: 'OsrmRouter');
      return _fallback(origin, dest);
    }
  }

  /// 여러 stop 을 순서대로 잇는 도보 경로. 각 leg 별로 OSRM 호출 (병렬).
  /// stop 수 ≤ 1 이면 빈/단일 결과.
  static Future<RouteResult> routeMulti(List<LatLng> stops) async {
    if (stops.length < 2) {
      return RouteResult(
        points: List<LatLng>.from(stops),
        meters: 0,
        routed: false,
      );
    }
    final legs = <Future<RouteResult>>[];
    for (var i = 0; i < stops.length - 1; i++) {
      legs.add(route(stops[i], stops[i + 1]));
    }
    final results = await Future.wait(legs);
    final merged = <LatLng>[stops.first];
    var meters = 0.0;
    var anyRouted = false;
    for (final r in results) {
      merged.addAll(r.points.skip(1));
      meters += r.meters;
      anyRouted = anyRouted || r.routed;
    }
    return RouteResult(points: merged, meters: meters, routed: anyRouted);
  }

  /// OSRM 실패 시 PathGraph 의 호수 우회 그래프 → 그것도 fallback 안 되면 직선.
  static RouteResult _fallback(LatLng origin, LatLng dest) {
    return PathGraph.route(origin, dest);
  }

  static double _haversine(LatLng a, LatLng b) {
    const r = 6371000.0;
    final p1 = a.latitude * math.pi / 180;
    final p2 = b.latitude * math.pi / 180;
    final dp = (b.latitude - a.latitude) * math.pi / 180;
    final dl = (b.longitude - a.longitude) * math.pi / 180;
    final h = math.sin(dp / 2) * math.sin(dp / 2) +
        math.cos(p1) * math.cos(p2) * math.sin(dl / 2) * math.sin(dl / 2);
    return 2 * r * math.atan2(math.sqrt(h), math.sqrt(1 - h));
  }
}
