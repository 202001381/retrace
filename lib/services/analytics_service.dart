import 'package:flutter/foundation.dart';

/// 화면 진입·이벤트·스크롤 깊이 등을 기록하는 얇은 stub.
/// 추후 Firebase Analytics / Amplitude 등으로 교체 시 동일 인터페이스 유지.
class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  void logEvent(String name, [Map<String, Object?> props = const {}]) {
    debugPrint('[analytics] $name $props');
  }

  void logScreenView(String screen) =>
      logEvent('screen_view', {'screen': screen});

  /// depth 는 0.0~1.0. 호출 측에서 임계 도달 시점에만 호출하도록 디바운스.
  void logScrollDepth(String screen, double depth) => logEvent(
        'scroll_depth',
        {'screen': screen, 'depth': depth},
      );
}
