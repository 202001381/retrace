import 'package:flutter_test/flutter_test.dart';
import 'package:seoul_land_app/models/attraction.dart';
import 'package:seoul_land_app/models/demo_scenario.dart';

void main() {
  group('DemoScenario.resolveStops', () {
    test('모든 시나리오 stopIds 가 kAttractions 에 실제 존재', () {
      final byId = {for (final a in kAttractions) a.id};
      for (final s in DemoScenario.values) {
        for (final id in s.stopIds) {
          expect(byId.contains(id), isTrue,
              reason: '${s.name} 의 누락 id: $id');
        }
      }
    });

    test('각 시나리오는 10개 이상의 스팟을 가짐 (~4시간 코스)', () {
      for (final s in DemoScenario.values) {
        expect(s.stopIds.length, greaterThanOrEqualTo(10),
            reason: '${s.name} 너무 짧음');
      }
    });

    test('각 시나리오는 최소 1개 음식점 포함 (식사 동선)', () {
      for (final s in DemoScenario.values) {
        final hasFood = s.resolveStops().any((a) => a.category == '음식점');
        expect(hasFood, isTrue, reason: '${s.name} 식사 동선 누락');
      }
    });
  });

  group('DemoScenario.toRecommendation', () {
    const gateLat = 37.4332;
    const gateLng = 127.0174;

    test('totalMin 이 4시간 코스 범위 (3~7시간) 안 — 실제 데이터 워크용 여유', () {
      for (final s in DemoScenario.values) {
        final r = s.toRecommendation(
          originLat: gateLat,
          originLng: gateLng,
        );
        expect(r.totalMin, inInclusiveRange(180, 420),
            reason: '${s.name} totalMin=${r.totalMin} 범위 밖');
      }
    });

    test('rationale 가 비어있지 않음', () {
      for (final s in DemoScenario.values) {
        final r = s.toRecommendation(
          originLat: gateLat,
          originLng: gateLng,
        );
        expect(r.rationale, isNotNull);
        expect(r.rationale!.isNotEmpty, isTrue);
      }
    });

    test('lockedAt 이 현재 시각 근처 (윈도우 lock 시작)', () {
      final s = DemoScenario.family;
      final before = DateTime.now();
      final r = s.toRecommendation(
        originLat: gateLat,
        originLng: gateLng,
      );
      final after = DateTime.now();
      expect(r.lockedAt.isAfter(before.subtract(const Duration(seconds: 1))),
          isTrue);
      expect(r.lockedAt.isBefore(after.add(const Duration(seconds: 1))),
          isTrue);
    });

    test('spots.length 가 stopIds.length 와 일치 (해석 손실 없음)', () {
      for (final s in DemoScenario.values) {
        final r = s.toRecommendation(
          originLat: gateLat,
          originLng: gateLng,
        );
        expect(r.spots.length, s.stopIds.length,
            reason: '${s.name} 일부 스팟이 해석 안 됨');
      }
    });
  });
}
