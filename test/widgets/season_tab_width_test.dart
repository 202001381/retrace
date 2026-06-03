import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seoul_land_app/l10n/generated/app_localizations.dart';
import 'package:seoul_land_app/screens/archive_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Archive 시즌 4개 탭이 모두 동일 너비로 렌더된다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844)); // iPhone 14
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // ArchiveScreen 은 SharedPreferences 기반 _PhotoStore.load() 후 _ready=true
    // 로 전환된다. 테스트 환경에선 default mock 으로 SharedPreferences 초기값을
    // 주입해야 즉시 settle 한다.
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      const MaterialApp(
        // 한국어 라벨('봄','여름'...) 을 검색하므로 ko 로케일 강제.
        locale: Locale('ko'),
        localizationsDelegates: [
          AppL10n.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: [Locale('ko'), Locale('en')],
        home: Scaffold(body: ArchiveScreen()),
      ),
    );
    // 비동기 await(_PhotoStore.load) → setState 까지 끌어옴.
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // 4개 시즌 라벨이 같은 Row 안의 4개 Expanded 자식에 들어있어야 함.
    final labels = ['봄', '여름', '가을', '겨울'];
    final widths = <double>[];
    for (final l in labels) {
      final finder = find.text(l).first;
      expect(finder, findsOneWidget,
          reason: '$l 라벨이 화면에 보여야 함');
      // 라벨의 가장 가까운 부모 GestureDetector 의 렌더 박스 크기 측정.
      final detector = find
          .ancestor(of: finder, matching: find.byType(GestureDetector))
          .first;
      final box = tester.renderObject<RenderBox>(detector);
      widths.add(box.size.width);
    }

    // 모든 너비가 ±0.5px 이내로 동일해야 함 (소수점 반올림 여유).
    final ref = widths.first;
    for (var i = 1; i < widths.length; i++) {
      expect((widths[i] - ref).abs(), lessThanOrEqualTo(0.5),
          reason: '${labels[i]} (${widths[i]}) vs ${labels[0]} ($ref) 너비 차이');
    }
  });
}
