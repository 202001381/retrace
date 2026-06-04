import 'attraction.dart';

/// 장소 카테고리 — `Attraction.category` 문자열과 1:1 매핑.
enum PlaceCategory {
  attraction('어트랙션'),
  restaurant('음식점'),
  cafe('카페'),
  photoSpot('포토스팟');

  final String label;
  const PlaceCategory(this.label);

  static PlaceCategory? fromLabel(String l) {
    for (final c in PlaceCategory.values) {
      if (c.label == l) return c;
    }
    return null;
  }
}

/// 장소 리스트 화면의 필터 상태. immutable + 순수 적용 함수.
class PlaceFilterState {
  final PlaceCategory? category; // null = 전체
  final bool onlyOperating;
  /// "내 이스터에그" — 내가 수집한 어트랙션만.
  final bool onlyMyEasterEggs;
  /// "이스터에그" — 이스터에그가 있는 어트랙션 전체 (수집 여부 무관).
  final bool onlyHasEasterEgg;

  const PlaceFilterState({
    this.category,
    this.onlyOperating = false,
    this.onlyMyEasterEggs = false,
    this.onlyHasEasterEgg = false,
  });

  static const PlaceFilterState empty = PlaceFilterState();

  bool get isAnyActive =>
      category != null ||
      onlyOperating ||
      onlyMyEasterEggs ||
      onlyHasEasterEgg;

  PlaceFilterState copyWith({
    PlaceCategory? category,
    bool clearCategory = false,
    bool? onlyOperating,
    bool? onlyMyEasterEggs,
    bool? onlyHasEasterEgg,
  }) {
    return PlaceFilterState(
      category: clearCategory ? null : (category ?? this.category),
      onlyOperating: onlyOperating ?? this.onlyOperating,
      onlyMyEasterEggs: onlyMyEasterEggs ?? this.onlyMyEasterEggs,
      onlyHasEasterEgg: onlyHasEasterEgg ?? this.onlyHasEasterEgg,
    );
  }

  /// 입력 리스트에 필터를 적용해 새 리스트를 반환. discoveredIds 는
  /// "내 이스터에그" 토글의 모집단(사용자가 수집한 어트랙션 id 집합).
  List<Attraction> apply(
    Iterable<Attraction> all,
    Set<String> discoveredIds,
  ) {
    return all.where((a) {
      if (category != null && a.category != category!.label) return false;
      if (onlyOperating && !a.isOperating) return false;
      if (onlyHasEasterEgg && !a.hasEasterEgg) return false;
      if (onlyMyEasterEggs && !discoveredIds.contains(a.id)) return false;
      return true;
    }).toList();
  }

  @override
  bool operator ==(Object other) =>
      other is PlaceFilterState &&
      other.category == category &&
      other.onlyOperating == onlyOperating &&
      other.onlyMyEasterEggs == onlyMyEasterEggs &&
      other.onlyHasEasterEgg == onlyHasEasterEgg;

  @override
  int get hashCode => Object.hash(
      category, onlyOperating, onlyMyEasterEggs, onlyHasEasterEgg);
}
