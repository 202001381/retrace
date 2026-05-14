import 'package:shared_preferences/shared_preferences.dart';

// ─── 온보딩 종료 시 진입 의도 ──────────────────────────────
enum OnboardingExit {
  home,         // 그냥 홈으로 (skip 포함)
  mapTab,       // 홈 진입 후 MAP 탭 자동 전환
  pricingPopup, // 홈 진입 후 루나 프라이싱 팝업 자동 오픈
}

// ─── 선호 어트랙션 / 방문 목적 라벨 ─────────────────────────
class FavoriteType {
  static const thrill = '스릴 어트랙션 위주';
  static const family = '가족·어린이 위주';
  static const both = '둘 다 괜찮아요';
}

class VisitPurpose {
  static const rides = '놀이기구 즐기기';
  static const picnic = '나들이·피크닉';
  static const kidsOuting = '아이 데리고 나들이';
  static const date = '데이트';
}

// ─── 구성원 카테고리 (7종) ──────────────────────────────────
enum MemberCategory {
  infant,        // 👶 유아 (7세 미만)
  child,         // 🧒 어린이 (8~13세)
  teen,          // 🧑 청소년 (14~19세)
  adultMale,     // 👨 성인 남성 (20~39세)
  adultFemale,   // 👩 성인 여성 (20~39세)
  seniorMale,    // 🧓 중장년 남성 (40세 이상)
  seniorFemale,  // 👵 중장년 여성 (40세 이상)
}

extension MemberCategoryX on MemberCategory {
  String get prefsKey {
    switch (this) {
      case MemberCategory.infant:
        return 'survey_infant';
      case MemberCategory.child:
        return 'survey_child';
      case MemberCategory.teen:
        return 'survey_teen';
      case MemberCategory.adultMale:
        return 'survey_adult_male';
      case MemberCategory.adultFemale:
        return 'survey_adult_female';
      case MemberCategory.seniorMale:
        return 'survey_senior_male';
      case MemberCategory.seniorFemale:
        return 'survey_senior_female';
    }
  }

  String get emoji {
    switch (this) {
      case MemberCategory.infant:
        return '👶';
      case MemberCategory.child:
        return '🧒';
      case MemberCategory.teen:
        return '🧑';
      case MemberCategory.adultMale:
        return '👨';
      case MemberCategory.adultFemale:
        return '👩';
      case MemberCategory.seniorMale:
        return '🧓';
      case MemberCategory.seniorFemale:
        return '👵';
    }
  }

  String get label {
    switch (this) {
      case MemberCategory.infant:
        return '유아';
      case MemberCategory.child:
        return '어린이';
      case MemberCategory.teen:
        return '청소년';
      case MemberCategory.adultMale:
        return '성인 남성';
      case MemberCategory.adultFemale:
        return '성인 여성';
      case MemberCategory.seniorMale:
        return '중장년 남성';
      case MemberCategory.seniorFemale:
        return '중장년 여성';
    }
  }

  String get ageRange {
    switch (this) {
      case MemberCategory.infant:
        return '7세 미만';
      case MemberCategory.child:
        return '8~13세';
      case MemberCategory.teen:
        return '14~19세';
      case MemberCategory.adultMale:
      case MemberCategory.adultFemale:
        return '20~39세';
      case MemberCategory.seniorMale:
      case MemberCategory.seniorFemale:
        return '40세 이상';
    }
  }
}

// ─── 응답 데이터 ────────────────────────────────────────────
class SurveyAnswers {
  final Map<MemberCategory, int> members;
  final String? favoriteType;
  final String? purpose;

  const SurveyAnswers({
    required this.members,
    required this.favoriteType,
    required this.purpose,
  });

  int count(MemberCategory c) => members[c] ?? 0;
  int get total => members.values.fold(0, (a, b) => a + b);

  bool get hasInfant => count(MemberCategory.infant) > 0;
  bool get hasChild => count(MemberCategory.child) > 0;
  bool get hasTeenOrAdult =>
      count(MemberCategory.teen) +
          count(MemberCategory.adultMale) +
          count(MemberCategory.adultFemale) >
      0;
  bool get hasSenior =>
      count(MemberCategory.seniorMale) + count(MemberCategory.seniorFemale) > 0;
}

// ─── shared_preferences 래퍼 ────────────────────────────────
class OnboardingService {
  static const _kOnboardingCompleted = 'onboarding_completed';
  static const _kSurveyCompleted = 'survey_completed';
  static const _kFavoriteType = 'survey_favorite_type';
  static const _kPurpose = 'survey_purpose';
  static const _kResultLabel = 'survey_result_label';
  static const _kTotalMembers = 'survey_total_members';

  /// 온보딩(인트로 + 설문 또는 스킵)을 본 적 없으면 true.
  static Future<bool> needsOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_kOnboardingCompleted) ?? false);
  }

  /// 설문까지 완료했는지.
  static Future<bool> isSurveyCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kSurveyCompleted) ?? false;
  }

  /// 인트로만 본 케이스 (skip). 설문 답변은 저장하지 않음.
  static Future<void> markSkipped() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnboardingCompleted, true);
    await prefs.setBool(_kSurveyCompleted, false);
  }

  static Future<void> save(
    SurveyAnswers a, {
    String? resultLabel,
    int? totalMembers,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    for (final c in MemberCategory.values) {
      await prefs.setInt(c.prefsKey, a.count(c));
    }
    if (a.favoriteType != null) await prefs.setString(_kFavoriteType, a.favoriteType!);
    if (a.purpose != null) await prefs.setString(_kPurpose, a.purpose!);
    if (resultLabel != null) await prefs.setString(_kResultLabel, resultLabel);
    if (totalMembers != null) await prefs.setInt(_kTotalMembers, totalMembers);
    await prefs.setBool(_kOnboardingCompleted, true);
    await prefs.setBool(_kSurveyCompleted, true);
  }

  static Future<String?> resultLabel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kResultLabel);
  }

  static Future<SurveyAnswers?> read() async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(_kSurveyCompleted) ?? false)) return null;
    return SurveyAnswers(
      members: {
        for (final c in MemberCategory.values) c: prefs.getInt(c.prefsKey) ?? 0,
      },
      favoriteType: prefs.getString(_kFavoriteType),
      purpose: prefs.getString(_kPurpose),
    );
  }

  /// 개발/테스트용 — 온보딩 전체 초기화.
  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kOnboardingCompleted);
    await prefs.remove(_kSurveyCompleted);
    await prefs.remove(_kFavoriteType);
    await prefs.remove(_kPurpose);
    await prefs.remove(_kResultLabel);
    await prefs.remove(_kTotalMembers);
    for (final c in MemberCategory.values) {
      await prefs.remove(c.prefsKey);
    }
  }
}
