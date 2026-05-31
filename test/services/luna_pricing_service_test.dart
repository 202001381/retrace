import 'package:flutter_test/flutter_test.dart';
import 'package:seoul_land_app/models/pricing_state.dart';
import 'package:seoul_land_app/services/luna_pricing_service.dart';

void main() {
  group('LunaPricingService.kakaoMessageText', () {
    final state = PricingState(
      basePrice: 35000,
      discountAmount: 5250,
      discountPercent: 15,
      reason: DiscountReason.weather,
      validUntil: DateTime(2026, 5, 26, 22, 0),
    );
    final text = LunaPricingService.instance.kakaoMessageText(state);

    test('includes brand header', () {
      expect(text, contains('[루나 프라이싱]'));
    });

    test('includes reason emoji and label', () {
      expect(text, contains('🌥'));
      expect(text, contains('흐려서 한산'));
    });

    test('includes discount percentage', () {
      expect(text, contains('15%'));
    });

    test('includes base price and final price with thousand separators', () {
      expect(text, contains('₩35,000'));
      expect(text, contains('₩29,750'));
    });

    test('includes validity time', () {
      // "오늘 22:00 까지" 형식.
      expect(text, contains('22:00'));
    });
  });

  group('LunaPricingService.current', () {
    test('returns a non-null state with sensible numbers', () async {
      final s = await LunaPricingService.instance.current();
      expect(s.basePrice, greaterThan(0));
      expect(s.discountAmount, lessThan(s.basePrice));
      expect(s.discountPercent, inInclusiveRange(0, 25));
      expect(s.finalPrice, s.basePrice - s.discountAmount);
      expect(s.validUntil.isAfter(DateTime.now()), isTrue);
    });
  });
}
