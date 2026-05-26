/// 루나 프라이싱의 단일 진실 데이터 모델. 백엔드 XGBoost 응답이 결국 이 형태로
/// 들어오도록 contract 설계.
enum DiscountReason {
  weather('🌥', '흐려서 한산'),
  weekday('📅', '평일 비수기'),
  lowDemand('📉', '오늘 한산'),
  event('🎉', '이벤트 특가');

  final String defaultEmoji;
  final String defaultLabel;
  const DiscountReason(this.defaultEmoji, this.defaultLabel);
}

class PricingState {
  final int basePrice;
  final int discountAmount;
  final int discountPercent;
  final DiscountReason reason;
  final DateTime validUntil;

  const PricingState({
    required this.basePrice,
    required this.discountAmount,
    required this.discountPercent,
    required this.reason,
    required this.validUntil,
  });

  int get finalPrice => basePrice - discountAmount;
  String get reasonEmoji => reason.defaultEmoji;
  String get reasonLabel => reason.defaultLabel;

  /// 만료 여부. now 미지정 시 DateTime.now() 사용.
  bool isExpired([DateTime? now]) =>
      (now ?? DateTime.now()).isAfter(validUntil);

  /// 남은 시간. 만료 후엔 Duration.zero.
  Duration remaining([DateTime? now]) {
    final d = validUntil.difference(now ?? DateTime.now());
    return d.isNegative ? Duration.zero : d;
  }
}
