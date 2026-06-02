import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 사용자 선택 로케일 — null 이면 시스템 기본값(supportedLocales 중 매칭).
/// ValueNotifier 로 MaterialApp 가 즉시 rebuild.
class LocaleService {
  LocaleService._();
  static final LocaleService instance = LocaleService._();

  static const String _kKey = 'app_locale';
  static const List<Locale> supported = [
    Locale('ko'),
    Locale('en'),
  ];

  final ValueNotifier<Locale?> locale = ValueNotifier<Locale?>(null);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_kKey);
    if (code == null || code.isEmpty) {
      locale.value = null;
      return;
    }
    locale.value = Locale(code);
  }

  Future<void> setLocale(Locale? next) async {
    locale.value = next;
    final prefs = await SharedPreferences.getInstance();
    if (next == null) {
      await prefs.remove(_kKey);
    } else {
      await prefs.setString(_kKey, next.languageCode);
    }
  }
}
