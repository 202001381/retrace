/// 서울랜드 도보 경로 그래프 (Dijkstra).
///
/// 핸드-오서링한 22개 웨이포인트 + 호수 통과 차단 룰로 직선이 물 위를
/// 가로지르지 않도록 라우팅합니다. 외부 지도 API 없이 동작합니다.
///
/// 사용:
///   final r = PathGraph.route(origin, destination);
///   PolylineLayer(polylines: [Polyline(points: r.points, ...)])
///   '도보 ${r.walkMinutes}분'
///
/// 한계: 노드 밀도가 낮아 50m 미만 짧은 이동은 직선과 유사하게 보입니다.
/// 호수를 가로지를 만큼 양 끝이 멀 때 그래프가 정확히 우회시킵니다.
library;

import 'dart:collection';
import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../core/walk_speed.dart';

class RouteResult {
  final List<LatLng> points;
  final double meters;
  final bool routed; // false = 그래프 우회 실패해 직선 fallback
  const RouteResult({
    required this.points,
    required this.meters,
    required this.routed,
  });

  int get walkMinutes => (meters / kWalkSpeedMpm).ceil();
}

class PathGraph {
  // ── 웨이포인트 — 서울랜드 도보 가능 영역 hand-tuned ───────────
  // 좌표는 어트랙션 데이터(127.017~127.021 / 37.432~37.436)와 동일한
  // 좌표계. 외곽 루프 + 호수 둘레 + 광장 허브 구성.
  static const List<LatLng> _nodes = [
    LatLng(37.4330, 127.0177), // 0  남서 입구 (정문 근방)
    LatLng(37.4330, 127.0188), // 1  남
    LatLng(37.4329, 127.0200), // 2  남남동
    LatLng(37.4330, 127.0210), // 3  남동 corner
    LatLng(37.4337, 127.0213), // 4  동남
    LatLng(37.4344, 127.0215), // 5  동
    LatLng(37.4350, 127.0214), // 6  동북
    LatLng(37.4354, 127.0210), // 7  북동
    LatLng(37.4357, 127.0203), // 8  북북동
    LatLng(37.4357, 127.0194), // 9  북
    LatLng(37.4356, 127.0185), // 10 북북서
    LatLng(37.4354, 127.0179), // 11 북서
    LatLng(37.4348, 127.0177), // 12 서북
    LatLng(37.4342, 127.0178), // 13 서
    LatLng(37.4337, 127.0180), // 14 서남
    LatLng(37.4338, 127.0190), // 15 호수 남서
    LatLng(37.4338, 127.0200), // 16 호수 남동
    LatLng(37.4347, 127.0202), // 17 호수 북동
    LatLng(37.4347, 127.0190), // 18 호수 북서
    LatLng(37.4346, 127.0207), // 19 동 광장
    LatLng(37.4345, 127.0185), // 20 서 광장
    LatLng(37.4333, 127.0195), // 21 남 갈림 (입구 위쪽)
  ];

  // 호수 — 이 점에서 일정 반경 안을 지나는 엣지는 차단해 우회 경로로 유도.
  static const LatLng _lakeCenter = LatLng(37.4343, 127.0196);
  static const double _lakeRadiusMeters = 26;

  // 인접 리스트는 첫 호출 시 한 번 빌드.
  static List<List<int>>? _adjCache;
  static List<List<int>> get _adj => _adjCache ??= _buildAdjacency();

  static List<List<int>> _buildAdjacency() {
    const k = 4; // 각 노드당 이웃 후보 수
    const maxEdgeMeters = 170.0; // 한 엣지 최대 길이
    final adj = List.generate(_nodes.length, (_) => <int>[]);
    for (var i = 0; i < _nodes.length; i++) {
      final candidates = <int>[for (var j = 0; j < _nodes.length; j++) if (j != i) j]
        ..sort((a, b) => _haversine(_nodes[i], _nodes[a])
            .compareTo(_haversine(_nodes[i], _nodes[b])));
      var added = 0;
      for (final j in candidates) {
        if (added >= k) break;
        final d = _haversine(_nodes[i], _nodes[j]);
        if (d > maxEdgeMeters) break;
        if (_edgeCrossesObstacle(_nodes[i], _nodes[j])) continue;
        if (!adj[i].contains(j)) adj[i].add(j);
        if (!adj[j].contains(i)) adj[j].add(i);
        added++;
      }
    }
    return adj;
  }

  static bool _edgeCrossesObstacle(LatLng a, LatLng b) {
    // 엣지를 8 등분 샘플링해 호수 반경 안에 들어가는지 검사.
    for (var step = 0; step <= 8; step++) {
      final t = step / 8.0;
      final lat = a.latitude + (b.latitude - a.latitude) * t;
      final lng = a.longitude + (b.longitude - a.longitude) * t;
      if (_haversine(LatLng(lat, lng), _lakeCenter) < _lakeRadiusMeters) {
        return true;
      }
    }
    return false;
  }

  static int _nearestNode(LatLng p) {
    var best = 0;
    var bestD = double.infinity;
    for (var i = 0; i < _nodes.length; i++) {
      final d = _haversine(p, _nodes[i]);
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    return best;
  }

  /// `origin → destination` 사이 도보 경로를 그래프로 계산해 반환.
  /// 그래프로 경로를 못 찾으면 직선 fallback (routed=false).
  static RouteResult route(LatLng origin, LatLng destination) {
    final straight = _haversine(origin, destination);
    // 아주 가까우면 그래프 의미 없음 — 직선.
    if (straight < 60) {
      return RouteResult(
        points: [origin, destination],
        meters: straight,
        routed: false,
      );
    }

    final s = _nearestNode(origin);
    final t = _nearestNode(destination);
    if (s == t) {
      return RouteResult(
        points: [origin, destination],
        meters: straight,
        routed: false,
      );
    }

    final n = _nodes.length;
    final dist = List<double>.filled(n, double.infinity);
    final prev = List<int>.filled(n, -1);
    dist[s] = 0;
    // (distance, nodeIndex) 정렬 PQ.
    final pq = HeapPriorityQueue();
    pq.add(0, s);
    while (pq.isNotEmpty) {
      final u = pq.removeMin();
      if (u == t) break;
      for (final v in _adj[u]) {
        final w = _haversine(_nodes[u], _nodes[v]);
        final nd = dist[u] + w;
        if (nd < dist[v]) {
          dist[v] = nd;
          prev[v] = u;
          pq.add(nd, v);
        }
      }
    }

    if (dist[t].isInfinite) {
      return RouteResult(
        points: [origin, destination],
        meters: straight,
        routed: false,
      );
    }

    final path = <int>[];
    var cur = t;
    while (cur != -1) {
      path.add(cur);
      cur = prev[cur];
    }
    final wp = path.reversed.map((i) => _nodes[i]).toList();
    final route = [origin, ...wp, destination];

    var meters = 0.0;
    for (var i = 0; i < route.length - 1; i++) {
      meters += _haversine(route[i], route[i + 1]);
    }
    return RouteResult(points: route, meters: meters, routed: true);
  }

  /// 여러 stop 을 순서대로 잇는 다중 구간 경로. 각 leg 그래프 우회.
  static RouteResult routeMulti(List<LatLng> stops) {
    if (stops.length < 2) {
      return RouteResult(points: stops, meters: 0, routed: false);
    }
    final out = <LatLng>[stops.first];
    var meters = 0.0;
    var anyRouted = false;
    for (var i = 0; i < stops.length - 1; i++) {
      final leg = route(stops[i], stops[i + 1]);
      // 첫 점은 이미 들어있으므로 건너뜀.
      out.addAll(leg.points.skip(1));
      meters += leg.meters;
      anyRouted = anyRouted || leg.routed;
    }
    return RouteResult(points: out, meters: meters, routed: anyRouted);
  }

  // ── Haversine ───────────────────────────────────────────────
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

/// 최소 priority queue — Dart core 가 제공 안 해서 간단 구현.
class HeapPriorityQueue {
  final List<double> _keys = [];
  final List<int> _vals = [];

  bool get isNotEmpty => _vals.isNotEmpty;

  void add(double key, int val) {
    _keys.add(key);
    _vals.add(val);
    _siftUp(_vals.length - 1);
  }

  int removeMin() {
    final v = _vals[0];
    final last = _vals.length - 1;
    if (last > 0) {
      _keys[0] = _keys[last];
      _vals[0] = _vals[last];
    }
    _keys.removeLast();
    _vals.removeLast();
    if (_vals.isNotEmpty) _siftDown(0);
    return v;
  }

  void _siftUp(int i) {
    while (i > 0) {
      final p = (i - 1) >> 1;
      if (_keys[p] <= _keys[i]) break;
      _swap(p, i);
      i = p;
    }
  }

  void _siftDown(int i) {
    final n = _vals.length;
    while (true) {
      final l = i * 2 + 1;
      final r = i * 2 + 2;
      var best = i;
      if (l < n && _keys[l] < _keys[best]) best = l;
      if (r < n && _keys[r] < _keys[best]) best = r;
      if (best == i) break;
      _swap(best, i);
      i = best;
    }
  }

  void _swap(int a, int b) {
    final tk = _keys[a]; _keys[a] = _keys[b]; _keys[b] = tk;
    final tv = _vals[a]; _vals[a] = _vals[b]; _vals[b] = tv;
  }
}
