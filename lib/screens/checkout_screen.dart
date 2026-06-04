import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/pricing_state.dart';
import '../services/visit_history_service.dart';
import '../widgets/design/condition_pip.dart';
import '../widgets/discount_cause_label.dart';
import '../widgets/discount_countdown.dart';

/// v3 ticket purchase — dark BG + perforated ticket card hero + 결제하기 CTA.
/// 결제 성공 시 QR-style 완료 시트로 마무리 (별도 PG 연동은 mock).
class CheckoutScreen extends StatefulWidget {
  final PricingState pricing;
  const CheckoutScreen({super.key, required this.pricing});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  bool _expired = false;
  bool _processing = false;
  int _qty = 1;

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
    final l = AppL10n.of(context);
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l.checkout_expired_title),
        content: Text(l.checkout_discount_expired_msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l.common_ok),
          ),
        ],
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _onPay() async {
    if (_expired || _processing) return;
    // STEP 2 — 결제수단 선택 시트.
    final method = await showModalBottomSheet<_PayMethod>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PaymentMethodSheet(
        baseTotal: widget.pricing.basePrice * _qty,
        discount: widget.pricing.discountAmount * _qty,
        finalTotal: widget.pricing.finalPrice * _qty,
      ),
    );
    if (method == null || !mounted) return;

    setState(() => _processing = true);
    await Future.delayed(const Duration(milliseconds: 700));
    await VisitHistoryService.markVisitedNow();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => _QrSuccessSheet(
        finalAmount: widget.pricing.finalPrice * _qty,
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  void _bump(int delta) {
    setState(() => _qty = (_qty + delta).clamp(1, 9));
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.pricing;
    final total = p.finalPrice * _qty;
    final saved = p.discountAmount * _qty;
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: SafeArea(
        child: Column(
          children: [
            // ── 헤더 ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 18),
                  ),
                  const Spacer(),
                  Container(
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.access_time_rounded,
                            size: 14, color: Colors.white),
                        const SizedBox(width: 4),
                        DiscountCountdown(
                          validUntil: p.validUntil,
                          onExpired: () => setState(() => _expired = true),
                          defaultColor: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 12, 22, 32),
                children: [
                  const Eyebrow('STEP 01 · CONFIRM', color: AppColors.yellow),
                  const SizedBox(height: 8),
                  Text(
                    AppL10n.of(context).checkout_special_ticket,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      height: 1.15,
                      letterSpacing: -1.2,
                    ),
                  ),
                  const SizedBox(height: 28),
                  _PerforatedTicket(
                    pricing: p,
                    qty: _qty,
                    onMinus: _qty > 1 ? () => _bump(-1) : null,
                    onPlus: _qty < 9 ? () => _bump(1) : null,
                  ),
                  const SizedBox(height: 20),
                  // 합계 row
                  _SummaryRow(label: AppL10n.of(context).common_subtotal, value: '₩${_fmt(p.basePrice * _qty)}'),
                  const SizedBox(height: 8),
                  _SummaryRow(
                    label: AppL10n.of(context).checkout_luna_discount_pct(p.discountPercent),
                    value: '-₩${_fmt(saved)}',
                    valueColor: AppColors.yellow,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                  const SizedBox(height: 12),
                  _SummaryRow(
                    label: AppL10n.of(context).common_total_payment,
                    value: '₩${_fmt(total)}',
                    bold: true,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    AppL10n.of(context).checkout_locked_disclaimer,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 11,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            // ── CTA ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: (_expired || _processing) ? null : _onPay,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.red,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        Colors.white.withValues(alpha: 0.18),
                    disabledForegroundColor:
                        Colors.white.withValues(alpha: 0.6),
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(99)),
                  ),
                  child: _processing
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.4, color: Colors.white),
                        )
                      : Text(
                          _expired
                              ? AppL10n.of(context).checkout_discount_expired
                              : AppL10n.of(context).checkout_pay_now(_fmt(total)),
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w900),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 천공(perforated) 티켓 카드 ─────────────────────────────
class _PerforatedTicket extends StatelessWidget {
  final PricingState pricing;
  final int qty;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;
  const _PerforatedTicket({
    required this.pricing,
    required this.qty,
    required this.onMinus,
    required this.onPlus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            // 상단 컬러 strip
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.red, AppColors.redDeep],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'SEOULLAND',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          letterSpacing: 1.8,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.yellow,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '−${pricing.discountPercent}%',
                          style: const TextStyle(
                            color: AppColors.ink900,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    AppL10n.of(context).checkout_pass_1day,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DiscountCauseLabel.reasonLabel(context, pricing),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            // 천공 라인
            const _PerforationLine(),
            // 수량 영역
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
              child: Row(
                children: [
                  Text(
                    AppL10n.of(context).common_quantity,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.ink500,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  _QtyButton(icon: Icons.remove, onTap: onMinus),
                  SizedBox(
                    width: 44,
                    child: Text(
                      '$qty',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppColors.ink900,
                      ),
                    ),
                  ),
                  _QtyButton(icon: Icons.add, onTap: onPlus),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PerforationLine extends StatelessWidget {
  const _PerforationLine();
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 14,
      child: Stack(
        children: [
          Positioned(
            left: -7,
            top: 0,
            bottom: 0,
            child: Container(
              width: 14,
              decoration: const BoxDecoration(
                color: AppColors.bgDeep,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            right: -7,
            top: 0,
            bottom: 0,
            child: Container(
              width: 14,
              decoration: const BoxDecoration(
                color: AppColors.bgDeep,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Center(
            child: CustomPaint(
              size: const Size(double.infinity, 1),
              painter: _DashPainter(),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.ink200
      ..strokeWidth = 1;
    const dash = 4.0, gap = 4.0;
    double x = 12;
    while (x < size.width - 12) {
      canvas.drawLine(Offset(x, 0), Offset(x + dash, 0), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_DashPainter o) => false;
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _QtyButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled ? AppColors.ink900 : AppColors.ink200,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: Colors.white),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;
  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: bold ? 14 : 13,
            color: Colors.white.withValues(alpha: bold ? 0.92 : 0.7),
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: bold ? 22 : 14,
            color: valueColor ?? Colors.white,
            fontWeight: bold ? FontWeight.w900 : FontWeight.w800,
            letterSpacing: bold ? -0.6 : -0.2,
          ),
        ),
      ],
    );
  }
}

// ─── 결제 완료 QR 시트 ───────────────────────────────────────
class _QrSuccessSheet extends StatelessWidget {
  final int finalAmount;
  const _QrSuccessSheet({required this.finalAmount});

  static String _fmt(int n) => n.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
      decoration: const BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: AppColors.ink300,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: 24),
          // 체크 동그라미
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.mintTint,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded,
                size: 32, color: AppColors.mint),
          ),
          const SizedBox(height: 16),
          Text(
            AppL10n.of(context).checkout_payment_done,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: AppColors.ink900,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '₩${_fmt(finalAmount)}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.ink500,
            ),
          ),
          const SizedBox(height: 22),
          // mock QR (격자 패턴)
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.line),
            ),
            child: CustomPaint(painter: _MockQrPainter()),
          ),
          const SizedBox(height: 14),
          Text(
            AppL10n.of(context).checkout_show_qr,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.ink500,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.ink900,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(99)),
              ),
              child: Text(
                AppL10n.of(context).checkout_start_my_luna,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MockQrPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.ink900;
    final cell = size.width / 24;
    // pseudorandom but stable pattern
    final mask = [
      0xFFE000, 0x800020, 0xBE83A0, 0xA28BA0, 0xA28BA0, 0xBE8320,
      0x8000E0, 0xFFFFE0, 0x0F1F00, 0x6E92E0, 0x2A4D60, 0x4F3B00,
      0xFFE000, 0xC65560, 0x4F3B00, 0x6E9220, 0x2A4D40, 0xC65500,
      0x800000, 0xBE83A0, 0xA28BA0, 0xA28BA0, 0xBE8320, 0xFFE000,
    ];
    for (var r = 0; r < 24; r++) {
      for (var c = 0; c < 24; c++) {
        if ((mask[r] >> (23 - c)) & 1 == 1) {
          canvas.drawRect(
              Rect.fromLTWH(c * cell, r * cell, cell, cell), paint);
        }
      }
    }
    // finder squares (corners)
    void finder(double ox, double oy) {
      canvas.drawRect(Rect.fromLTWH(ox, oy, cell * 7, cell * 7), paint);
      final inner = Paint()..color = AppColors.bgCard;
      canvas.drawRect(
          Rect.fromLTWH(ox + cell, oy + cell, cell * 5, cell * 5), inner);
      canvas.drawRect(
          Rect.fromLTWH(
              ox + cell * 2, oy + cell * 2, cell * 3, cell * 3),
          paint);
    }

    finder(0, 0);
    finder(size.width - cell * 7, 0);
    finder(0, size.height - cell * 7);
  }

  @override
  bool shouldRepaint(_MockQrPainter o) => false;
}

// ─── STEP 2 결제수단 선택 시트 ────────────────────────────────
enum _PayMethod { kakao, card, naver, bank }

class _PaymentMethodSheet extends StatefulWidget {
  final int baseTotal;
  final int discount;
  final int finalTotal;
  const _PaymentMethodSheet({
    required this.baseTotal,
    required this.discount,
    required this.finalTotal,
  });

  @override
  State<_PaymentMethodSheet> createState() => _PaymentMethodSheetState();
}

class _PaymentMethodSheetState extends State<_PaymentMethodSheet> {
  _PayMethod _selected = _PayMethod.kakao;

  static String _fmt(int n) => n.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );

  List<(_PayMethod, String, Color, String)> _methodsLocalized(BuildContext context) {
    final l = AppL10n.of(context);
    return [
      (_PayMethod.kakao, l.checkout_kakao_pay, const Color(0xFFFAE100), 'K'),
      (_PayMethod.card,  l.checkout_credit_card, const Color(0xFF1F1F1F), 'CARD'),
      (_PayMethod.naver, l.checkout_naver_pay, const Color(0xFF03C75A), 'N'),
      (_PayMethod.bank,  l.checkout_bank_transfer, const Color(0xFF0084E0), '₩'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: const BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.ink300,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Eyebrow('STEP 02 · PAYMENT', color: AppColors.red),
          const SizedBox(height: 6),
          Text(
            AppL10n.of(context).checkout_how_pay,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: AppColors.ink900,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 18),
          ..._methodsLocalized(context).map((m) {
            final selected = _selected == m.$1;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () => setState(() => _selected = m.$1),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.redTint : AppColors.bgPage,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected ? AppColors.red : AppColors.line,
                      width: selected ? 1.6 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: m.$3,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          m.$4,
                          style: TextStyle(
                            color: m.$3 == const Color(0xFFFAE100)
                                ? AppColors.ink900
                                : Colors.white,
                            fontSize: m.$4.length > 1 ? 10 : 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          m.$2,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink900,
                          ),
                        ),
                      ),
                      Container(
                        width: 22,
                        height: 22,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: selected ? AppColors.red : Colors.transparent,
                          border: Border.all(
                              color: selected
                                  ? AppColors.red
                                  : AppColors.ink300),
                        ),
                        child: selected
                            ? const Icon(Icons.check_rounded,
                                size: 14, color: Colors.white)
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 12),
          // 요약
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.bgPage,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                _summaryRow(AppL10n.of(context).common_subtotal, '₩${_fmt(widget.baseTotal)}'),
                const SizedBox(height: 6),
                _summaryRow(
                  AppL10n.of(context).checkout_luna_discount,
                  '-₩${_fmt(widget.discount)}',
                  valueColor: AppColors.red,
                ),
                const Divider(height: 18, color: AppColors.line),
                _summaryRow(
                  AppL10n.of(context).common_total_payment,
                  '₩${_fmt(widget.finalTotal)}',
                  bold: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(_selected),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.red,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(99)),
              ),
              child: Text(
                AppL10n.of(context).checkout_pay_now(_fmt(widget.finalTotal)),
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value,
      {Color? valueColor, bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: bold ? 14 : 13,
            color: bold ? AppColors.ink900 : AppColors.ink500,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: bold ? 18 : 13,
            color: valueColor ?? AppColors.ink900,
            fontWeight: bold ? FontWeight.w900 : FontWeight.w800,
            letterSpacing: bold ? -0.4 : 0,
          ),
        ),
      ],
    );
  }
}
