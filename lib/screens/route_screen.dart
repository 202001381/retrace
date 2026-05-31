import 'package:flutter/material.dart';
import '../widgets/spot_detail_sheet.dart';
import '../models/spot_model.dart';
import 'package:latlong2/latlong.dart';

class RouteScreen extends StatefulWidget {
  final String companion;
  final String companionEmoji;
  final String preference;
  const RouteScreen({
    super.key,
    this.companion = '가족',
    this.companionEmoji = '👨‍👩‍👧',
    this.preference = '스릴·액티비티',
  });

  @override
  State<RouteScreen> createState() => _RouteScreenState();
}

class _RouteStop {
  final int order;
  final String name, emoji, category, zone, duration;
  final int waitMin;
  final bool hasEasterEgg;
  const _RouteStop({
    required this.order,
    required this.name,
    required this.emoji,
    required this.category,
    required this.zone,
    required this.waitMin,
    required this.duration,
    this.hasEasterEgg = false,
  });
}

class _RouteScreenState extends State<RouteScreen> {
  static const _stops = <_RouteStop>[
    _RouteStop(order: 1, name: '급류타기', emoji: '🌊', category: '어트랙션', zone: '어드벤처존', waitMin: 15, duration: '10분'),
    _RouteStop(order: 2, name: '킹바이킹', emoji: '⛵', category: '어트랙션', zone: '스릴존', waitMin: 5, duration: '8분', hasEasterEgg: true),
    _RouteStop(order: 3, name: '레드락 푸드코트', emoji: '🍔', category: '음식점', zone: '센터광장', waitMin: 0, duration: '30분'),
    _RouteStop(order: 4, name: '범퍼카', emoji: '🚗', category: '어트랙션', zone: '패밀리존', waitMin: 10, duration: '5분'),
  ];

  static const _total = '3시간 15분';

  Color _categoryColor(String c) {
    switch (c) {
      case '음식점':
        return const Color(0xFFFF6D00);
      case '포토존':
        return const Color(0xFF8E24AA);
      default:
        return const Color(0xFFE60012);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header
            Container(
              color: const Color(0xFF1E3158),
              padding: const EdgeInsets.fromLTRB(16, 12, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.maybePop(context),
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${widget.companionEmoji} ${widget.companion} 맞춤 동선 추천',
                                style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
                            Text(widget.preference,
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Wrap(
                      spacing: 8,
                      children: [
                        _HeaderChip(text: '🗺️ ${_stops.length}개 스팟'),
                        _HeaderChip(text: '⏱️ $_total'),
                        _HeaderChip(text: '🎯 AI 최적 동선'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Simplified map visualization
            Container(
              height: 220,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFEFF6FF), Color(0xFFECFDF5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border(bottom: BorderSide(color: Colors.white, width: 2)),
              ),
              child: CustomPaint(
                painter: _RouteMapPainter(stops: _stops, getColor: _categoryColor),
                child: const SizedBox.expand(),
              ),
            ),

            // List
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: _stops.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) => _StopRow(stop: _stops[i], categoryColor: _categoryColor, onTap: () => _openDetail(_stops[i])),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openDetail(_RouteStop s) {
    // Try matching to a real Spot from SeoulLandSpots for the detail sheet
    final spot = SeoulLandSpots.all.firstWhere(
      (x) => x.name == s.name,
      orElse: () => Spot(
        id: 'tmp-${s.order}',
        name: s.name,
        nameEn: s.name,
        position: const LatLng(37.4279, 127.0247),
        category: s.category == '음식점' ? SpotCategory.food : s.category == '포토존' ? SpotCategory.photo : SpotCategory.attraction,
        themes: const [],
        icon: s.emoji,
        description: '${s.zone} • ${s.duration}',
        rating: 4.5,
        reviewCount: 100,
        waitTime: s.waitMin > 0 ? '${s.waitMin}분' : null,
        hasEasterEgg: s.hasEasterEgg,
        zone: s.zone,
        visitDurationMin: 20,
      ),
    );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SpotDetailSheet(spot: spot),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  final String text;
  const _HeaderChip({required this.text});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
    );
  }
}

class _RouteMapPainter extends CustomPainter {
  final List<_RouteStop> stops;
  final Color Function(String) getColor;
  _RouteMapPainter({required this.stops, required this.getColor});

  @override
  void paint(Canvas canvas, Size size) {
    final spacing = size.width / (stops.length + 1);
    final y = size.height / 2;
    final centers = List<Offset>.generate(stops.length, (i) => Offset(spacing * (i + 1), y));

    // dashed line
    final linePaint = Paint()
      ..color = const Color(0xFFE60012).withValues(alpha: 0.7)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke;

    for (var i = 0; i < centers.length - 1; i++) {
      _drawDashedLine(canvas, centers[i], centers[i + 1], linePaint);
    }

    // markers
    for (var i = 0; i < stops.length; i++) {
      final c = centers[i];
      final color = getColor(stops[i].category);

      // label above
      final tp = TextPainter(
        text: TextSpan(text: stops[i].name, style: const TextStyle(color: Color(0xFF1F1F1F), fontSize: 11, fontWeight: FontWeight.w800)),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: spacing - 6);
      tp.paint(canvas, Offset(c.dx - tp.width / 2, c.dy - 50));

      // circle
      canvas.drawCircle(c, 20, Paint()..color = color.withValues(alpha: 0.9));

      // number
      final order = TextPainter(
        text: TextSpan(text: '${stops[i].order}', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
        textDirection: TextDirection.ltr,
      )..layout();
      order.paint(canvas, Offset(c.dx - order.width / 2, c.dy - order.height / 2));
    }
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dash = 8.0, gap = 4.0;
    final delta = end - start;
    final distance = delta.distance;
    final direction = delta / distance;
    double drawn = 0;
    while (drawn < distance) {
      final next = drawn + dash;
      final segEnd = next > distance ? end : start + direction * next;
      canvas.drawLine(start + direction * drawn, segEnd, paint);
      drawn = next + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _RouteMapPainter old) => old.stops != stops;
}

class _StopRow extends StatelessWidget {
  final _RouteStop stop;
  final Color Function(String) categoryColor;
  final VoidCallback onTap;
  const _StopRow({required this.stop, required this.categoryColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = categoryColor(stop.category);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEEEEEE)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text('${stop.order}',
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(width: 10),
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              alignment: Alignment.center,
              child: Text(stop.emoji, style: const TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(stop.name,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF1F1F1F))),
                      ),
                      if (stop.hasEasterEgg) const Padding(padding: EdgeInsets.only(left: 4), child: Text('🥚', style: TextStyle(fontSize: 12))),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(stop.category, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w800)),
                      const Text(' • ', style: TextStyle(color: Color(0xFFCCCCCC))),
                      Text(stop.zone, style: const TextStyle(fontSize: 11, color: Color(0xFF888888))),
                      const Text(' • ', style: TextStyle(color: Color(0xFFCCCCCC))),
                      Text('⏱ ${stop.duration}', style: const TextStyle(fontSize: 11, color: Color(0xFF888888))),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF888888), size: 20),
          ],
        ),
      ),
    );
  }
}
