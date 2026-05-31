import 'package:shared_preferences/shared_preferences.dart';

import '../models/attraction.dart';

/// 'easter_egg_{attraction_id}' = true 형식으로 발견 여부 영속화.
class EasterEggService {
  static String _key(String id) => 'easter_egg_$id';

  static Future<bool> isDiscovered(String id) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key(id)) ?? false;
  }

  static Future<void> markDiscovered(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key(id), true);
  }

  /// 현재까지 발견한 모든 어트랙션 ID 집합.
  static Future<Set<String>> discoveredAll() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs
        .getKeys()
        .where((k) => k.startsWith('easter_egg_') && (prefs.getBool(k) ?? false))
        .map((k) => k.substring('easter_egg_'.length))
        .toSet();
  }

  /// 챕터 내 모든 이스터에그 어트랙션 발견 여부.
  static Future<bool> isChapterCompleted(String chapter) async {
    final targets = kChapterTargets[chapter] ?? const [];
    if (targets.isEmpty) return false;
    final discovered = await discoveredAll();
    // 챕터 내 hasEasterEgg=true 인 어트랙션만 카운트
    final eggTargets = targets.where((id) {
      final att = kAttractions.firstWhere(
        (a) => a.id == id,
        orElse: () => kAttractions.first,
      );
      return att.id == id && att.hasEasterEgg;
    }).toList();
    if (eggTargets.isEmpty) return false;
    return eggTargets.every(discovered.contains);
  }

  /// 4개 챕터 완료 상태 한 번에 조회.
  static Future<Map<String, bool>> allChaptersStatus() async {
    final discovered = await discoveredAll();
    final out = <String, bool>{};
    for (final ch in kChapterTargets.keys) {
      final targets = kChapterTargets[ch]!;
      final eggTargets = targets.where((id) {
        final att = kAttractions.where((a) => a.id == id);
        return att.isNotEmpty && att.first.hasEasterEgg;
      }).toList();
      out[ch] = eggTargets.isNotEmpty && eggTargets.every(discovered.contains);
    }
    return out;
  }

  /// 디버그/리셋용 — 모든 발견 기록 삭제.
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    final eggKeys = prefs.getKeys().where((k) => k.startsWith('easter_egg_')).toList();
    for (final k in eggKeys) {
      await prefs.remove(k);
    }
  }
}
