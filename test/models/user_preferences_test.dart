import 'package:flutter_test/flutter_test.dart';
import 'package:seoul_land_app/models/user_preferences.dart';

void main() {
  group('UserPreferences', () {
    test('defaults are all OFF (opt-in 원칙)', () {
      final d = UserPreferences.defaults;
      expect(d.appPushEnabled, isFalse);
      expect(d.lowCrowdAlertEnabled, isFalse);
      expect(d.lowCrowdChannels, isEmpty);
      expect(d.marketingConsent, isFalse);
      expect(d.marketingConsentAt, isNull);
      expect(d.locationTrackingEnabled, isFalse);
    });

    test('canUseKakaoOrSms is equivalent to marketingConsent', () {
      expect(UserPreferences.defaults.canUseKakaoOrSms, isFalse);
      final consented = UserPreferences.defaults
          .copyWith(marketingConsent: true, marketingConsentAt: DateTime.now());
      expect(consented.canUseKakaoOrSms, isTrue);
    });

    test('withoutAdChannels removes kakao and sms but keeps appPush', () {
      final p = UserPreferences.defaults.copyWith(
        lowCrowdChannels: {
          AlertChannel.appPush,
          AlertChannel.kakao,
          AlertChannel.sms,
        },
      );
      final cleaned = p.withoutAdChannels();
      expect(cleaned.lowCrowdChannels, {AlertChannel.appPush});
    });

    test('copyWith clearMarketingConsentAt sets timestamp to null', () {
      final at = DateTime(2026, 5, 26);
      final p = UserPreferences.defaults
          .copyWith(marketingConsent: true, marketingConsentAt: at);
      final cleared = p.copyWith(clearMarketingConsentAt: true);
      expect(cleared.marketingConsentAt, isNull);
    });

    test('toMap/fromMap round-trip preserves all fields', () {
      final at = DateTime.utc(2026, 5, 26, 10, 30);
      final p = UserPreferences(
        appPushEnabled: true,
        lowCrowdAlertEnabled: true,
        lowCrowdChannels: {AlertChannel.appPush, AlertChannel.kakao},
        marketingConsent: true,
        marketingConsentAt: at,
        locationTrackingEnabled: true,
      );
      final restored = UserPreferences.fromMap(p.toMap());
      expect(restored, equals(p));
    });

    test('fromMap of null returns defaults', () {
      expect(UserPreferences.fromMap(null), equals(UserPreferences.defaults));
    });

    test('fromMap ignores unknown channel keys gracefully', () {
      final restored = UserPreferences.fromMap({
        'app_push_enabled': true,
        'low_crowd_alert_enabled': true,
        'low_crowd_channels': ['app_push', 'unknown_channel', 'sms'],
        'marketing_consent': false,
        'marketing_consent_at': null,
        'location_tracking_enabled': false,
      });
      expect(restored.lowCrowdChannels,
          {AlertChannel.appPush, AlertChannel.sms});
    });

    test('AlertChannel.fromKey maps known keys, returns null otherwise', () {
      expect(AlertChannel.fromKey('app_push'), AlertChannel.appPush);
      expect(AlertChannel.fromKey('kakao'), AlertChannel.kakao);
      expect(AlertChannel.fromKey('sms'), AlertChannel.sms);
      expect(AlertChannel.fromKey('nope'), isNull);
    });

    test('equality uses unordered set comparison for channels', () {
      final a = UserPreferences.defaults.copyWith(
        lowCrowdChannels: {AlertChannel.kakao, AlertChannel.sms},
      );
      final b = UserPreferences.defaults.copyWith(
        lowCrowdChannels: {AlertChannel.sms, AlertChannel.kakao},
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });
}
