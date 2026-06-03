import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seoul_land_app/l10n/generated/app_localizations.dart';
import 'package:seoul_land_app/models/user_preferences.dart';
import 'package:seoul_land_app/screens/mypage/notification_settings_screen.dart';
import 'package:seoul_land_app/services/preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 한국어 라벨 검증 — ko 로케일 강제 + AppL10n 델리게이트.
Widget _appWith(Widget child) => MaterialApp(
      locale: const Locale('ko'),
      localizationsDelegates: const [
        AppL10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ko'), Locale('en')],
      home: child,
    );

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService.instance.reset();
  });

  testWidgets(
    '카카오·SMS 채널은 마케팅 동의 OFF 상태에서 비활성',
    (tester) async {
      // 한산 알림 ON + 마케팅 OFF 상태로 시작.
      await PreferencesService.instance.update(
        UserPreferences.defaults.copyWith(lowCrowdAlertEnabled: true),
      );

      await tester.pumpWidget(_appWith(const NotificationSettingsScreen()));
      await tester.pumpAndSettle();

      // 카카오 / SMS 라벨이 보이고, 마케팅 OFF 라 onChanged 가 null (비활성).
      expect(find.text('카카오 알림톡'), findsOneWidget);
      expect(find.text('SMS'), findsOneWidget);

      final checkboxes =
          tester.widgetList<Checkbox>(find.byType(Checkbox)).toList();
      // 앱푸시 / 카카오 / SMS 3개.
      expect(checkboxes.length, 3);
      // 카카오·SMS (index 1, 2) 는 비활성 (onChanged == null).
      expect(checkboxes[1].onChanged, isNull);
      expect(checkboxes[2].onChanged, isNull);
      // 앱푸시는 활성.
      expect(checkboxes[0].onChanged, isNotNull);

      // 안내 텍스트 노출.
      expect(
        find.textContaining('마케팅 정보 수신 동의 후 사용'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    '마케팅 OFF 시 lowCrowdChannels 에서 kakao/sms 가 자동 제거됨',
    (tester) async {
      // 마케팅 ON + 모든 채널 체크된 상태로 시작.
      await PreferencesService.instance.update(
        UserPreferences.defaults.copyWith(
          lowCrowdAlertEnabled: true,
          lowCrowdChannels: {
            AlertChannel.appPush,
            AlertChannel.kakao,
            AlertChannel.sms,
          },
          marketingConsent: true,
          marketingConsentAt: DateTime(2026, 5, 26),
        ),
      );

      await tester.pumpWidget(_appWith(const NotificationSettingsScreen()));
      await tester.pumpAndSettle();

      // 마케팅 토글이 켜져 있는 상태에서 OFF 로 전환.
      final switches = find.byType(Switch);
      // 0: 앱푸시 / 1: 한산 / 2: 마케팅
      await tester.tap(switches.at(2));
      await tester.pumpAndSettle();

      final after = PreferencesService.instance.current;
      expect(after.marketingConsent, isFalse);
      expect(after.lowCrowdChannels.contains(AlertChannel.kakao), isFalse);
      expect(after.lowCrowdChannels.contains(AlertChannel.sms), isFalse);
      // 앱푸시는 보존.
      expect(after.lowCrowdChannels.contains(AlertChannel.appPush), isTrue);
    },
  );

  testWidgets(
    '한산 알림 OFF 상태에서는 채널 선택 영역 자체가 숨겨짐',
    (tester) async {
      await tester.pumpWidget(_appWith(const NotificationSettingsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('카카오 알림톡'), findsNothing);
      expect(find.text('SMS'), findsNothing);
      expect(find.text('발송 채널 (중복 선택)'), findsNothing);
    },
  );
}
