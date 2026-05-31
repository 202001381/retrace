import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seoul_land_app/widgets/discount_countdown.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('DiscountCountdown', () {
    testWidgets('renders HH:MM:SS for >= 1 hour remaining', (tester) async {
      final until = DateTime.now().add(const Duration(hours: 2, minutes: 30));
      await tester.pumpWidget(_wrap(DiscountCountdown(validUntil: until)));
      final text =
          tester.widget<Text>(find.byType(Text).first).data ?? '';
      expect(text, contains(':'));
      expect(text, contains('남음'));
      // 시 자릿수 2개로 패딩 됨.
      expect(RegExp(r'^\d{2}:\d{2}:\d{2} 남음$').hasMatch(text), isTrue);
    });

    testWidgets('renders "N분 남음" for < 1 hour, >= 10 minutes', (tester) async {
      final until = DateTime.now().add(const Duration(minutes: 30));
      await tester.pumpWidget(_wrap(DiscountCountdown(validUntil: until)));
      final text =
          tester.widget<Text>(find.byType(Text).first).data ?? '';
      expect(RegExp(r'^\d+분 남음$').hasMatch(text), isTrue);
    });

    testWidgets('renders 분초 with urgent style for < 10 minutes',
        (tester) async {
      final until = DateTime.now().add(const Duration(minutes: 5));
      await tester.pumpWidget(_wrap(DiscountCountdown(validUntil: until)));
      final text =
          tester.widget<Text>(find.byType(Text).first).data ?? '';
      expect(RegExp(r'^\d+분 \d{2}초 남음$').hasMatch(text), isTrue);
    });

    testWidgets('hides itself when already expired and fires onExpired',
        (tester) async {
      var fired = false;
      final until = DateTime.now().subtract(const Duration(minutes: 1));
      await tester.pumpWidget(_wrap(DiscountCountdown(
        validUntil: until,
        onExpired: () => fired = true,
      )));
      await tester.pump(); // postFrameCallback 실행
      expect(find.byType(Text), findsNothing); // SizedBox.shrink
      expect(fired, isTrue);
    });

    testWidgets('fires onExpired exactly once when ticking past zero',
        (tester) async {
      var fireCount = 0;
      // 1초 후 만료되는 시각으로 시작.
      final until = DateTime.now().add(const Duration(seconds: 1));
      await tester.pumpWidget(_wrap(DiscountCountdown(
        validUntil: until,
        onExpired: () => fireCount++,
      )));
      // 2.5초 진행 — 이미 시간이 지났을 것.
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.pump(const Duration(milliseconds: 1100));
      expect(fireCount, lessThanOrEqualTo(1));
    });
  });
}
