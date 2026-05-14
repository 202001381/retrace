import 'package:shared_preferences/shared_preferences.dart';

// ─── 선택지 상수 (Firestore/UI 모두 동일 문자열 사용) ─────────
class AgeGroups {
  static const under7 = '7세 미만';
  static const age8to13 = '8~13세';
  static const age14to19 = '14~19세';
  static const age20to39 = '20~39세';
  static const age40plus = '40세 이상';
  static const all = [under7, age8to13, age14to19, age20to39, age40plus];
}

class Gender {
  static const male = '남성';
  static const female = '여성';
  static const undisclosed = '선택 안 함';
  static const all = [male, female, undisclosed];
}

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

// ─── 설문 응답 데이터 클래스 ──────────────────────────────────
class SurveyAnswers {
  final int headcount;
  final List<String> ageGroups;
  final String gender;
  final String favoriteType;
  final String purpose;

  const SurveyAnswers({
    required this.headcount,
    required this.ageGroups,
    required this.gender,
    required this.favoriteType,
    required this.purpose,
  });

  /// 아이 동반(7세 미만 또는 8~13세) 여부.
  bool get hasChild =>
      ageGroups.contains(AgeGroups.under7) || ageGroups.contains(AgeGroups.age8to13);

  /// 키 제한 어트랙션 필터링이 필요한지 (7세 미만 동반 시).
  bool get filterHeightLimited => ageGroups.contains(AgeGroups.under7);
}

// ─── shared_preferences 래퍼 ────────────────────────────────
class OnboardingService {
  static const _kCompleted = 'survey_completed';
  static const _kHeadcount = 'survey_headcount';
  static const _kAgeGroups = 'survey_age_groups';
  static const _kGender = 'survey_gender';
  static const _kFavoriteType = 'survey_favorite_type';
  static const _kPurpose = 'survey_purpose';

  /// 설문 미완료 시 true (= 온보딩 다시 보여줘야 함).
  static Future<bool> needsSurvey() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_kCompleted) ?? false);
  }

  static Future<void> save(SurveyAnswers a) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kHeadcount, a.headcount);
    await prefs.setStringList(_kAgeGroups, a.ageGroups);
    await prefs.setString(_kGender, a.gender);
    await prefs.setString(_kFavoriteType, a.favoriteType);
    await prefs.setString(_kPurpose, a.purpose);
    await prefs.setBool(_kCompleted, true);
  }

  static Future<SurveyAnswers?> read() async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(_kCompleted) ?? false)) return null;
    return SurveyAnswers(
      headcount: prefs.getInt(_kHeadcount) ?? 2,
      ageGroups: prefs.getStringList(_kAgeGroups) ?? const [],
      gender: prefs.getString(_kGender) ?? Gender.undisclosed,
      favoriteType: prefs.getString(_kFavoriteType) ?? FavoriteType.both,
      purpose: prefs.getString(_kPurpose) ?? VisitPurpose.rides,
    );
  }

  /// 개발/테스트용 — 설문 다시 보기.
  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kCompleted);
    await prefs.remove(_kHeadcount);
    await prefs.remove(_kAgeGroups);
    await prefs.remove(_kGender);
    await prefs.remove(_kFavoriteType);
    await prefs.remove(_kPurpose);
  }
}
