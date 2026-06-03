import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seoul_land_app/widgets/design/stamp.dart';

void main() {
  group('Stamp.emoji', () {
    testWidgets('emoji 가 비어있지 않으면 code 가 아니라 emoji 가 표시된다',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: Stamp(code: '빅', emoji: '🎠', tone: StampTone.blue, size: 34),
        ),
      ));
      expect(find.text('🎠'), findsOneWidget);
      expect(find.text('빅'), findsNothing);
    });

    testWidgets('emoji 가 null 이면 code 텍스트 fallback', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: Stamp(code: '빅', tone: StampTone.blue, size: 34),
        ),
      ));
      expect(find.text('빅'), findsOneWidget);
    });

    testWidgets('emoji 가 빈 문자열이면 code 텍스트 fallback', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: Stamp(code: '빅', emoji: '', tone: StampTone.blue, size: 34),
        ),
      ));
      expect(find.text('빅'), findsOneWidget);
    });
  });
}
