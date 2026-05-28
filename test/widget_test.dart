// 앱 부팅 스모크 테스트 — Counter 보일러플레이트(이 앱은 카운터 앱이 아님)를
// 대체해, MaterialApp 이 예외 없이 첫 프레임을 그리는지만 확인한다.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seoul_land_app/main.dart';

void main() {
  testWidgets('app boots without throwing on first frame',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const SeoulLandApp());
    // 비동기 onboarding 로딩 + Firebase init catch — 단일 pump 로 첫 프레임 확보.
    await tester.pump();
    // 예외 없으면 통과.
    expect(tester.takeException(), isNull);
  });
}
