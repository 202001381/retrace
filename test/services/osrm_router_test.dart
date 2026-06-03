// OsrmRouter 의 핵심은 외부 HTTP 호출이라 실제 호출 없이 테스트가 어렵다.
// 여기서는 RouteResult/PathGraph fallback 로직과 짧은 거리 skip 만 검증.
//
// 실제 OSRM 응답 파싱 정확도는 통합 테스트(devices) 에서 확인.

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:seoul_land_app/services/osrm_router.dart';

void main() {
  group('OsrmRouter.route', () {
    test('60m 미만 짧은 거리 — API 호출 없이 직선 fallback', () async {
      // 10m 거리 — _skipThresholdMeters(60m) 아래.
      const a = LatLng(37.4350, 127.0180);
      const b = LatLng(37.4351, 127.0181);
      final r = await OsrmRouter.route(a, b);
      expect(r.points.length, 2);
      expect(r.routed, isFalse);
    });
  });

  group('OsrmRouter.routeMulti', () {
    test('빈 stops — 빈 결과', () async {
      final r = await OsrmRouter.routeMulti([]);
      expect(r.points, isEmpty);
      expect(r.meters, 0);
    });

    test('단일 stop — 점 1개 그대로', () async {
      final r = await OsrmRouter.routeMulti([const LatLng(37.43, 127.01)]);
      expect(r.points.length, 1);
    });
  });
}
