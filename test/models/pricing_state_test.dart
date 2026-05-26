import 'package:flutter_test/flutter_test.dart';
import 'package:seoul_land_app/models/pricing_state.dart';

void main() {
  group('PricingState', () {
    final fixed = DateTime(2026, 5, 26, 12, 0);

    PricingState make({DateTime? validUntil}) => PricingState(
          basePrice: 35000,
          discountAmount: 5250,
          discountPercent: 15,
          reason: DiscountReason.weather,
          validUntil: validUntil ?? fixed.add(const Duration(hours: 4)),
        );

    test('finalPrice = basePrice - discountAmount', () {
      expect(make().finalPrice, 29750);
    });

    test('reason exposes default emoji and label', () {
      final s = make();
      expect(s.reasonEmoji, '🌥');
      expect(s.reasonLabel, '흐려서 한산');
    });

    test('isExpired is false before validUntil', () {
      final s = make(validUntil: fixed.add(const Duration(seconds: 1)));
      expect(s.isExpired(fixed), isFalse);
    });

    test('isExpired is true after validUntil', () {
      final s = make(validUntil: fixed.subtract(const Duration(seconds: 1)));
      expect(s.isExpired(fixed), isTrue);
    });

    test('isExpired is false exactly at validUntil', () {
      // 정확히 validUntil 시점은 아직 만료 아님 (isAfter 는 strict).
      final s = make(validUntil: fixed);
      expect(s.isExpired(fixed), isFalse);
    });

    test('remaining is positive before expiry', () {
      final s = make(validUntil: fixed.add(const Duration(minutes: 30)));
      expect(s.remaining(fixed), const Duration(minutes: 30));
    });

    test('remaining is zero (not negative) after expiry', () {
      final s = make(validUntil: fixed.subtract(const Duration(hours: 1)));
      expect(s.remaining(fixed), Duration.zero);
    });
  });

  group('DiscountReason', () {
    test('all reasons have distinct emojis and labels', () {
      final emojis = DiscountReason.values.map((r) => r.defaultEmoji).toSet();
      final labels = DiscountReason.values.map((r) => r.defaultLabel).toSet();
      expect(emojis.length, DiscountReason.values.length);
      expect(labels.length, DiscountReason.values.length);
    });
  });
}
