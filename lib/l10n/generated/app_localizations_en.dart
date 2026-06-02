import 'app_localizations.dart';

class AppL10nEn extends AppL10n {
  AppL10nEn() : super('en');

  @override String get appName => 'Re-Trace';

  @override String get navHome => 'Home';
  @override String get navMap => 'Map';
  @override String get navMyLuna => 'My Luna';
  @override String get navArchive => 'Archive';
  @override String get navMyPage => 'Me';

  @override String get common_ok => 'OK';
  @override String get common_cancel => 'Cancel';
  @override String get common_close => 'Close';
  @override String get common_retry => 'Retry';
  @override String get common_loading => 'Loading...';
  @override String get common_error => 'Something went wrong';
  @override String get common_save => 'Save';
  @override String get common_done => 'Done';
  @override String get common_next => 'Next';
  @override String get common_back => 'Back';
  @override String get common_min_short => 'min';
  @override String get common_meter_short => 'm';
  @override String get common_kilometer_short => 'km';

  @override String get home_greeting_morning => 'Good morning';
  @override String get home_greeting_afternoon => 'Have a good day';
  @override String get home_greeting_evening => 'Wind down well';
  @override String get home_search_hint => 'Search attractions & food';
  @override String get home_notifications => 'Notifications';
  @override String get home_today_route => "Today's recommended route";
  @override String get home_view_all_route => 'View full route';
  @override String get home_view_more => 'View more';
  @override String get home_weather_title => 'Weather';
  @override String get home_crowd_title => 'Crowd level';
  @override String get home_crowd_low => 'Light';
  @override String get home_crowd_mid => 'Moderate';
  @override String get home_crowd_high => 'Crowded';

  @override String get map_route_on => 'My Luna Route';
  @override String get map_gps_label => 'My location';
  @override String get map_gps_remote_snackbar => "You're not at Seoul Land yet — using the front gate as origin 📍";
  @override String get map_ai_scan => 'AI Scan';
  @override String get map_filter_all => 'All';
  @override String get map_filter_attraction => 'Rides';
  @override String get map_filter_food => 'Food';
  @override String get map_filter_photo => 'Photo';
  @override String get map_search_hint => 'Search places';

  @override String get myluna_title => 'My Luna';
  @override String get myluna_subtitle => "Today's personalized route";
  @override String get myluna_refresh => 'Refresh';
  @override String get myluna_skip => 'Skip';
  @override String get myluna_start_now => 'Start now';
  @override String get myluna_empty_title => 'Try different settings';
  @override String get myluna_empty_subtitle => 'Change companion or preference to see a new course';
  @override String get myluna_change_profile => 'Change profile';
  @override String get myluna_loading_route => 'Computing the best route...';
  @override String myluna_walking_minutes(int min) => '$min min';
  @override String myluna_total_time(int min) => 'Total $min min';

  @override String get archive_title => 'Memory Shelf';
  @override String get archive_season_spring => 'Spring';
  @override String get archive_season_summer => 'Summer';
  @override String get archive_season_autumn => 'Autumn';
  @override String get archive_season_winter => 'Winter';
  @override String get archive_empty_slot => 'Empty slot';
  @override String archive_book_collected(int count, int total) => '$count/$total collected';

  @override String get mypage_title => 'Me';
  @override String get mypage_section_profile => 'Profile';
  @override String get mypage_section_preferences => 'Preferences';
  @override String get mypage_section_legal => 'Legal';
  @override String get mypage_section_app => 'App';
  @override String get mypage_language => 'Language';
  @override String get mypage_language_korean => '한국어';
  @override String get mypage_language_english => 'English';
  @override String get mypage_language_system => 'System default';
  @override String get mypage_notification => 'Notifications';
  @override String get mypage_location => 'Location';
  @override String get mypage_marketing_consent => 'Marketing consent';
  @override String get mypage_reset_onboarding => 'Replay onboarding';
  @override String get mypage_app_version => 'App version';
  @override String get mypage_app_info => 'App info';
  @override String get mypage_terms => 'Terms of Service';
  @override String get mypage_privacy => 'Privacy Policy';

  @override String get onboarding_welcome_title => 'Your Seoul Land,\ntailored for you';
  @override String get onboarding_welcome_subtitle => "Tell us your companion and preferences\nand we'll plan today better";
  @override String get onboarding_start => 'Get started';
  @override String get onboarding_companion_title => "Who's with you today?";
  @override String get onboarding_purpose_title => 'What would you like to do?';
  @override String get onboarding_favorite_title => 'What do you prefer?';
  @override String get onboarding_done_title => 'All set!';

  @override String get error_network => 'Please check your network';
  @override String get error_unknown => 'An unknown error occurred';
  @override String get error_load_failed => 'Failed to load';
}
