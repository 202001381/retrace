import 'package:flutter_test/flutter_test.dart';
import 'package:seoul_land_app/models/attraction.dart';
import 'package:seoul_land_app/models/place_filter.dart';

Attraction _make({
  required String id,
  String category = '어트랙션',
  bool isOperating = true,
  bool hasEasterEgg = false,
}) {
  return Attraction(
    id: id,
    name: id,
    category: category,
    zone: 'zone',
    lat: 0,
    lng: 0,
    indoor: false,
    heightLimit: 0,
    thrillLevel: 0,
    waitMinutes: 0,
    rating: 0,
    hasEasterEgg: hasEasterEgg,
    chapter: null,
    description: '',
    icon: '',
    isOperating: isOperating,
  );
}

void main() {
  group('PlaceFilterState.apply', () {
    final all = <Attraction>[
      _make(id: 'a1', category: '어트랙션', isOperating: true, hasEasterEgg: true),
      _make(id: 'a2', category: '어트랙션', isOperating: false, hasEasterEgg: false),
      _make(id: 'f1', category: '음식점', isOperating: true, hasEasterEgg: false),
      _make(id: 'c1', category: '카페', isOperating: true, hasEasterEgg: true),
      _make(id: 'p1', category: '포토스팟', isOperating: false, hasEasterEgg: true),
    ];

    test('empty filter returns all entries', () {
      final r = PlaceFilterState.empty.apply(all, {});
      expect(r.map((a) => a.id), ['a1', 'a2', 'f1', 'c1', 'p1']);
    });

    test('category narrows to a single label', () {
      final r = const PlaceFilterState(category: PlaceCategory.cafe)
          .apply(all, {});
      expect(r.map((a) => a.id), ['c1']);
    });

    test('onlyOperating drops closed entries', () {
      final r = const PlaceFilterState(onlyOperating: true).apply(all, {});
      expect(r.map((a) => a.id), ['a1', 'f1', 'c1']);
    });

    test('onlyMyEasterEggs intersects with discoveredIds, not hasEasterEgg', () {
      // c1 has an egg but the user hasn't collected it → excluded.
      // a1 was collected → included even though many others also have eggs.
      final r =
          const PlaceFilterState(onlyMyEasterEggs: true).apply(all, {'a1'});
      expect(r.map((a) => a.id), ['a1']);
    });

    test('onlyMyEasterEggs with empty discoveredIds returns nothing', () {
      final r =
          const PlaceFilterState(onlyMyEasterEggs: true).apply(all, {});
      expect(r, isEmpty);
    });

    test('category × onlyOperating × onlyMyEasterEggs combines AND', () {
      const f = PlaceFilterState(
        category: PlaceCategory.attraction,
        onlyOperating: true,
        onlyMyEasterEggs: true,
      );
      // a1 is attraction, operating, and collected → in.
      // a2 is attraction but closed → out.
      // c1 is collected but cafe → out.
      final r = f.apply(all, {'a1', 'c1'});
      expect(r.map((a) => a.id), ['a1']);
    });

    test('isAnyActive reflects state', () {
      expect(PlaceFilterState.empty.isAnyActive, isFalse);
      expect(
        const PlaceFilterState(category: PlaceCategory.cafe).isAnyActive,
        isTrue,
      );
      expect(const PlaceFilterState(onlyOperating: true).isAnyActive, isTrue);
      expect(
        const PlaceFilterState(onlyMyEasterEggs: true).isAnyActive,
        isTrue,
      );
    });

    test('copyWith clearCategory drops category to null', () {
      const f = PlaceFilterState(category: PlaceCategory.cafe, onlyOperating: true);
      final cleared = f.copyWith(clearCategory: true);
      expect(cleared.category, isNull);
      expect(cleared.onlyOperating, isTrue);
    });
  });

  group('PlaceCategory.fromLabel', () {
    test('maps known labels to enum values', () {
      expect(PlaceCategory.fromLabel('어트랙션'), PlaceCategory.attraction);
      expect(PlaceCategory.fromLabel('음식점'), PlaceCategory.restaurant);
      expect(PlaceCategory.fromLabel('카페'), PlaceCategory.cafe);
      expect(PlaceCategory.fromLabel('포토스팟'), PlaceCategory.photoSpot);
    });

    test('returns null for unknown label', () {
      expect(PlaceCategory.fromLabel('전체'), isNull);
      expect(PlaceCategory.fromLabel(''), isNull);
    });
  });
}
