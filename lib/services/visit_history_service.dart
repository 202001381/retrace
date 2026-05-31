import 'package:shared_preferences/shared_preferences.dart';

/// 마지막 방문 시각을 영속화. 루나 프라이싱 카피와 동선 추천의
/// 재방문 가산점 입력으로 사용된다.
class VisitHistoryService {
  static const _kLastVisitAt = 'visit_log_last_at';

  static Future<DateTime?> lastVisitAt() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_kLastVisitAt);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  static Future<int?> lastVisitDaysAgo() async {
    final at = await lastVisitAt();
    if (at == null) return null;
    return DateTime.now().difference(at).inDays;
  }

  static Future<void> markVisitedNow() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kLastVisitAt, DateTime.now().millisecondsSinceEpoch);
  }

  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kLastVisitAt);
  }
}
