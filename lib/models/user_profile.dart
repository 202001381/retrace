class UserProfile {
  final String name;
  final String companionType; // 가족 / 연인 / 친구 / 혼자
  final DateTime createdAt;

  const UserProfile({
    required this.name,
    required this.companionType,
    required this.createdAt,
  });

  Map<String, Object?> toMap() => {
        'name': name,
        'companion_type': companionType,
        'created_at': createdAt.toUtc().toIso8601String(),
      };

  static UserProfile fromMap(Map<String, Object?> m) => UserProfile(
        name: m['name'] as String? ?? '',
        companionType: m['companion_type'] as String? ?? '가족',
        createdAt: _parseTs(m['created_at']) ?? DateTime.now(),
      );
}

class VisitHistoryEntry {
  final DateTime date;
  final String weather;
  final String companion;
  final int durationMin;
  final List<String> attractionsVisited;

  const VisitHistoryEntry({
    required this.date,
    required this.weather,
    required this.companion,
    required this.durationMin,
    required this.attractionsVisited,
  });

  Map<String, Object?> toMap() => {
        'date': date.toUtc().toIso8601String(),
        'weather': weather,
        'companion': companion,
        'duration_min': durationMin,
        'attractions_visited': attractionsVisited,
      };

  static VisitHistoryEntry fromMap(Map<String, Object?> m) => VisitHistoryEntry(
        date: _parseTs(m['date']) ?? DateTime.now(),
        weather: m['weather'] as String? ?? '',
        companion: m['companion'] as String? ?? '',
        durationMin: (m['duration_min'] as num?)?.toInt() ?? 0,
        attractionsVisited:
            ((m['attractions_visited'] as List?) ?? const []).whereType<String>().toList(),
      );
}

DateTime? _parseTs(Object? v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v);
  try {
    final dyn = v as dynamic;
    return dyn.toDate() as DateTime?;
  } catch (_) {
    return null;
  }
}
