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
    return CustomPaint(
      size: Size(size, size),
      painter: _MoonPainter(color: color, filled: filled),
    );
  }
}

class _MoonPainter extends CustomPainter {
  final Color color;
  final bool filled;
  _MoonPainter({required this.color, required this.filled});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final path = Path()
      ..moveTo(20 * s, 14.5 * s)
      ..arcToPoint(Offset(9.5 * s, 4 * s),
          radius: Radius.circular(8 * s), clockwise: false)
      ..arcToPoint(Offset(20 * s, 14.5 * s),
          radius: Radius.circular(6.5 * s), clockwise: false)
      ..close();
    final paint = Paint()
      ..color = color
      ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = 1.6 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_MoonPainter o) => o.color != color || o.filled != filled;
}
