import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;

import '../models/pricing_state.dart';

/// 루나 프라이싱 — 백엔드 `POST /api/discount` 호출, 미설정·실패 시 mock fallback.
///
/// baseUrl 주입: `--dart-define=API_BASE_URL=http://localhost:5000`
/// 빈 문자열이면 mock (15% 자정까지 유효).
class LunaPricingService {
  LunaPricingService._();
  static final LunaPricingService instance = LunaPricingService._();

  static const String _baseUrl = String.fromEnvironment('API_BASE_URL');
  static const bool _useMock = _baseUrl.length == 0;
  static const Duration _timeout = Duration(seconds: 5);
  static const int _basePrice = 35000;

  /// 현재 시점의 프라이싱 상태. 백엔드 응답을 PricingState 로 매핑.
  Future<PricingState> current({
    String crowdLevel = '하',
    double rainProb = 30,
  }) async {
    if (_useMock) return _mockPricing();
    try {
      final pct = await _fetchDiscountPct(crowdLevel, rainProb).timeout(_timeout);
      return _buildState(pct, _reasonForBackend(crowdLevel, rainProb));
    } catch (e, st) {
      developer.log(
        'pricing backend failed, falling back to mock',
        error: e,
        stackTrace: st,
        name: 'LunaPricingService',
      );
      return _mockPricing();
    }
  }

  Future<int> _fetchDiscountPct(String crowdLevel, double rainProb) async {
    final uri = Uri.parse('$_baseUrl/api/discount');
    final resp = await http.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'crowd_level': crowdLevel, 'rain_prob': rainProb}),
    );
    if (resp.statusCode >= 400) {
      throw HttpException('discount api ${resp.statusCode}: ${resp.body}');
    }
    final body = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, Object?>;
    return (body['discount_pct'] as num).toInt();
  }

  PricingState _buildState(int discountPct, DiscountReason reason) {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    final discountAmount = (_basePrice * discountPct / 100).round();
    return PricingState(
      basePrice: _basePrice,
      discountAmount: discountAmount,
      discountPercent: discountPct,
      reason: reason,
      validUntil: midnight,
    );
  }

  /// 백엔드 crowd_level + rain_prob 조합 → 사유 라벨.
  DiscountReason _reasonForBackend(String crowdLevel, double rainProb) {
    if (rainProb >= 50) return DiscountReason.weather;
    if (crowdLevel == '하') return DiscountReason.lowDemand;
    return DiscountReason.weekday;
  }

  PricingState _mockPricing() {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    return PricingState(
      basePrice: _basePrice,
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
    final isMidnight = t.hour == 0 && t.minute == 0;
    final h = isMidnight ? 24 : t.hour;
    final m = t.minute.toString().padLeft(2, '0');
    return '오늘 $h:$m';
  }
}

class HttpException implements Exception {
  final String message;
  const HttpException(this.message);
  @override
  String toString() => 'HttpException: $message';
}
