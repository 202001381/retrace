enum Season { spring, summer, autumn, winter }

extension SeasonX on Season {
  String get key {
    switch (this) {
      case Season.spring:
        return 'spring';
      case Season.summer:
        return 'summer';
      case Season.autumn:
        return 'autumn';
      case Season.winter:
        return 'winter';
    }
  }

  String get label {
    switch (this) {
      case Season.spring:
        return '봄';
      case Season.summer:
        return '여름';
      case Season.autumn:
        return '가을';
      case Season.winter:
        return '겨울';
    }
  }

  /// 한국 기준 활성화 월 범위.
  static Season fromMonth(int month) {
    if (month >= 3 && month <= 5) return Season.spring;
    if (month >= 6 && month <= 8) return Season.summer;
    if (month >= 9 && month <= 11) return Season.autumn;
    return Season.winter;
  }
}

/// 계절별 챕터 대상 어트랙션 (각 5개). attractionId 는 SeoulLandSpots 의 id 와 일치.
const Map<Season, List<String>> chapterTargets = {
  Season.spring: ['a08', 'a14', 'a09', 'a15', 'a07'],     // 가족형: 회전목마, 빅회전목마, 범퍼카, 코끼리열차, 대관람차
  Season.summer: ['a03', 'a06', 'a04', 'a05', 'a02'],     // 워터·야외 스릴: 후룸, 급류, 자이로스윙, 킹바이킹, 블랙홀
  Season.autumn: ['a01', 'a07', 'a12', 'a14', 'a08'],     // 야간 개장 연계: 은하열차, 대관람차, 스카이X, 빅회전목마, 회전목마
  Season.winter: ['a13', 'a11', 'a02', 'a10', 'a08'],     // 실내 중심: VR게이트, 타임머신5D, 블랙홀(실내), 해적소굴, 회전목마
};

class ChapterStatus {
  final bool completed;
  final List<String> discovered;
  final DateTime? unlockedAt;

  const ChapterStatus({
    this.completed = false,
    this.discovered = const [],
    this.unlockedAt,
  });

  ChapterStatus copyWith({
    bool? completed,
    List<String>? discovered,
    DateTime? unlockedAt,
  }) =>
      ChapterStatus(
        completed: completed ?? this.completed,
        discovered: discovered ?? this.discovered,
        unlockedAt: unlockedAt ?? this.unlockedAt,
      );

  Map<String, Object?> toMap() => {
        'completed': completed,
        'discovered': discovered,
        'unlocked_at': unlockedAt?.toUtc().toIso8601String(),
      };

  static ChapterStatus fromMap(Map<String, Object?>? m) {
    if (m == null) return const ChapterStatus();
    return ChapterStatus(
      completed: m['completed'] as bool? ?? false,
      discovered: ((m['discovered'] as List?) ?? const []).whereType<String>().toList(),
      unlockedAt: _parseTs(m['unlocked_at']),
    );
  }
}

DateTime? _parseTs(Object? v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v);
  // Firestore Timestamp 객체
  try {
    final dyn = v as dynamic;
    return dyn.toDate() as DateTime?;
  } catch (_) {
    return null;
  }
}
