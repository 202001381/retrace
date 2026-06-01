import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

enum PipTint { sky, sun, mint, blush, ink }

class _PipStyle {
  final Color bg, fg;
  const _PipStyle(this.bg, this.fg);
}

const Map<PipTint, _PipStyle> _kPipPalette = {
  PipTint.sky:   _PipStyle(AppColors.bgSky, AppColors.blueDeep),
  PipTint.sun:   _PipStyle(AppColors.yellowTint, Color(0xFF8A6300)),
  PipTint.mint:  _PipStyle(AppColors.mintTint, Color(0xFF1E7754)),
  PipTint.blush: _PipStyle(AppColors.blushTint, Color(0xFFB5395A)),
  PipTint.ink:   _PipStyle(AppColors.ink100, AppColors.ink700),
};

/// 컨디션 칩 — 날씨/혼잡도/대기 표시용 작고 둥근 텍스트 pill.
class ConditionPip extends StatelessWidget {
  final IconData icon;
  final String label;
  final PipTint tint;
  const ConditionPip({
    super.key,
    required this.icon,
    required this.label,
    this.tint = PipTint.sky,
  });

  @override
  Widget build(BuildContext context) {
    final s = _kPipPalette[tint]!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: s.bg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: s.fg),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: s.fg,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// 작은 상태 도트 (여유/보통/혼잡) + 라벨.
class StatusDotChip extends StatelessWidget {
  final String label;
  final Color color;
  const StatusDotChip({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.2),
                blurRadius: 0,
                spreadRadius: 3,
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// "EYEBROW" — 작은 UPPERCASE 라벨 (10–11px).
class Eyebrow extends StatelessWidget {
  final String text;
  final Color? color;
  final double size;
  const Eyebrow(this.text, {super.key, this.color, this.size = 10});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: color ?? AppColors.ink500,
        fontSize: size,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.6,
        height: 1.0,
      ),
    );
  }
}
