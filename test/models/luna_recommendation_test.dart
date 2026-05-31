import 'package:flutter_test/flutter_test.dart';
import 'package:seoul_land_app/models/attraction.dart';
import 'package:seoul_land_app/models/luna_recommendation.dart';

Attraction _spot(String id) => Attraction(
      id: id,
      name: id,
      category: '어트랙션',
      zone: 'zone',
      lat: 0,
      lng: 0,
      indoor: false,
      heightLimit: 0,
      thrillLevel: 0,
      waitMinutes: 10,
      rating: 4.0,
      hasEasterEgg: false,
      chapter: null,
      description: '',
      icon: '🎢',
      isOperating: true,
    );

LunaRecommendation _rec(
  List<Attraction> spots, {
  DateTime? lockedAt,
}) =>
    LunaRecommendation(
      spots: spots,
      totalMin: 30,
      rationale: 'mock',
      lockedAt: lockedAt ?? DateTime(2026, 5, 26, 12, 0),
    );

void main() {
  group('LunaRecommendation window', () {
    final fixed = DateTime(2026, 5, 26, 12, 0);

    test('not expired before 10 minutes', () {
      final r = _rec([_spot('a')], lockedAt: fixed);
      expect(r.windowExpired(fixed.add(const Duration(minutes: 9, seconds: 59))),
          isFalse);
    });

    test('expired exactly at 10 minutes', () {
      final r = _rec([_spot('a')], lockedAt: fixed);
      expect(r.windowExpired(fixed.add(const Duration(minutes: 10))), isTrue);
    });

    test('expired well after window', () {
      final r = _rec([_spot('a')], lockedAt: fixed);
      expect(r.windowExpired(fixed.add(const Duration(hours: 1))), isTrue);
    });

    test('remainingWindow positive before expiry', () {
      final r = _rec([_spot('a')], lockedAt: fixed);
      expect(r.remainingWindow(fixed.add(const Duration(minutes: 3))),
          const Duration(minutes: 7));
    });

    test('remainingWindow is Duration.zero (not negative) after expiry', () {
      final r = _rec([_spot('a')], lockedAt: fixed);
      expect(r.remainingWindow(fixed.add(const Duration(hours: 1))),
          Duration.zero);
    });
  });

  group('LunaRecommendation skipFirst', () {
    final fixed = DateTime(2026, 5, 26, 12, 0);

    test('removes first spot, second promoted', () {
      final r = _rec([_spot('a'), _spot('b'), _spot('c')], lockedAt: fixed);
      final next = r.skipFirst();
      expect(next.spots.map((s) => s.id), ['b', 'c']);
    });

    test('lockedAt preserved across skip (윈도우 유지)', () {
      final r = _rec([_spot('a'), _spot('b')], lockedAt: fixed);
      final next = r.skipFirst();
      expect(next.lockedAt, fixed);
    });

    test('single-spot becomes empty after skip', () {
      final r = _rec([_spot('a')], lockedAt: fixed);
      final next = r.skipFirst();
      expect(next.isEmpty, isTrue);
    });

    test('empty stays empty when skipped again', () {
      final r = _rec(const [], lockedAt: fixed);
      final next = r.skipFirst();
      expect(next.isEmpty, isTrue);
    });
  });

  group('LunaRecommendation.isEmpty', () {
    test('true on empty spots', () {
      expect(_rec(const []).isEmpty, isTrue);
    });
    test('false on non-empty', () {
      expect(_rec([_spot('a')]).isEmpty, isFalse);
    });
  });
}
