import 'package:shared_preferences/shared_preferences.dart';

enum CompanionType { solo, couple, friends, family }
enum ChildAge { none, under7, age7to13 }
enum VisitPurpose { thrill, familyFriendly, both }

extension CompanionTypeX on CompanionType {
  String get key {
    switch (this) {
      case CompanionType.solo:
        return 'solo';
      case CompanionType.couple:
        return 'couple';
      case CompanionType.friends:
        return 'friends';
      case CompanionType.family:
        return 'family';
    }
  }

  String get label {
    switch (this) {
      case CompanionType.solo:
        return '혼자';
      case CompanionType.couple:
        return '커플';
      case CompanionType.friends:
        return '친구';
      case CompanionType.family:
        return '가족';
    }
  }

  String get emoji {
    switch (this) {
      case CompanionType.solo:
        return '🙋';
      case CompanionType.couple:
        return '💑';
      case CompanionType.friends:
        return '👫';
      case CompanionType.family:
        return '👨‍👩‍👧';
    }
  }
}

extension ChildAgeX on ChildAge {
  String get key {
    switch (this) {
      case ChildAge.none:
        return 'none';
      case ChildAge.under7:
        return 'under7';
      case ChildAge.age7to13:
        return 'age7to13';
    }
  }

  String get label {
    switch (this) {
      case ChildAge.none:
        return '없음';
      case ChildAge.under7:
        return '7세 미만';
      case ChildAge.age7to13:
        return '7~13세';
    }
  }
}

extension VisitPurposeX on VisitPurpose {
  String get key {
    switch (this) {
      case VisitPurpose.thrill:
        return 'thrill';
      case VisitPurpose.familyFriendly:
        return 'family_friendly';
      case VisitPurpose.both:
        return 'both';
    }
  }

  String get label {
    switch (this) {
      case VisitPurpose.thrill:
        return '스릴 어트랙션';
      case VisitPurpose.familyFriendly:
        return '가족형';
      case VisitPurpose.both:
        return '둘 다';
    }
  }
}

class OnboardingAnswers {
  final CompanionType companion;
  final ChildAge childAge;
  final VisitPurpose purpose;
  const OnboardingAnswers({
    required this.companion,
    required this.childAge,
    required this.purpose,
  });
}

class OnboardingService {
  static const _kIsFirstLaunch = 'is_first_launch';
  static const _kCompanion = 'onboarding_companion';
  static const _kChildAge = 'onboarding_child_age';
  static const _kPurpose = 'onboarding_purpose';

  /// 최초 실행 여부. 키가 없으면 true (= 온보딩 필요).
  static Future<bool> isFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kIsFirstLaunch) ?? true;
  }

  static Future<void> saveAnswers(OnboardingAnswers a) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCompanion, a.companion.key);
    await prefs.setString(_kChildAge, a.childAge.key);
    await prefs.setString(_kPurpose, a.purpose.key);
    await prefs.setBool(_kIsFirstLaunch, false);
  }

  static Future<OnboardingAnswers?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final c = prefs.getString(_kCompanion);
    final age = prefs.getString(_kChildAge);
    final p = prefs.getString(_kPurpose);
    if (c == null || age == null || p == null) return null;
    return OnboardingAnswers(
      companion: CompanionType.values.firstWhere((e) => e.key == c, orElse: () => CompanionType.family),
      childAge: ChildAge.values.firstWhere((e) => e.key == age, orElse: () => ChildAge.none),
      purpose: VisitPurpose.values.firstWhere((e) => e.key == p, orElse: () => VisitPurpose.both),
    );
  }

  /// 개발/테스트용 — 온보딩 다시 보기.
  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kIsFirstLaunch);
    await prefs.remove(_kCompanion);
    await prefs.remove(_kChildAge);
    await prefs.remove(_kPurpose);
  }
}
