import '../models/attraction.dart';

/// 마이 루나 추천 — 윈도우 고정 + 건너뛰기 헬퍼.
/// Disney Genie 반면교사: 사용자가 본 추천은 일정 시간 그대로여야 한다.
class LunaRecommendation {
  final List<Attraction> spots;
  final int totalMin;
  final String? rationale;
  final DateTime lockedAt;

  const LunaRecommendation({
    required this.spots,
    required this.totalMin,
    required this.rationale,
    required this.lockedAt,
  });

  /// 추천 고정 윈도우 — 백엔드 데이터가 바뀌어도 이 시간 동안은 같은 추천 유지.
  static const Duration window = Duration(minutes: 10);

  bool windowExpired([DateTime? now]) =>
      (now ?? DateTime.now()).difference(lockedAt) >= window;

  Duration remainingWindow([DateTime? now]) {
    final r = window - (now ?? DateTime.now()).difference(lockedAt);
    return r.isNegative ? Duration.zero : r;
  }

  /// 1번 스팟 제거 → 2번이 1번으로 승격. lockedAt 은 그대로(같은 추천 세트).
  /// 건너뛰기는 클라이언트 동작이므로 윈도우 깨지 않음.
  LunaRecommendation skipFirst() {
    if (spots.length <= 1) return copyWith(spots: const []);
    return copyWith(spots: spots.skip(1).toList());
  }

  bool get isEmpty => spots.isEmpty;

  LunaRecommendation copyWith({
    List<Attraction>? spots,
    int? totalMin,
    String? rationale,
    DateTime? lockedAt,
  }) {
    return LunaRecommendation(
      spots: spots ?? this.spots,
      totalMin: totalMin ?? this.totalMin,
      rationale: rationale ?? this.rationale,
      lockedAt: lockedAt ?? this.lockedAt,
    );
  }
}
