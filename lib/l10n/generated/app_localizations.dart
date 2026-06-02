/// AUTO-GENERATED locale file (mirrors `lib/l10n/app_*.arb`).
/// 이 파일은 `flutter gen-l10n` 으로 재생성 가능. 수동 편집 X — ARB 만 고치고
/// 빌드하면 같은 자리에 다시 생성됨. 빌드 없이도 IDE/analyzer 가 인식하도록
/// 미리 커밋해둔다.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_localizations_en.dart';
import 'app_localizations_ko.dart';

abstract class AppL10n {
  AppL10n(String locale) : localeName = locale;

  final String localeName;

  static AppL10n of(BuildContext context) {
    final result = Localizations.of<AppL10n>(context, AppL10n);
    assert(result != null,
        'No AppL10n found in context. Did you forget delegates in MaterialApp?');
    return result!;
  }

  static const LocalizationsDelegate<AppL10n> delegate = _AppL10nDelegate();

  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = [
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  static const List<Locale> supportedLocales = [Locale('ko'), Locale('en')];

  String get appName;

  String get navHome;
  String get navMap;
  String get navMyLuna;
  String get navArchive;
  String get navMyPage;

  String get common_ok;
  String get common_cancel;
  String get common_close;
  String get common_retry;
  String get common_loading;
  String get common_error;
  String get common_save;
  String get common_done;
  String get common_next;
  String get common_back;
  String get common_min_short;
  String get common_meter_short;
  String get common_kilometer_short;

  String get home_greeting_morning;
  String get home_greeting_afternoon;
  String get home_greeting_evening;
  String get home_search_hint;
  String get home_notifications;
  String get home_today_route;
  String get home_view_all_route;
  String get home_view_more;
  String get home_weather_title;
  String get home_crowd_title;
  String get home_crowd_low;
  String get home_crowd_mid;
  String get home_crowd_high;

  String get map_route_on;
  String get map_gps_label;
  String get map_gps_remote_snackbar;
  String get map_ai_scan;
  String get map_filter_all;
  String get map_filter_attraction;
  String get map_filter_food;
  String get map_filter_photo;
  String get map_search_hint;

  String get myluna_title;
  String get myluna_subtitle;
  String get myluna_refresh;
  String get myluna_skip;
  String get myluna_start_now;
  String get myluna_empty_title;
  String get myluna_empty_subtitle;
  String get myluna_change_profile;
  String get myluna_loading_route;
  String myluna_walking_minutes(int min);
  String myluna_total_time(int min);

  String get archive_title;
  String get archive_season_spring;
  String get archive_season_summer;
  String get archive_season_autumn;
  String get archive_season_winter;
  String get archive_empty_slot;
  String archive_book_collected(int count, int total);

  String get mypage_title;
  String get mypage_section_profile;
  String get mypage_section_preferences;
  String get mypage_section_legal;
  String get mypage_section_app;
  String get mypage_language;
  String get mypage_language_korean;
  String get mypage_language_english;
  String get mypage_language_system;
  String get mypage_notification;
  String get mypage_location;
  String get mypage_marketing_consent;
  String get mypage_reset_onboarding;
  String get mypage_app_version;
  String get mypage_app_info;
  String get mypage_terms;
  String get mypage_privacy;

  String get onboarding_welcome_title;
  String get onboarding_welcome_subtitle;
  String get onboarding_start;
  String get onboarding_companion_title;
  String get onboarding_purpose_title;
  String get onboarding_favorite_title;
  String get onboarding_done_title;

  String get error_network;
  String get error_unknown;
  String get error_load_failed;
}

class _AppL10nDelegate extends LocalizationsDelegate<AppL10n> {
  const _AppL10nDelegate();

  @override
  Future<AppL10n> load(Locale locale) {
    return SynchronousFuture<AppL10n>(_lookup(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ko', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppL10nDelegate old) => false;

  AppL10n _lookup(Locale locale) {
    switch (locale.languageCode) {
      case 'en':
        return AppL10nEn();
      case 'ko':
      default:
        return AppL10nKo();
    }
  }
}
