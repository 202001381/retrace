import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_preferences.dart';
import 'firestore_service.dart';

/// 사용자 설정 단일 진실 — SharedPreferences canonical, Firestore best-effort sync.
/// 인증 시스템이 들어오면 [_guestUid] 부분만 실제 uid 로 교체.
class PreferencesService {
  PreferencesService._({FirestoreService? remote}) : _remote = remote;

  static final PreferencesService instance = PreferencesService._();

  /// FirestoreService 는 Firebase 초기화 후에만 안전 — lazy + 실패 시 다음 시도로.
  FirestoreService? _remote;

  static const String _kPrefsKey = 'user_preferences_v1';
  // TODO: auth 연동 후 실제 uid 사용. 게스트 동의 이력도 마이그레이션 대상.
  static const String _guestUid = 'guest';

  final ValueNotifier<UserPreferences> _notifier =
      ValueNotifier<UserPreferences>(UserPreferences.defaults);
  bool _loaded = false;

  ValueListenable<UserPreferences> get listenable => _notifier;
  UserPreferences get current => _notifier.value;

  Future<UserPreferences> read() async {
    if (_loaded) return _notifier.value;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPrefsKey);
    if (raw != null) {
      try {
        final map = jsonDecode(raw) as Map<String, Object?>;
        _notifier.value = UserPreferences.fromMap(map);
      } catch (_) {
        // 직렬화 손상 — 디폴트 유지.
      }
    }
    _loaded = true;
    return _notifier.value;
  }

  /// 로컬 즉시 반영 + Firestore best-effort. 실패해도 UI 영향 X.
  Future<void> update(UserPreferences next) async {
    _notifier.value = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefsKey, jsonEncode(next.toMap()));
    unawaited(_syncRemote(next));
  }

  Future<void> _syncRemote(UserPreferences next) async {
    try {
      final remote = _remote ??= FirestoreService();
      await remote.setPreferences(_guestUid, next);
    } catch (_) {
      // 네트워크/인증/Firebase 미초기화 모두 무시 — 로컬은 이미 반영됨.
    }
  }

  /// 개발/테스트용 초기화.
  Future<void> reset() async {
    _notifier.value = UserPreferences.defaults;
    _loaded = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPrefsKey);
  }
}
