import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Re·Trace 워드마크 — Pretendard 800, "Re"만 레드, 가운데 점은 40% opacity.
class RetraceLogo extends StatelessWidget {
  final double size;
  final bool dark;
  final bool showBeta;
  final bool showSub;

  const RetraceLogo({
    super.key,
    this.size = 22,
    this.dark = false,
    this.showBeta = true,
    this.showSub = false,
  });

  @override
  Widget build(BuildContext context) {
    final ink = dark ? Colors.white : AppColors.ink900;
    final sub = dark ? Colors.white.withValues(alpha: 0.55) : AppColors.ink500;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showSub)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              '서울랜드 · SEOULLAND',
              style: TextStyle(
                color: sub,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
              ),
            ),
          ),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text.rich(
              TextSpan(
                style: TextStyle(
                  fontSize: size,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -size * 0.035,
                  height: 1.0,
                  color: ink,
                ),
                children: [
                  const TextSpan(text: 'Re', style: TextStyle(color: AppColors.red)),
                  TextSpan(
                    text: ' · ',
                    style: TextStyle(color: ink.withValues(alpha: 0.4)),
                  ),
                  const TextSpan(text: 'Trace'),
                ],
              ),
            ),
            if (showBeta) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.redTint,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'BETA',
                  style: TextStyle(
                    fontSize: size * 0.34,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                    color: AppColors.red,
                    height: 1.0,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// 작은 초승달 마크 — 마이 루나 브랜드 글리프.
class MoonMark extends StatelessWidget {
  final double size;
  final Color color;
  final bool filled;
  const MoonMark({
    super.key,
    this.size = 22,
    this.color = AppColors.blue,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    // Path.combine 의 가용성 차이를 피하기 위해 Icon으로 폴백.
    // 디자인적으로 동일한 초승달 글리프 (Material Icons.nightlight_round).
    return Icon(
      filled ? Icons.nightlight_round : Icons.nightlight_outlined,
      size: size,
      color: color,
    );
  }
}

