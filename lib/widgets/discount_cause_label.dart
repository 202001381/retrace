import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

import '../models/pricing_state.dart';

/// 할인 인과 라벨 — "🌥 흐려서 한산 → 15% 할인" 한 줄.
/// 모든 할인 표시 위치에 동반되어야 함 (Wendy's 백래시 교훈: 프레이밍 일관성).
class DiscountCauseLabel extends StatelessWidget {
  final PricingState state;
  final bool dark;       // 진한 배경(네이비) 위에 올릴 때 true
  final double fontSize;

  const DiscountCauseLabel({
    super.key,
    required this.state,
    this.dark = false,
    this.fontSize = 13,
  });

  @override
  Widget build(BuildContext context) {
    final labelColor = dark ? AppColors.textOnDark : AppColors.textPrimary;
    final accentColor = dark ? AppColors.yellow : AppColors.red;
    final arrowColor = AppColors.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(state.reasonEmoji, style: TextStyle(fontSize: fontSize + 3)),
        const SizedBox(width: 4),
        Flexible(
          child: Text(state.reasonLabel,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: labelColor,
                fontSize: fontSize,
                fontWeight: FontWeight.w800,
              )),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Icon(Icons.arrow_forward_rounded,
              size: fontSize + 1, color: arrowColor),
        ),
        Text('${state.discountPercent}% 할인',
            style: TextStyle(
              color: accentColor,
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
            )),
      ],
    );
  }
}
