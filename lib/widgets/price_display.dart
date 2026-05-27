import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

import '../models/pricing_state.dart';

enum PriceDisplaySize { compact, hero }

/// 정가·할인가·할인율을 한 컴포넌트로 일관 표시. 모든 가격 노출 위치에서 동일하게 사용.
/// 표시광고법 권고를 따라 정가/할인가/최종가 모두 보임.
class PriceDisplay extends StatelessWidget {
  final PricingState state;
  final PriceDisplaySize size;
  final Color accentColor;
  const PriceDisplay({
    super.key,
    required this.state,
    this.size = PriceDisplaySize.compact,
    this.accentColor = AppColors.brandCoral,
  });

  static String _fmt(int n) => n.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );

  @override
  Widget build(BuildContext context) {
    switch (size) {
      case PriceDisplaySize.compact:
        return _compact();
      case PriceDisplaySize.hero:
        return _hero();
    }
  }

  Widget _compact() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text('정가 ₩${_fmt(state.basePrice)}',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.lineThrough,
            )),
        const SizedBox(width: 6),
        const Icon(Icons.arrow_forward_rounded,
            size: 12, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Text('₩${_fmt(state.finalPrice)}',
            style: TextStyle(
              color: accentColor,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            )),
        const SizedBox(width: 6),
        _DiscountChip(percent: state.discountPercent, color: accentColor),
      ],
    );
  }

  Widget _hero() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('정가 ₩${_fmt(state.basePrice)}',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.lineThrough,
            )),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text('₩${_fmt(state.finalPrice)}',
                style: TextStyle(
                  color: accentColor,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  height: 1,
                )),
            const SizedBox(width: 10),
            _DiscountChip(percent: state.discountPercent, color: accentColor),
          ],
        ),
      ],
    );
  }
}

class _DiscountChip extends StatelessWidget {
  final int percent;
  final Color color;
  const _DiscountChip({required this.percent, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '-$percent%',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
