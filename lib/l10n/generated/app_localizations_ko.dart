import 'app_localizations.dart';

class AppL10nKo extends AppL10n {
  AppL10nKo() : super('ko');

  @override String get appName => 'Re-Trace';

  @override String get navHome => '홈';
  @override String get navMap => '지도';
  @override String get navMyLuna => '마이 루나';
  @override String get navArchive => 'Archive';
  @override String get navMyPage => '마이';

  @override String get common_ok => '확인';
  @override String get common_cancel => '취소';
  @override String get common_close => '닫기';
  @override String get common_retry => '다시 시도';
  @override String get common_loading => '불러오는 중...';
  @override String get common_error => '문제가 생겼어요';
  @override String get common_save => '저장';
  @override String get common_done => '완료';
  @override String get common_next => '다음';
  @override String get common_back => '이전';
  @override String get common_min_short => '분';
  @override String get common_meter_short => 'm';
  @override String get common_kilometer_short => 'km';

  @override String get home_greeting_morning => '좋은 아침이에요';
  @override String get home_greeting_afternoon => '오늘 하루도 좋아요';
  @override String get home_greeting_evening => '오늘 마무리 잘 해요';
  @override String get home_search_hint => '어트랙션·음식 검색';
  @override String get home_notifications => '알림';
  @override String get home_today_route => '오늘의 추천 동선';
  @override String get home_view_all_route => '전체 동선 보기';
  @override String get home_view_more => '더 보기';
  @override String get home_weather_title => '오늘 날씨';
  @override String get home_crowd_title => '혼잡도';
  @override String get home_crowd_low => '여유';
  @override String get home_crowd_mid => '보통';
  @override String get home_crowd_high => '혼잡';

  @override String get map_route_on => '마이 루나 동선';
  @override String get map_gps_label => '내 위치';
  @override String get map_gps_remote_snackbar => '서울랜드 도착 전이에요 — 정문 기준으로 안내해요 📍';
  @override String get map_ai_scan => 'AI 스캔';
  @override String get map_filter_all => '전체';
  @override String get map_filter_attraction => '어트랙션';
  @override String get map_filter_food => '음식';
  @override String get map_filter_photo => '포토';
  @override String get map_search_hint => '장소 검색';

  @override String get myluna_title => '마이 루나';
  @override String get myluna_subtitle => '오늘의 맞춤 동선';
  @override String get myluna_refresh => '새로고침';
  @override String get myluna_skip => '건너뛰기';
  @override String get myluna_start_now => '지금 출발';
  @override String get myluna_empty_title => '조건을 바꿔보세요';
  @override String get myluna_empty_subtitle => '동행·취향을 바꾸면 새 코스를 보여드려요';
  @override String get myluna_change_profile => '프로필 변경';
  @override String get myluna_loading_route => '최적 동선 계산 중...';
  @override String myluna_walking_minutes(int min) => '$min분';
  @override String myluna_total_time(int min) => '총 $min분';

  @override String get archive_title => '기억의 책장';
  @override String get archive_season_spring => '봄';
  @override String get archive_season_summer => '여름';
  @override String get archive_season_autumn => '가을';
  @override String get archive_season_winter => '겨울';
  @override String get archive_empty_slot => '아직 비어 있어요';
  @override String archive_book_collected(int count, int total) => '$count/$total 수집';

  @override String get mypage_title => '마이';
  @override String get mypage_section_profile => '프로필';
  @override String get mypage_section_preferences => '환경설정';
  @override String get mypage_section_legal => '이용 정보';
  @override String get mypage_section_app => '앱 정보';
  @override String get mypage_language => '언어';
  @override String get mypage_language_korean => '한국어';
  @override String get mypage_language_english => 'English';
  @override String get mypage_language_system => '시스템 설정';
  @override String get mypage_notification => '알림 설정';
  @override String get mypage_location => '위치 설정';
  @override String get mypage_marketing_consent => '마케팅 정보 수신';
  @override String get mypage_reset_onboarding => '온보딩 다시 보기';
  @override String get mypage_app_version => '앱 버전';
  @override String get mypage_app_info => '앱 정보';
  @override String get mypage_terms => '이용약관';
  @override String get mypage_privacy => '개인정보 처리방침';

  @override String get onboarding_welcome_title => '함께 만드는\n나의 서울랜드';
  @override String get onboarding_welcome_subtitle => '동행과 취향을 알려주시면\n오늘 하루를 더 알차게 짜드려요';
  @override String get onboarding_start => '시작하기';
  @override String get onboarding_companion_title => '누구와 함께 오셨어요?';
  @override String get onboarding_purpose_title => '오늘 무엇을 하고 싶으세요?';
  @override String get onboarding_favorite_title => '어떤 걸 더 좋아하세요?';
  @override String get onboarding_done_title => '준비 완료!';

  @override String get error_network => '네트워크 연결을 확인해주세요';
  @override String get error_unknown => '알 수 없는 오류가 발생했어요';
  @override String get error_load_failed => '불러오지 못했어요';
}
