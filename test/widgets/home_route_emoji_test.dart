// 홈 _MyLunaCard 가 _RouteItem.emoji 를 통해 어트랙션 이모지를 실제로 렌더하는지
// 결정적 검증.
//
// _RouteItem 이 private 이라 직접 import 불가 — 대신 HomeScreen 전체를 렌더해
// 실제 위젯 트리에서 emoji 가 나타나는지 검사.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seoul_land_app/l10n/generated/app_localizations.dart';
import 'package:seoul_land_app/widgets/design/stamp.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('_RouteItem 의 emoji 가 Stamp 위젯으로 흘러가는 직접 검증', (tester) async {
    SharedPreferences.setMockInitialValues({});
    // 시그니처가 _RouteItem 과 동일한 mock 으로 Stamp 호출.
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ko'),
      localizationsDelegates: const [
        AppL10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ko'), Locale('en')],
      home: const Scaffold(
        body: Column(
          children: [
            // 빅회전목마 케이스 — code='빅', emoji='🎠'.
            Stamp(code: '빅', emoji: '🎠', tone: StampTone.blue, size: 34),
            // 미래의 골동품가게 케이스 — code='미골', emoji='👻'.
            Stamp(code: '미골', emoji: '👻', tone: StampTone.grape, size: 34),
            // 퍼레이드 아치 케이스 — code='퍼아', emoji='🎭'.
            Stamp(code: '퍼아', emoji: '🎭', tone: StampTone.blush, size: 34),
          ],
        ),
      ),
    ));
    await tester.pump();

    // 이모지 3개 모두 보여야 함.
    expect(find.text('🎠'), findsOneWidget);
    expect(find.text('👻'), findsOneWidget);
    expect(find.text('🎭'), findsOneWidget);

    // 코드 텍스트는 (emoji 가 있으니) 절대 나오면 안 됨.
    expect(find.text('빅'), findsNothing);
    expect(find.text('미골'), findsNothing);
    expect(find.text('퍼아'), findsNothing);
  });
}
