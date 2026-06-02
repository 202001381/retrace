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
  @override String get home_today_events => "Today's events";
  @override String get home_get_ticket => 'Get ticket';
  @override String get home_discount_label => 'Discount';
  @override String get home_card_weather => 'Weather';
  @override String get home_card_crowd => 'Crowd';
  @override String home_card_crowd_current(String level) => 'Current crowd: $level';
  @override String get home_companion_change => 'Change companion';
  @override String get home_view_attractions => 'Browse attractions';

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

  @override String get mypage_title => 'My Page';
  @override String get mypage_section_profile => 'Profile';
  @override String get mypage_section_preferences => 'Preferences';
  @override String get mypage_section_legal => 'Legal';
  @override String get mypage_section_app => 'App';
  @override String get mypage_settings_payment => 'Payment history';
  @override String get mypage_settings_terms => 'Terms & policies';
  @override String get mypage_coming_soon => 'Coming soon';
  @override String get mypage_feedback => 'Send feedback';
  @override String get mypage_replay_onboarding_sub => 'Retake preferences';
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

  @override String get cat_attraction => 'Attractions';
  @override String get cat_food => 'Food';
  @override String get cat_restaurant => 'Restaurant';
  @override String get cat_cafe => 'Cafe';
  @override String get cat_photo => 'Photo';
  @override String get cat_photo_spot => 'Photo Spot';
  @override String get label_thrill => 'Thrill';
  @override String get label_activity => 'Activity';
  @override String get label_family => 'Family';
  @override String get label_date => 'Date';
  @override String get label_thrill_activity => 'Thrill · Activity';

  @override String wait_short(int min) => 'Wait $min min';
  @override String wait_expected(int min) => 'Expected wait $min min';
  @override String get walk_short => 'Walk';
  @override String get wait_label => 'Wait';

  @override String get home_first_visit_welcome => 'Welcome, first visitor';
  @override String get home_today_park_is => 'Today the park is ';
  @override String get home_park_is_chill => 'relaxed.';
  @override String get home_park_is_special => 'on a special deal.';
  @override String get home_park_is_calm => 'calm.';
  @override String get home_today_chill_day => 'A calm day today';
  @override String get home_weather_cloudy_18 => 'Cloudy 18°C';
  @override String get home_weather_detail_today => 'Cloudy today · Low 15°C / High 20°C';
  @override String get home_weather_rain_detail => '60% rain · Gwacheon, Gyeonggi';
  @override String get home_crowd_mid_label => 'Moderate crowd';
  @override String get home_crowd_recommend_morning => 'We recommend visiting after 11 AM';
  @override String get home_drawing_route => 'Drawing your route...';
  @override String get home_route_load_failed => "Couldn't load route";
  @override String get home_retry => 'Retry ↻';
  @override String home_route_total_min(int min) => 'About $min min total';
  @override String get home_change_conditions => 'Change conditions';
  @override String home_uncollected_eggs(int count) => '$count uncollected easter eggs';
  @override String get home_route_preparing => "Preparing today's recommended route 🌙";
  @override String get home_view_full_route => 'View full route →';
  @override String get home_onboarding_answers => 'Onboarding answers';
  @override String get home_view_all => 'View all';

  @override String get myluna_loading_recs => 'Loading recommendations...';
  @override String get myluna_load_failed => "Couldn't load recommendations";
  @override String get myluna_change_conditions => 'Change conditions';
  @override String get myluna_condition => 'Condition';
  @override String get myluna_next => 'Next recommendation';
  @override String get myluna_next_candidate => 'Next candidate';
  @override String get myluna_change_conditions_prompt => 'Want to change conditions?';
  @override String get myluna_skipped_too_many => "You've skipped a lot. Try new conditions for fresh picks.";
  @override String get myluna_get_new_rec => 'Get new recommendation';
  @override String get myluna_sample_preview => 'Preview sample course';
  @override String get myluna_stop_sample => 'Stop preview';
  @override String get myluna_navigate_start => 'Start navigation';
  @override String myluna_total_min(int min) => 'Total $min min';
  @override String myluna_course_count(int count) => 'Course ($count stops)';
  @override String myluna_missing_eggs(int count) => '$count eggs left';

  @override String get map_route_realtime => 'Live sync';
  @override String get map_no_eggs_collected => 'No easter eggs collected yet';
  @override String get map_visit_starred => 'Visit places marked with ✨ on the map';
  @override String get map_filter_reset => 'Reset filter';
  @override String get map_operating_only => 'Operating only';
  @override String get map_no_match => 'No places match';
  @override String map_total_count(int count) => '$count places';
  @override String map_result_count(int count) => '$count results';
  @override String get map_rerecommend => 'Recommend again';

  @override String get onboarding_intro_title => 'Re-Trace Seoul Land.\nWe remember your taste and route\nto suggest a different day every time.';
  @override String get onboarding_make_my_luna => 'Let us ask a few things\nto build your My Luna';
  @override String get onboarding_just_3 => 'Just 3 questions 🙂';
  @override String get onboarding_q_purpose => "What's your\npurpose today?";
  @override String get onboarding_q_favorite => 'Which rides do you\nprefer more?';
  @override String get onboarding_q_party => "Who's with\nyou?";
  @override String get onboarding_pick_accurate => 'Pick as accurately as you can';
  @override String get onboarding_party_count_msg => "We'll tailor the route to your group";
  @override String get onboarding_party_total => 'Total people';
  @override String get onboarding_party_count => 'How many';
  @override String get onboarding_skip => 'Skip';
  @override String get onboarding_browse => 'Browse around';
  @override String get onboarding_for_you => 'A Seoul Land course just for you';
  @override String get onboarding_ready => 'Your My Luna is ready!';
  @override String get onboarding_my_luna_what => 'What is My Luna?';
  @override String get onboarding_luna_pricing_what => 'What is Luna Pricing?';
  @override String get onboarding_proactive_notif => 'Proactive alerts';
  @override String get onboarding_realtime_discount => 'Real-time discount';
  @override String get onboarding_anytime_new_course => 'A new course anytime';
  @override String get onboarding_pricing_desc => 'Ticket price changes by crowd and weather. Up to 25% off on calm days!';
  @override String get onboarding_notif_desc => 'The night before your visit, Luna tells you if tomorrow looks calm';
  @override String get onboarding_personalized_desc => 'We analyze crowd, weather, and companions to design the perfect route';
  @override String get onboarding_thrill_course => 'Thrill course';
  @override String get onboarding_family_course => 'Family course';
  @override String get onboarding_date_course => 'Date course';
  @override String get onboarding_custom_course => 'Custom course';
  @override String get onboarding_thrill_fast => 'I love fast and exciting rides';
  @override String get onboarding_family_together => 'I love rides we can take together';
  @override String get onboarding_either_ok => 'Depends on the situation';

  @override String get fav_thrill => 'Thrill rides';
  @override String get fav_family => 'Family-friendly';
  @override String get fav_either => 'Either is fine';
  @override String get purpose_rides => 'Enjoy rides';
  @override String get purpose_picnic => 'Picnic';
  @override String get purpose_kids_outing => 'Kids outing';
  @override String get purpose_date => 'Date';

  @override String get common_indoor => 'Indoor';
  @override String get common_outdoor => 'Outdoor';
  @override String get common_easter_egg => 'Easter egg';
  @override String get common_quantity => 'Quantity';
  @override String get common_subtotal => 'Subtotal';
  @override String get common_total_payment => 'Total';
  @override String get common_refresh => 'Refresh';
  @override String get common_discovered => 'Discovered!';
  @override String get common_traveling => 'Heading there...';
  @override String get common_just_now => 'Just now';
  @override String get common_view_consent => 'View consent details';
  @override String get common_view_terms => 'View terms';

  @override String attr_walk_eta(int min) => '$min min walk';
  @override String get attr_story_title => "There's a hidden story here";
  @override String get attr_story_listen => 'Listen to the story';
  @override String get attr_story_replay => 'Listen again';
  @override String get attr_view_next_route => 'View next stop';
  @override String get attr_go_here => 'Take me here';

  @override String get map_no_attractions_match => 'No attractions match';

  @override String get notif_today_title => "Today's notifications";
  @override String get notif_today_8am => 'Today 08:00';
  @override String get notif_today_1330 => 'Today 13:30';
  @override String get notif_route_updated => 'Your My Luna route was updated';
  @override String get notif_route_detail => 'Reshuffled Lavatwister to stop #2 based on wait-time changes.';
  @override String get notif_parade_soon => '2 PM parade starting soon';
  @override String get notif_parade_detail => 'Meet at Central Plaza. Best spots fill up 30 min before.';
  @override String get notif_egg_nearby => 'Someone just found a stamp near the Antique Future Shop. Get closer.';
  @override String get notif_pricing_today => "Today's −15% Luna Pricing";
  @override String get notif_pricing_reason => 'Weekday — relatively calm';
  @override String get notif_visit_recommend => 'We recommend visiting after 11 AM. 8 min shorter waits than weekends.';
  @override String get notif_cloudy_calm => 'Cloudy and calm. Get it for ₩29,750 until 09:53.';

  @override String get companion_change_title => 'Change My Luna conditions';
  @override String get companion_members => 'Members';
  @override String get companion_preferred_style => 'Preferred style';
  @override String get companion_solo => 'Solo';
  @override String get companion_couple => 'Couple';
  @override String get companion_friend => 'Friends';
  @override String get companion_family => 'Family';
  @override String get style_thrill => 'Thrill · Activity';
  @override String get style_show => 'Shows · Parades';
  @override String get style_photo => 'Photo · Selfies';
  @override String get style_relax => 'Relax · Healing';

  @override String get checkout_special_ticket => 'Today only\nLuna ticket';
  @override String get checkout_pass_1day => '1-day pass';
  @override String get checkout_luna_discount => 'Luna discount';
  @override String get checkout_how_pay => 'How would you like to pay?';
  @override String get checkout_credit_card => 'Credit/Debit card';
  @override String get checkout_kakao_pay => 'KakaoPay';
  @override String get checkout_naver_pay => 'NaverPay';
  @override String get checkout_bank_transfer => 'Bank transfer';
  @override String get checkout_start_my_luna => 'Start My Luna';
  @override String get checkout_payment_done => 'Payment complete';
  @override String get checkout_show_qr => 'Show this QR at the gate';
  @override String get checkout_discount_expired => 'Discount expired';
  @override String get checkout_discount_expired_msg => "Today's Luna Pricing window has passed.\nReturning to home.";

  @override String get notif_set_title => 'Notifications';
  @override String get notif_set_service => 'Service notifications';
  @override String get notif_set_app_push => 'App push notifications';
  @override String get notif_set_calm_alert => 'Calm-day alert';
  @override String get notif_set_calm_desc => 'Off-season · calm-weather alerts';
  @override String get notif_set_marketing => 'Marketing consent';
  @override String get notif_set_marketing_desc => 'Discount coupons · event ads';
  @override String get notif_set_channels => 'Delivery channels (multi-select)';
  @override String get notif_set_app_push_short => 'App push';
  @override String get notif_set_kakao => 'KakaoTalk Alert';
  @override String notif_set_last_consent(String date) => 'Last consent: $date';

  @override String get marketing_title => 'Marketing consent';
  @override String get marketing_collected => 'Collected / used';
  @override String get marketing_received => "What you'll receive on consent";
  @override String get marketing_time => 'Send window';
  @override String get marketing_time_value => '8 AM ~ 9 PM';
  @override String get marketing_optout => 'How to opt out';
  @override String get marketing_optout_msg => 'You can opt out anytime in My Page > Notifications.';
  @override String get marketing_legal => 'Legal basis: Act on Promotion of Information and Communications Network Utilization, Article 50';
  @override String get marketing_optout_note => 'Opting out limits features like calm-day alerts.';
  @override String get marketing_agree => 'I agree';
  @override String get marketing_disagree => 'Decline';

  @override String get app_info_title => 'App info';
  @override String get app_info_service => 'Service';
  @override String get app_info_service_desc => 'Seoul Land AI dynamic pricing & route recommendation';
  @override String get app_info_version => 'Version';
  @override String get app_info_dev => 'Developed by';
  @override String get app_info_dev_team => 'HUFS Capstone Team 1';
  @override String get app_info_oss_license => 'Open-source licenses';
  @override String get app_info_oss_coming => 'License page (coming soon)';

  @override String get location_title => 'Location';
  @override String get location_purpose => 'Used for easter egg discovery and route recommendations';
  @override String get location_terms_view => 'View Location Terms';
  @override String get location_terms_coming => 'Location Terms (coming soon)';
  @override String get location_open_settings => 'Open settings';

  @override String get search_no_results => 'No results';
  @override String get search_hint_all => 'Search attractions, food, zones';
  @override String get no_survey_default => 'No survey — default priority';
  @override String get no_facility_match => 'No facility matches the filter.';

  @override String get demo_payment_prompt => 'Pay and your custom course begins';
  @override String get demo_family_title => 'Family 4h';
  @override String get demo_family_sub => 'Kid-friendly, lower thrill';
  @override String get demo_date_title => 'Date 4h';
  @override String get demo_date_sub => 'Photo spots + meals + night view';
  @override String get demo_thrill_title => 'Thrill 4h';
  @override String get demo_thrill_sub => 'Coasters + activities focus';

  @override String get mypage_stat_visits => 'Visits';
  @override String get mypage_stat_eggs => 'Easter eggs';
  @override String get mypage_stat_avg_route => 'Avg route';
  @override String get mypage_guest => 'Guest';
  @override String get mypage_egg_progress => 'Easter egg progress';

  @override String get map_btn_route => 'Route';
  @override String get map_btn_gps => 'GPS';

  @override String survey_headcount(int n) => '$n people';
}
