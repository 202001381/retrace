import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/main.dart';

void main() {
  testWidgets('SeoullandApp 스모크 — 하단 네비 3탭 렌더링', (tester) async {
    await tester.pumpWidget(const SeoullandApp());
    // DashboardScreen 의 HTTP 호출은 백그라운드에서 계속 시도되므로
    // pumpAndSettle 을 쓰면 hang. 첫 프레임만 그리고 검증한다.
    await tester.pump();

    expect(find.text('대시보드'), findsOneWidget);
    expect(find.text('추천'), findsOneWidget);
    expect(find.text('스토리'), findsOneWidget);
  });
}
