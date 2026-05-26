import '../models/pricing_state.dart';

/// 루나 프라이싱 데이터 source. 현재는 mock — 백엔드 XGBoost 엔드포인트 붙으면
/// `current()` 내부만 HTTP 로 교체.
class LunaPricingService {
  LunaPricingService._();
  static final LunaPricingService instance = LunaPricingService._();

  /// 현재 시점의 프라이싱 상태. 자정까지 유효한 15% 할인을 mock 반환.
  Future<PricingState> current() async {
    await Future.delayed(const Duration(milliseconds: 120));
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    return PricingState(
      basePrice: 35000,
      discountAmount: 5250,
      discountPercent: 15,
      reason: DiscountReason.weather,
      validUntil: midnight,
    );
  }

  /// 카카오 알림톡 본문 (텍스트 버전). 정통법 정보성 알림 톤.
  /// 호출처는 백엔드 발송 파이프라인에서 사용 — 클라이언트는 헬퍼만 제공.
  String kakaoMessageText(PricingState s) {
    final base = _fmt(s.basePrice);
    final disc = _fmt(s.finalPrice);
    final until = _fmtTime(s.validUntil);
    return '[루나 프라이싱]\n'
        '${s.reasonEmoji} ${s.reasonLabel}\n'
        '\n'
        '오늘 서울랜드 입장권이 ${s.discountPercent}% 할인됩니다.\n'
        '정가 ₩$base → 할인가 ₩$disc\n'
        '\n'
        '⏰ $until 까지 유효\n'
        '🌙 RE-TRACE 앱에서 자세히 보기';
  }

  static String _fmt(int n) => n.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );

  static String _fmtTime(DateTime t) {
    // "오늘 22:00" 또는 "오늘 24:00" 등. 자정은 24:00 표기.
    final isMidnight = t.hour == 0 && t.minute == 0;
    final h = isMidnight ? 24 : t.hour;
    final m = t.minute.toString().padLeft(2, '0');
    return '오늘 $h:$m';
  }
}
