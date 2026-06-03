import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:seoul_land_app/services/path_graph.dart';

// PathGraph 내부 호수 중심 좌표 (테스트 검증용).
const _lakeCenter = LatLng(37.4343, 127.0196);
const _lakeRadius = 26.0;

double _haversine(LatLng a, LatLng b) {
  const r = 6371000.0;
  final dLat = (b.latitude - a.latitude) * math.pi / 180;
  final dLng = (b.longitude - a.longitude) * math.pi / 180;
  final la1 = a.latitude * math.pi / 180;
  final la2 = b.latitude * math.pi / 180;
  final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(la1) * math.cos(la2) *
          math.sin(dLng / 2) * math.sin(dLng / 2);
  return 2 * r * math.asin(math.sqrt(h));
}

void main() {
  group('PathGraph.route', () {
    test('짧은 거리(60m 미만)는 직선 fallback', () {
      const a = LatLng(37.4330, 127.0188);
      const b = LatLng(37.4331, 127.0189); // ~10m
      final r = PathGraph.route(a, b);
      expect(r.points.length, 2);
      expect(r.routed, isFalse);
    });

    test('호수를 사이에 둔 두 점은 우회 경로(중간 웨이포인트 ≥1)', () {
      const north = LatLng(37.4355, 127.0196);
      const south = LatLng(37.4330, 127.0196);
      final r = PathGraph.route(north, south);
      expect(r.routed, isTrue, reason: '그래프 우회가 활성화되어야 함');
      expect(r.points.length, greaterThanOrEqualTo(3),
          reason: '직선 [origin, dest] 두 점이면 우회 실패');
      // 중간 웨이포인트가 모두 호수 밖에 있는지 확인.
      for (var i = 1; i < r.points.length - 1; i++) {
        final d = _haversine(r.points[i], _lakeCenter);
        expect(d, greaterThan(_lakeRadius - 1),
            reason: '중간 점 ${r.points[i]} 가 호수 안에 있음');
      }
    });

    test('도보 거리 ≥ 직선 거리', () {
      const origin = LatLng(37.4330, 127.0177);
      const dest = LatLng(37.4357, 127.0210);
      final r = PathGraph.route(origin, dest);
      final straight = _haversine(origin, dest);
      expect(r.meters, greaterThanOrEqualTo(straight - 1));
    });

    test('walkMinutes 는 200m 정도 거리에서 1~10분 사이', () {
      const origin = LatLng(37.4330, 127.0188);
      const dest = LatLng(37.4347, 127.0202);
      final r = PathGraph.route(origin, dest);
      expect(r.walkMinutes, greaterThanOrEqualTo(1));
      expect(r.walkMinutes, lessThanOrEqualTo(10));
    });
  });

  group('PathGraph.routeMulti', () {
    test('빈/단일 stops 안전 처리', () {
      expect(PathGraph.routeMulti(const []).points, isEmpty);
      expect(
        PathGraph.routeMulti(const [LatLng(37.43, 127.01)]).points.length,
        1,
      );
    });

    test('3-stop 경로 — 시작/끝 보존, 거리 누적', () {
      final stops = [
        const LatLng(37.4330, 127.0177),
        const LatLng(37.4347, 127.0207),
        const LatLng(37.4337, 127.0180),
      ];
      final r = PathGraph.routeMulti(stops);
      expect(r.points.first, stops.first);
      expect(r.points.last, stops.last);
      expect(r.meters, greaterThan(0));
    });
  });
}
