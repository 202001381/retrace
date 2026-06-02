import 'package:flutter/material.dart';

/// Re-Trace 디자인 시스템 라인 글리프 — design_handoff_retrace/ds-primitives.jsx
/// 의 SVG path 들을 그대로 CustomPainter 로 옮긴 것. Material Icons 대신 사용해
/// 디자인의 얇은 stroke (1.6) 룩을 유지.
///
/// 사용:
///   RetraceGlyph(name: 'bell', size: 16, color: AppColors.blueDeep)
///
/// 지원 이름: refresh, bell, pin, card, scroll, info, sparkle, egg,
///   language, chevron, clock, walk, gps, search, check, plus, cloud
///   (필요 시 _paint 에 case 추가)
class RetraceGlyph extends StatelessWidget {
  final String name;
  final double size;
  final Color color;
  final double strokeWidth;

  const RetraceGlyph({
    super.key,
    required this.name,
    this.size = 20,
    this.color = const Color(0xFF1F1F1F),
    this.strokeWidth = 1.6,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GlyphPainter(
          name: name,
          color: color,
          strokeWidth: strokeWidth,
        ),
      ),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  final String name;
  final Color color;
  final double strokeWidth;

  _GlyphPainter({
    required this.name,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 디자인의 viewBox 가 24x24 — 우리 size 에 맞춰 스케일.
    final scale = size.width / 24.0;
    canvas.save();
    canvas.scale(scale, scale);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (name) {
      case 'refresh':
        // M4 12a8 8 0 0 1 14-5.3  + M20 12a8 8 0 0 1-14 5.3  + M18 3v4h-4  + M6 21v-4h4
        final p = Path()
          ..moveTo(4, 12)
          ..arcToPoint(const Offset(18, 6.7),
              radius: const Radius.circular(8), clockwise: true);
        canvas.drawPath(p, paint);
        final p2 = Path()
          ..moveTo(20, 12)
          ..arcToPoint(const Offset(6, 17.3),
              radius: const Radius.circular(8), clockwise: true);
        canvas.drawPath(p2, paint);
        canvas.drawPath(
            Path()
              ..moveTo(18, 3)
              ..lineTo(18, 7)
              ..lineTo(14, 7),
            paint);
        canvas.drawPath(
            Path()
              ..moveTo(6, 21)
              ..lineTo(6, 17)
              ..lineTo(10, 17),
            paint);
        break;

      case 'bell':
        // M6 16h12l-1.5-2V11a4.5 4.5 0 1 0-9 0v3L6 16Z + clapper
        final body = Path()
          ..moveTo(6, 16)
          ..lineTo(18, 16)
          ..lineTo(16.5, 14)
          ..lineTo(16.5, 11)
          ..arcToPoint(const Offset(7.5, 11),
              radius: const Radius.circular(4.5), clockwise: false)
          ..lineTo(7.5, 14)
          ..close();
        canvas.drawPath(body, paint);
        canvas.drawPath(
            Path()
              ..moveTo(10, 19)
              ..arcToPoint(const Offset(14, 19),
                  radius: const Radius.circular(2), clockwise: false),
            paint);
        break;

      case 'pin':
        // M12 21s7-7 7-12a7 7 0 1 0-14 0c0 5 7 12 7 12Z + circle r=2.5
        final outer = Path()
          ..moveTo(12, 21)
          ..cubicTo(12, 21, 19, 14, 19, 9)
          ..arcToPoint(const Offset(5, 9),
              radius: const Radius.circular(7), clockwise: false)
          ..cubicTo(5, 14, 12, 21, 12, 21)
          ..close();
        canvas.drawPath(outer, paint);
        canvas.drawCircle(const Offset(12, 9), 2.5, paint);
        break;

      case 'card':
        // rect(x=3,y=6,w=18,h=13,rx=2) + M3 10h18
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                const Rect.fromLTWH(3, 6, 18, 13), const Radius.circular(2)),
            paint);
        canvas.drawLine(const Offset(3, 10), const Offset(21, 10), paint);
        break;

      case 'scroll':
        // M5 5h12v14H7a2 2 0 0 1-2-2V5Z + M17 5a2 2 0 0 1 2 2v2h-4
        final scroll = Path()
          ..moveTo(5, 5)
          ..lineTo(17, 5)
          ..lineTo(17, 19)
          ..lineTo(7, 19)
          ..arcToPoint(const Offset(5, 17),
              radius: const Radius.circular(2), clockwise: true)
          ..close();
        canvas.drawPath(scroll, paint);
        canvas.drawPath(
            Path()
              ..moveTo(17, 5)
              ..arcToPoint(const Offset(19, 7),
                  radius: const Radius.circular(2), clockwise: true)
              ..lineTo(19, 9)
              ..lineTo(15, 9),
            paint);
        break;

      case 'info':
        canvas.drawCircle(const Offset(12, 12), 8.5, paint);
        canvas.drawLine(const Offset(12, 10), const Offset(12, 16), paint);
        // 점 (i 의 dot) — 짧은 stroke
        canvas.drawLine(const Offset(12, 7.5), const Offset(12, 8), paint);
        break;

      case 'sparkle':
        // 십자 + 대각선
        canvas.drawLine(const Offset(12, 4), const Offset(12, 10), paint);
        canvas.drawLine(const Offset(12, 14), const Offset(12, 20), paint);
        canvas.drawLine(const Offset(4, 12), const Offset(10, 12), paint);
        canvas.drawLine(const Offset(14, 12), const Offset(20, 12), paint);
        canvas.drawLine(const Offset(7, 7), const Offset(10, 10), paint);
        canvas.drawLine(const Offset(14, 14), const Offset(17, 17), paint);
        canvas.drawLine(const Offset(17, 7), const Offset(14, 10), paint);
        canvas.drawLine(const Offset(10, 14), const Offset(7, 17), paint);
        break;

      case 'egg':
        final egg = Path()
          ..moveTo(12, 3)
          ..cubicTo(16, 3, 19, 8, 19, 13)
          ..arcToPoint(const Offset(5, 13),
              radius: const Radius.circular(7), clockwise: false)
          ..cubicTo(5, 8, 8, 3, 12, 3)
          ..close();
        canvas.drawPath(egg, paint);
        break;

      case 'language':
        // globe — 원 + 위경도 곡선
        canvas.drawCircle(const Offset(12, 12), 8.5, paint);
        canvas.drawLine(const Offset(3.5, 12), const Offset(20.5, 12), paint);
        // 세로 타원 (적도 곡선)
        canvas.drawOval(
            const Rect.fromLTWH(8.5, 3.5, 7, 17), paint);
        break;

      case 'chevron':
        canvas.drawPath(
            Path()
              ..moveTo(9, 6)
              ..lineTo(15, 12)
              ..lineTo(9, 18),
            paint);
        break;

      case 'clock':
        canvas.drawCircle(const Offset(12, 12), 8.5, paint);
        canvas.drawPath(
            Path()
              ..moveTo(12, 7.5)
              ..lineTo(12, 12)
              ..lineTo(15, 14),
            paint);
        break;

      case 'check':
        canvas.drawPath(
            Path()
              ..moveTo(5, 12)
              ..lineTo(9.5, 16.5)
              ..lineTo(19, 7.5),
            paint);
        break;

      case 'plus':
        canvas.drawLine(const Offset(12, 5), const Offset(12, 19), paint);
        canvas.drawLine(const Offset(5, 12), const Offset(19, 12), paint);
        break;

      case 'walk':
        canvas.drawCircle(const Offset(13, 4.5), 1.7, paint);
        canvas.drawPath(
            Path()
              ..moveTo(10, 21)
              ..lineTo(12.5, 15)
              ..lineTo(15, 18)
              ..lineTo(18, 16),
            paint);
        canvas.drawPath(
            Path()
              ..moveTo(7, 13)
              ..lineTo(10, 9)
              ..lineTo(13, 12)
              ..lineTo(13, 15),
            paint);
        break;

      case 'gps':
        canvas.drawCircle(const Offset(12, 12), 3, paint);
        canvas.drawCircle(const Offset(12, 12), 8, paint);
        canvas.drawLine(const Offset(12, 2), const Offset(12, 5), paint);
        canvas.drawLine(const Offset(12, 19), const Offset(12, 22), paint);
        canvas.drawLine(const Offset(2, 12), const Offset(5, 12), paint);
        canvas.drawLine(const Offset(19, 12), const Offset(22, 12), paint);
        break;

      case 'search':
        canvas.drawCircle(const Offset(11, 11), 6.5, paint);
        canvas.drawLine(const Offset(16, 16), const Offset(20.5, 20.5), paint);
        break;

      default:
        // 미정의 이름 — 빈 박스 (디버그 용).
        break;
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      old.name != name || old.color != color || old.strokeWidth != strokeWidth;
}
