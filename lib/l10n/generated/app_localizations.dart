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
  String get home_today_events;
  String get home_get_ticket;
  String get home_discount_label;
  String get home_card_weather;
  String get home_card_crowd;
  String home_card_crowd_current(String level);
  String get home_companion_change;
  String get home_view_attractions;

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
  String get mypage_settings_payment;
  String get mypage_settings_terms;
  String get mypage_coming_soon;
  String get mypage_feedback;
  String get mypage_replay_onboarding_sub;
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

  String get cat_attraction;
  String get cat_food;
  String get cat_restaurant;
  String get cat_cafe;
  String get cat_photo;
  String get cat_photo_spot;
  String get label_thrill;
  String get label_activity;
  String get label_family;
  String get label_date;
  String get label_thrill_activity;

  String wait_short(int min);
  String wait_expected(int min);
  String get walk_short;
  String get wait_label;

  String get home_first_visit_welcome;
  String get home_today_park_is;
  String get home_park_is_chill;
  String get home_park_is_special;
  String get home_park_is_calm;
  String get home_today_chill_day;
  String get home_weather_cloudy_18;
  String get home_weather_detail_today;
  String get home_weather_rain_detail;
  String get home_crowd_mid_label;
  String get home_crowd_recommend_morning;
  String get home_drawing_route;
  String get home_route_load_failed;
  String get home_retry;
  String home_route_total_min(int min);
  String get home_change_conditions;
  String home_uncollected_eggs(int count);
  String get home_route_preparing;
  String get home_view_full_route;
  String get home_onboarding_answers;
  String get home_view_all;

  String get myluna_loading_recs;
  String get myluna_load_failed;
  String get myluna_change_conditions;
  String get myluna_condition;
  String get myluna_next;
  String get myluna_next_candidate;
  String get myluna_change_conditions_prompt;
  String get myluna_skipped_too_many;
  String get myluna_get_new_rec;
  String get myluna_sample_preview;
  String get myluna_stop_sample;
  String get myluna_navigate_start;
  String myluna_total_min(int min);
  String myluna_course_count(int count);
  String myluna_missing_eggs(int count);

  String get map_route_realtime;
  String get map_no_eggs_collected;
  String get map_visit_starred;
  String get map_filter_reset;
  String get map_operating_only;
  String get map_no_match;
  String map_total_count(int count);
  String map_result_count(int count);
  String get map_rerecommend;

  String get onboarding_intro_title;
  String get onboarding_make_my_luna;
  String get onboarding_just_3;
  String get onboarding_q_purpose;
  String get onboarding_q_favorite;
  String get onboarding_q_party;
  String get onboarding_pick_accurate;
  String get onboarding_party_count_msg;
  String get onboarding_party_total;
  String get onboarding_party_count;
  String get onboarding_skip;
  String get onboarding_browse;
  String get onboarding_for_you;
  String get onboarding_ready;
  String get onboarding_my_luna_what;
  String get onboarding_luna_pricing_what;
  String get onboarding_proactive_notif;
  String get onboarding_realtime_discount;
  String get onboarding_anytime_new_course;
  String get onboarding_pricing_desc;
  String get onboarding_notif_desc;
  String get onboarding_personalized_desc;
  String get onboarding_thrill_course;
  String get onboarding_family_course;
  String get onboarding_date_course;
  String get onboarding_custom_course;
  String get onboarding_thrill_fast;
  String get onboarding_family_together;
  String get onboarding_either_ok;
  String onboarding_summary_family_infant(int infant);
  String onboarding_summary_family(int total);
  String onboarding_summary_thrill(int total);
  String get onboarding_summary_date;
  String onboarding_summary_custom(int total);
  String get onboarding_result_see_route;
  String get onboarding_result_get_ticket;
  String get onboarding_pricing_short;
  String onboarding_pricing_now_off(int pct);
  String spot_reviews_count(int count);
  String spot_duration_min(int min);
  String get spot_wait_now_label;
  String get spot_price_range_label;
  String get spot_photo_tip_title;
  String get home_today_discount_detail;
  String home_saving_today(String amount);
  String home_save_with_luna_ticket(String amount);
  String home_wait_eta_short(int min);
  String get rec_browse_all;
  String get rec_filter_operating;
  String get rec_filter_egg;
  String rec_wait_eta_short(int min);
  String rec_zone_wait_eta(String zone, int min);
  String nav_walk_eta_short(int min);
  String route_custom_recommend(String companion);
  String route_stops_count(int count);
  String get route_ai_optimal;
  String checkout_luna_discount_pct(int pct);
  String price_off_pct(int pct);
  String price_list_price(String price);
  String get attr_luna_finding_story;
  String get narrative_found;
  String get narrative_placeholder;
  String get narrative_save_chronicle;
  String archive_photo_load_failed(String error);
  String map_nav_status(String name, int min);
  String get map_filter_my_eggs;
  String get nav_arrival_hint;
  String nav_arrival_close(String name);
  String get discount_reason_weather;
  String get discount_reason_weekday;
  String get discount_reason_low_demand;
  String get discount_reason_event;
  String narrative_load_error(String error);
  String get checkout_expired_title;
  String checkout_pay_now(String amount);
  String get checkout_locked_disclaimer;
  String get cat_show;
  String get cat_facility;
  String rec_thrill_level(int level);
  String get home_why_offer_prefix;
  String get home_why_offer_suffix;
  String get myluna_stat_walk;
  String get myluna_stat_wait;
  String get myluna_stat_total;
  String myluna_stat_min(int min);
  String get reward_unlock_eyebrow;
  String reward_unlock_title(String type);
  String reward_unlock_subtitle(int unlocked, int total);
  String get reward_unlock_use_now_q;
  String get reward_action_use_now;
  String get reward_action_later;
  String get reward_action_view_code;
  String get reward_type_goods;
  String get reward_type_ticket;
  String get reward_code_label;
  String get reward_show_at_store;
  String get reward_already_redeemed;
  String get reward_progress_title;
  String reward_progress_books(int n, int total);
  String get reward_progress_next_at_3;
  String get reward_progress_next_at_5;
  String get reward_progress_completed;
  String get reward_history_title;
  String get reward_history_empty;
  String archive_chapter_label(String season);
  String get archive_bookshelf_title;
  String get archive_bookshelf_subtitle;
  String archive_books_count(int count);
  String archive_date_full(int month, int day, String wd);
  String get archive_weekday_sun;
  String get archive_weekday_mon;
  String get archive_weekday_tue;
  String get archive_weekday_wed;
  String get archive_weekday_thu;
  String get archive_weekday_fri;
  String get archive_weekday_sat;
  String get archive_ch_02_log;
  String archive_visited_count(int count);
  String get archive_no_attractions;
  String get archive_todays_missions;
  String get archive_earned_badges;
  String get archive_ch_03_memory;
  String get archive_explore_success;
  String get archive_photo_gallery;
  String get archive_photo_camera;
  String get archive_photo_replace;
  String get archive_photo_delete;
  String get archive_stat_collected;
  String get archive_stat_photo_attached;
  String get archive_stat_record_period;
  String get archive_book_count_unit;
  String get archive_hint;
  String get archive_close_label;
  String get notif_set_marketing_gate_hint;
  String archive_events_books_count(int events, int books);
  String archive_season_range_label(String season, String range);
  String get archive_next_event_placeholder;
  String get archive_stat_event_chapters;
  String archive_event_books_badge(int count);
  String get archive_search_title;
  String get archive_search_hint;
  String get archive_search_empty;
  String get archive_add_book_title;
  String get archive_add_book_headline_label;
  String get archive_add_book_headline_hint;
  String get archive_add_book_event_label;
  String get archive_add_book_save;
  String get archive_add_book_coming_soon;
  // 옵션 D: 어트랙션 zone 영문화 (이름은 한국어 유지).
  String get zone_adventure;
  String get zone_future;
  String get zone_samcheonri;
  String get zone_world_plaza;
  String get zone_character_town;
  // 오늘의 이벤트 태그 (홈 하단 카드).
  String get event_tag_dday;
  String get event_tag_popular;
  String get event_tag_new;
  String get event_tag_night;
  String get event_tag_weekend;
  String get event_tag_family;
  String time_pm(String hourMin);
  String time_am(String hourMin);

  String get fav_thrill;
  String get fav_family;
  String get fav_either;
  String get purpose_rides;
  String get purpose_picnic;
  String get purpose_kids_outing;
  String get purpose_date;

  String get common_indoor;
  String get common_outdoor;
  String get common_easter_egg;
  String get common_quantity;
  String get common_subtotal;
  String get common_total_payment;
  String get common_refresh;
  String get common_discovered;
  String get common_traveling;
  String get common_just_now;
  String get common_view_consent;
  String get common_view_terms;

  String attr_walk_eta(int min);
  String get attr_story_title;
  String get attr_story_listen;
  String get attr_story_replay;
  String get attr_view_next_route;
  String get attr_go_here;

  String get map_no_attractions_match;

  String get notif_today_title;
  String get notif_today_8am;
  String get notif_today_1330;
  String get notif_route_updated;
  String get notif_route_detail;
  String get notif_parade_soon;
  String get notif_parade_detail;
  String get notif_egg_nearby;
  String get notif_pricing_today;
  String get notif_pricing_reason;
  String get notif_visit_recommend;
  String get notif_cloudy_calm;

  String get companion_change_title;
  String get companion_members;
  String get companion_preferred_style;
  String get companion_solo;
  String get companion_couple;
  String get companion_friend;
  String get companion_family;
  String get style_thrill;
  String get style_show;
  String get style_photo;
  String get style_relax;

  String get checkout_special_ticket;
  String get checkout_pass_1day;
  String get checkout_luna_discount;
  String get checkout_how_pay;
  String get checkout_credit_card;
  String get checkout_kakao_pay;
  String get checkout_naver_pay;
  String get checkout_bank_transfer;
  String get checkout_start_my_luna;
  String get checkout_payment_done;
  String get checkout_show_qr;
  String get checkout_discount_expired;
  String get checkout_discount_expired_msg;

  String get notif_set_title;
  String get notif_set_service;
  String get notif_set_app_push;
  String get notif_set_calm_alert;
  String get notif_set_calm_desc;
  String get notif_set_marketing;
  String get notif_set_marketing_desc;
  String get notif_set_channels;
  String get notif_set_app_push_short;
  String get notif_set_kakao;
  String notif_set_last_consent(String date);

  String get marketing_title;
  String get marketing_collected;
  String get marketing_received;
  String get marketing_time;
  String get marketing_time_value;
  String get marketing_optout;
  String get marketing_optout_msg;
  String get marketing_legal;
  String get marketing_optout_note;
  String get marketing_agree;
  String get marketing_disagree;

  String get app_info_title;
  String get app_info_service;
  String get app_info_service_desc;
  String get app_info_version;
  String get app_info_dev;
  String get app_info_dev_team;
  String get app_info_oss_license;
  String get app_info_oss_coming;

  String get location_title;
  String get location_purpose;
  String get location_terms_view;
  String get location_terms_coming;
  String get location_open_settings;

  String get search_no_results;
  String get search_hint_all;
  String get no_survey_default;
  String get no_facility_match;

  String get demo_payment_prompt;
  String get demo_family_title;
  String get demo_family_sub;
  String get demo_date_title;
  String get demo_date_sub;
  String get demo_thrill_title;
  String get demo_thrill_sub;

  String get mypage_stat_visits;
  String get mypage_stat_eggs;
  String get mypage_stat_avg_route;
  String get mypage_guest;
  String get mypage_egg_progress;

  String get map_btn_route;
  String get map_btn_gps;

  String survey_headcount(int n);

  String myluna_locked(String label);
  String myluna_lock_label_min_sec(int min, String sec);
  String myluna_lock_label_sec(int sec);
  String get myluna_lock_expired;
  String get myluna_refresh_now;

  String get location_os_granted;
  String get location_os_denied;
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
