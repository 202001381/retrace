import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

import '../models/pricing_state.dart';
import '../services/visit_history_service.dart';
import '../widgets/discount_cause_label.dart';
import '../widgets/discount_countdown.dart';

/// 결제 확인 화면 — 정가·할인·최종 분해 + 카운트다운 + 인과 + 신뢰 메시지.
/// 실제 PG 연동은 별도 작업. 여기선 mock 성공 다이얼로그 후 홈 복귀 + 방문 기록.
class CheckoutScreen extends StatefulWidget {
  final PricingState pricing;
  const CheckoutScreen({super.key, required this.pricing});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  bool _expired = false;
  bool _processing = false;

  static String _fmt(int n) => n.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );

  @override
  void initState() {
    super.initState();
    _expired = widget.pricing.isExpired();
    if (_expired) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showExpiredAndPop());
    }
  }

  Future<void> _showExpiredAndPop() async {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('할인이 만료됐어요'),
        content: const Text('오늘의 루나 프라이싱 유효 시간이 지났습니다.\n홈으로 돌아갑니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _onPay() async {
    if (_expired || _processing) return;
    setState(() => _processing = true);
    // Mock 결제 — 실 PG 연동은 별도 작업.
    await Future.delayed(const Duration(milliseconds: 600));
    await VisitHistoryService.markVisitedNow();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('결제 완료'),
        content: Text(
          '₩${_fmt(widget.pricing.finalPrice)} 결제가 완료되었어요.\n'
          '오늘 좋은 시간 보내세요!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
    if (mounted) Navigator.of(context).pop(); // back to home
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.pricing;
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AppBar(
        title: const Text('결제 확인',
            style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: AppColors.bgSurface,
        elevation: 0.5,
        foregroundColor: AppColors.textPrimary,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.bgSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.bgSunken),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('입장권 (성인 1매)',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                        )),
                    const SizedBox(height: 16),
                    _row('정가', '₩${_fmt(p.basePrice)}',
                        color: AppColors.textSecondary),
                    const SizedBox(height: 8),
                    _row(
                      '루나 할인 (${p.discountPercent}%)',
                      '-₩${_fmt(p.discountAmount)}',
                      color: AppColors.brandCoral,
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1, color: AppColors.bgSunken),
                    const SizedBox(height: 12),
                    _row(
                      '최종 결제액',
                      '₩${_fmt(p.finalPrice)}',
                      color: AppColors.textPrimary,
                      bold: true,
                      large: true,
                    ),
                    const SizedBox(height: 14),
                    DiscountCauseLabel(state: p),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // 유효 시간 카운트다운 — 만료 시 결제 버튼 비활성.
              Row(
                children: [
                  DiscountCountdown(
                    validUntil: p.validUntil,
                    onExpired: () => setState(() => _expired = true),
                    defaultColor: AppColors.textSecondary,
                  ),
                ],
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: (_expired || _processing) ? null : _onPay,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandCoral,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.textSecondary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _processing
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.4, color: Colors.white),
                        )
                      : Text(_expired ? '할인 만료됨' : '💳 결제하기',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w900)),
                ),
              ),
              const SizedBox(height: 12),
              // 신뢰 메시지 — Wendy's 백래시 교훈: 결제 후 가격 변동 영향 없음 명시.
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  '💡 이 할인은 표시된 시간까지 유효해요.\n'
                  '결제 후엔 가격 변동의 영향을 받지 않아요.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value,
      {required Color color, bool bold = false, bool large = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
              fontSize: large ? 15 : 14,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: AppColors.textSecondary,
            )),
        Text(value,
            style: TextStyle(
              fontSize: large ? 20 : 14,
              fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
              color: color,
            )),
      ],
    );
  }

}
