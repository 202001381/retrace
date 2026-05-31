import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/chapter.dart';
import '../models/user_preferences.dart';
import '../models/user_profile.dart';

/// users/{uid} 문서 CRUD + 챕터 상태 관리.
class FirestoreService {
  FirestoreService({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _users => _db.collection('users');
  DocumentReference<Map<String, dynamic>> _userDoc(String uid) => _users.doc(uid);

  // ── Profile ────────────────────────────────────────────────
  Future<void> upsertProfile(String uid, UserProfile profile) async {
    await _userDoc(uid).set({'profile': profile.toMap()}, SetOptions(merge: true));
  }

  Future<UserProfile?> getProfile(String uid) async {
    final snap = await _userDoc(uid).get();
    final data = snap.data();
    if (data == null) return null;
    final p = data['profile'] as Map<String, dynamic>?;
    return p == null ? null : UserProfile.fromMap(p);
  }

  // ── FCM token ──────────────────────────────────────────────
  Future<void> upsertFcmToken(String uid, String token) async {
    await _userDoc(uid).set({'fcm_token': token}, SetOptions(merge: true));
  }

  // ── Preferences (알림·위치·마케팅) ─────────────────────────
  Future<UserPreferences?> getPreferences(String uid) async {
    final snap = await _userDoc(uid).get();
    final m = snap.data()?['preferences'] as Map<String, dynamic>?;
    if (m == null) return null;
    return UserPreferences.fromMap(m);
  }

  Future<void> setPreferences(String uid, UserPreferences prefs) async {
    await _userDoc(uid).set(
      {'preferences': prefs.toMap()},
      SetOptions(merge: true),
    );
  }

  // ── Visit history ──────────────────────────────────────────
  Future<void> appendVisit(String uid, VisitHistoryEntry entry) async {
    await _userDoc(uid).set({
      'visit_history': FieldValue.arrayUnion([entry.toMap()]),
      'last_visit_at': Timestamp.fromDate(entry.date.toUtc()),
    }, SetOptions(merge: true));
  }

  Future<List<VisitHistoryEntry>> listVisits(String uid) async {
    final snap = await _userDoc(uid).get();
    final list = (snap.data()?['visit_history'] as List?) ?? const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(VisitHistoryEntry.fromMap)
        .toList();
  }

  // ── Chapter status ─────────────────────────────────────────
  Future<Map<Season, ChapterStatus>> getChapterStatus(String uid) async {
    final snap = await _userDoc(uid).get();
    final raw = (snap.data()?['chapter_status'] as Map<String, dynamic>?) ?? const {};
    return {
      for (final s in Season.values)
        s: ChapterStatus.fromMap(raw[s.key] as Map<String, dynamic>?),
    };
  }

  /// 어트랙션 발견 시 호출. 챕터 자동 활성화 + completed 자동 갱신.
  Future<ChapterStatus> recordDiscovery({
    required String uid,
    required String attractionId,
    DateTime? at,
  }) async {
    final ts = at ?? DateTime.now();
    final season = SeasonX.fromMonth(ts.month);
    final docRef = _userDoc(uid);

    return _db.runTransaction<ChapterStatus>((tx) async {
      final snap = await tx.get(docRef);
      final raw = (snap.data()?['chapter_status'] as Map<String, dynamic>?) ?? {};
      final current = ChapterStatus.fromMap(raw[season.key] as Map<String, dynamic>?);

      // 대상 어트랙션이 아니면 discovered 만 누적 (UX 보존), completed 평가 X
      final isTarget = chapterTargets[season]?.contains(attractionId) ?? false;
      final next = current.discovered.contains(attractionId)
          ? current
          : current.copyWith(
              discovered: [...current.discovered, attractionId],
              unlockedAt: current.unlockedAt ?? ts,
            );

      bool completed = current.completed;
      if (isTarget) {
        final targets = chapterTargets[season]!.toSet();
        final visitedTargets = next.discovered.toSet().intersection(targets);
        completed = visitedTargets.length >= targets.length;
      }

      final updated = next.copyWith(completed: completed);
      tx.set(
        docRef,
        {
          'chapter_status': {season.key: updated.toMap()},
        },
        SetOptions(merge: true),
      );
      return updated;
    });
  }

  /// 미완성 챕터 목록 반환.
  Future<List<Season>> incompleteChapters(String uid) async {
    final status = await getChapterStatus(uid);
    return Season.values.where((s) => !(status[s]?.completed ?? false)).toList();
  }
}
