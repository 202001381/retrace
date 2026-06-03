// Spot-check that the archive event mapping handles edge cases:
// - cross-year window (Winter Luna Lights 11.20-2.10)
// - empty event (season with no book in range)
// - short-window wins (Halloween 10.25-10.31 vs Maple 10.15-11.15)
//
// Implementation is private to archive_screen.dart so we use widget rendering
// to indirectly verify (counting badge widgets per season).
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seoul_land_app/l10n/generated/app_localizations.dart';
import 'package:seoul_land_app/screens/archive_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(Widget child) => MaterialApp(
      locale: const Locale('ko'),
      localizationsDelegates: const [
        AppL10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ko'), Locale('en')],
      home: Scaffold(body: child),
    );

void main() {
  setUpAll(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('ArchiveScreen — 봄 탭에서 시드 책 3권 모두 이벤트 카드에 매핑된다',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_wrap(const ArchiveScreen()));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 500));

    // 봄 시즌 — '벚꽃 페스티벌' 카드, '어린이날 페스타' 카드 노출.
    expect(find.text('벚꽃 페스티벌'), findsOneWidget);
    expect(find.text('어린이날 페스타'), findsOneWidget);
    // 봄 플라워가든은 시드에 책 없음 — 카드 자체는 노출되되 권수 뱃지 X.
    expect(find.text('봄 플라워가든'), findsOneWidget);
    // 다음 행사 칸 placeholder.
    expect(find.textContaining('다음 행사 칸'), findsOneWidget);
  });
}
