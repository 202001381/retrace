import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../widgets/companion_bottom_sheet.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onOpenMyLuna;
  const HomeScreen({super.key, this.onOpenMyLuna});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // ── Mock 시나리오 (API 연동 전 하드코딩) ─────────────────
  static const int _visitScore = 78;
  static const int _discountPct = 15;
  static const bool _isOffPeak = true;
  static const String _routeSummary = '은하열차 888 → 후룸라이드 → 대관람차';

  String _companion = '가족';
  String _style = '스릴·액티비티';

  static const List<_RouteItem> _routeItems = [
    _RouteItem(name: '은하열차 888', emoji: '🎢', type: '스릴', waitMin: 15, crowd: '보통', crowdColor: Color(0xFFFFC107)),
    _RouteItem(name: '후룸라이드', emoji: '🌊', type: '어드벤처', waitMin: 15, crowd: '보통', crowdColor: Color(0xFFFFC107)),
    _RouteItem(name: '대관람차', emoji: '🎠', type: '여유', waitMin: 5, crowd: '여유', crowdColor: Color(0xFF4CAF50)),
  ];

  void _openSettingsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CompanionBottomSheet(
        initialCompanion: _companion,
        initialStyle: _style,
        onConfirm: (c, s) => setState(() {
          _companion = c;
          _style = s;
        }),
      ),
    );
  }

  void _openPricingPopup() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _LunaPricingSheet(discountPct: _discountPct),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ⚠️ Scaffold 를 root 로 쓰지 않는다.
    // MainScreen 이 이미 Scaffold 안에 IndexedStack 으로 이 화면을 넣는데,
    // macOS desktop 에서 nested Scaffold + SafeArea + Scroll 조합이 본문을
    // 통째로 무효화시키는 케이스가 있어서 ColoredBox 로 단순화.
    return ColoredBox(
      color: const Color(0xFFF7F7F7),
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          children: [
            const _Header(),
            const SizedBox(height: 12),
            const _VisitScoreCard(
              score: _visitScore,
              discountPct: _discountPct,
              routeSummary: _routeSummary,
            ),
            const SizedBox(height: 16),
            if (_isOffPeak) ...[
              const _OffPeakBanner(),
              const SizedBox(height: 16),
            ],
            const _UsageBanner(),
            const SizedBox(height: 16),
            // IntrinsicHeight: ListView 가 자식에 unbounded height 를 주기 때문에
            // Row 의 crossAxisAlignment: stretch 는 그대로면 "BoxConstraints forces
            // infinite height" 로 터진다. Row 의 intrinsic height 를 부모가 강제.
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: const [
                  Expanded(child: _WeatherCard()),
                  SizedBox(width: 12),
                  Expanded(child: _CrowdCard()),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _LunaPricingCard(discountPct: _discountPct, onTap: _openPricingPopup),
            const SizedBox(height: 16),
            _MyLunaCard(
              companion: _companion,
              style: _style,
              items: _routeItems,
              onSettings: _openSettingsSheet,
              onOpenMap: widget.onOpenMyLuna,
            ),
            const SizedBox(height: 24),
            const _TodayEventsSection(),
          ],
        ),
      ),
    );
  }
}

// ─── Header ────────────────────────────────────────────────
class _Header extends StatelessWidget {
  const _Header();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 4),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '서울랜드',
                style: TextStyle(color: Color(0xFF888888), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 2.2),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('RE-TRACE',
                      style: TextStyle(color: Color(0xFFE60012), fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFFE60012), borderRadius: BorderRadius.circular(4)),
                    child: const Text('BETA',
                        style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          const Icon(Icons.search_rounded, color: Color(0xFF1F1F1F), size: 24),
          const SizedBox(width: 16),
          const Icon(Icons.notifications_outlined, color: Color(0xFF1F1F1F), size: 24),
        ],
      ),
    );
  }
}

// ─── 방문 가치 스코어 카드 (0~100) ─────────────────────────
class _VisitScoreCard extends StatelessWidget {
  final int score;
  final int discountPct;
  final String routeSummary;
  const _VisitScoreCard({required this.score, required this.discountPct, required this.routeSummary});

  Color get _scoreColor {
    if (score >= 80) return const Color(0xFF4CAF50);
    if (score >= 50) return const Color(0xFFFFB300);
    return const Color(0xFFE60012);
  }

  String get _scoreLabel {
    if (score >= 80) return '오늘 방문 강추!';
    if (score >= 50) return '방문하기 좋은 날';
    return '오늘은 한산해요';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 96, height: 96,
            child: CustomPaint(
              painter: _GaugePainter(score: score.clamp(0, 100), color: _scoreColor),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$score',
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: _scoreColor, height: 1)),
                    const SizedBox(height: 2),
                    const Text('/100',
                        style: TextStyle(fontSize: 10, color: Color(0xFF888888), fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('오늘의 방문 가치',
                    style: TextStyle(fontSize: 11, color: Color(0xFF888888), fontWeight: FontWeight.w800, letterSpacing: 1)),
                const SizedBox(height: 4),
                Text(_scoreLabel,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF1F1F1F))),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE60012).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text('🎟 $discountPct% 할인',
                      style: const TextStyle(color: Color(0xFFE60012), fontSize: 11, fontWeight: FontWeight.w900)),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.route_rounded, size: 14, color: Color(0xFF888888)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        routeSummary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF555555), fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final int score;
  final Color color;
  _GaugePainter({required this.score, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 6;
    const stroke = 8.0;

    final track = Paint()
      ..color = const Color(0xFFEFEFEF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawCircle(center, radius, track);

    final progress = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final sweep = (score / 100.0) * 2 * math.pi;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweep,
      false,
      progress,
    );
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) => old.score != score || old.color != color;
}

// ─── 비수기 한산 알림 ───────────────────────────────────────
class _OffPeakBanner extends StatelessWidget {
  const _OffPeakBanner();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E3158).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E3158).withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: const BoxDecoration(color: Color(0xFF1E3158), shape: BoxShape.circle),
            alignment: Alignment.center,
            child: const Text('🌙', style: TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text('비수기 한산 알림',
                    style: TextStyle(fontSize: 11, color: Color(0xFF1E3158), fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                SizedBox(height: 2),
                Text('지금 가시면 대기 거의 없어요. 이스터에그 챕터 채울 절호의 기회',
                    style: TextStyle(fontSize: 12, color: Color(0xFF1F1F1F), fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFF1E3158), size: 20),
        ],
      ),
    );
  }
}

// ─── 사용법 배너 ───────────────────────────────────────────
class _UsageBanner extends StatelessWidget {
  const _UsageBanner();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: const [
          Icon(Icons.warning_amber_rounded, color: Color(0xFFFFC107), size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text('앱 사용 사용법 총정리!!',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1F1F1F))),
          ),
          Icon(Icons.chevron_right_rounded, color: Color(0xFF888888), size: 20),
        ],
      ),
    );
  }
}

// ─── 날씨 카드 ─────────────────────────────────────────────
class _WeatherCard extends StatelessWidget {
  const _WeatherCard();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Row(
            children: [
              Text('☁️', style: TextStyle(fontSize: 20)),
              SizedBox(width: 6),
              Text('오늘 흐림', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF1F1F1F))),
              Spacer(),
              Text('18°C', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF1E3158))),
            ],
          ),
          SizedBox(height: 10),
          Text('최저 15°C / 최고 20°C', style: TextStyle(fontSize: 11, color: Color(0xFF888888))),
          SizedBox(height: 2),
          Text('강수확률 60% | 과천, 경기도', style: TextStyle(fontSize: 10, color: Color(0xFF888888))),
        ],
      ),
    );
  }
}

// ─── 혼잡도 카드 ───────────────────────────────────────────
class _CrowdCard extends StatelessWidget {
  const _CrowdCard();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('현재 혼잡도',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF888888))),
          const SizedBox(height: 6),
          Row(
            children: const [
              SizedBox(
                width: 12, height: 12,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: Color(0xFFFFC107), shape: BoxShape.circle),
                ),
              ),
              SizedBox(width: 6),
              Text('중간', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1F1F1F))),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: const Color(0xFFFFF8E1), borderRadius: BorderRadius.circular(8)),
            child: Row(
              children: const [
                Text('💡', style: TextStyle(fontSize: 11)),
                SizedBox(width: 4),
                Expanded(
                  child: Text('오전 11시 이후 방문을 추천드려요',
                      style: TextStyle(fontSize: 10, color: Color(0xFFE6A817), height: 1.3)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 루나 프라이싱 카드 ────────────────────────────────────
class _LunaPricingCard extends StatelessWidget {
  final int discountPct;
  final VoidCallback onTap;
  const _LunaPricingCard({required this.discountPct, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1E3158),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFFE60012), borderRadius: BorderRadius.circular(6)),
                      child: const Text('💰 루나 프라이싱',
                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
                    ),
                    const SizedBox(height: 12),
                    const Text('3개월 만이네요.',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800, height: 1.3)),
                    const SizedBox(height: 6),
                    Text(
                      '흐린 오늘 서울랜드엔 사람이 적당해요.\n지난번 못 찾은 이스터에그, 오늘 만날 수 있어요.',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12, height: 1.5),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(color: const Color(0xFFE60012), borderRadius: BorderRadius.circular(8)),
                      child: const Text('루나 티켓 받기 →',
                          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$discountPct%',
                      style: const TextStyle(color: Color(0xFFF4B633), fontSize: 48, fontWeight: FontWeight.w900, height: 1)),
                  const SizedBox(height: 4),
                  Text('오늘의\n할인율',
                      textAlign: TextAlign.right,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11, height: 1.2)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── 루나 프라이싱 상세 시트 ───────────────────────────────
class _LunaPricingSheet extends StatelessWidget {
  final int discountPct;
  const _LunaPricingSheet({required this.discountPct});

  static String _fmt(int n) =>
      n.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  @override
  Widget build(BuildContext context) {
    const original = 30000;
    final discounted = original * (100 - discountPct) ~/ 100;
    final saved = original - discounted;
    final reasons = const [
      ('☁️', '흐린 평일', '+8%'),
      ('📅', '3개월 만의 재방문', '+5%'),
      ('🥚', '미수집 이스터에그 2개', '+2%'),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: const Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(99)))),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  '오늘 루나가 $discountPct%\n드리는 이유',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1F1F1F), height: 1.3),
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 32, height: 32,
                  decoration: const BoxDecoration(color: Color(0xFFF5F5F5), shape: BoxShape.circle),
                  child: const Icon(Icons.close, size: 16, color: Color(0xFF888888)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...reasons.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(color: const Color(0xFFF7F7F7), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      Text(r.$1, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 10),
                      Expanded(child: Text(r.$2, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                      Text(r.$3, style: const TextStyle(color: Color(0xFFE60012), fontSize: 14, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
              )),
          const Divider(color: Color(0xFFEEEEEE), height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${_fmt(original)}원',
                  style: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 15, decoration: TextDecoration.lineThrough)),
              const SizedBox(width: 6),
              const Text('→', style: TextStyle(color: Color(0xFF888888))),
              const SizedBox(width: 6),
              Text('${_fmt(discounted)}원',
                  style: const TextStyle(color: Color(0xFFE60012), fontSize: 24, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 4),
          Text('오늘 ${_fmt(saved)}원 아끼는 중', style: const TextStyle(color: Color(0xFF888888), fontSize: 12)),
          const SizedBox(height: 4),
          const Text('⏰ 오늘 자정까지', style: TextStyle(color: Color(0xFF888888), fontSize: 12)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE60012),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('루나 티켓 ${_fmt(saved)}원 아끼기',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 마이 루나 카드 ────────────────────────────────────────
class _RouteItem {
  final String name, emoji, type, crowd;
  final int waitMin;
  final Color crowdColor;
  const _RouteItem({
    required this.name,
    required this.emoji,
    required this.type,
    required this.waitMin,
    required this.crowd,
    required this.crowdColor,
  });
}

class _MyLunaCard extends StatelessWidget {
  final String companion;
  final String style;
  final List<_RouteItem> items;
  final VoidCallback onSettings;
  final VoidCallback? onOpenMap;
  const _MyLunaCard({
    required this.companion,
    required this.style,
    required this.items,
    required this.onSettings,
    required this.onOpenMap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E3158), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text('🌙', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 6),
              const Text('마이 루나',
                  style: TextStyle(color: Color(0xFF1E3158), fontSize: 16, fontWeight: FontWeight.w900)),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3158).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: const Text('AI 맞춤 동선',
                    style: TextStyle(color: Color(0xFF1E3158), fontSize: 11, fontWeight: FontWeight.w700)),
              ),
              const Spacer(),
              InkWell(
                onTap: onSettings,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFDDDDDD)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.tune, size: 14, color: Color(0xFF555555)),
                      SizedBox(width: 4),
                      Text('조건 변경',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF555555))),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            children: [
              _Pill(text: companion),
              _Pill(text: style),
            ],
          ),
          const SizedBox(height: 10),
          const Text('지난번 못 찾은 이스터에그,',
              style: TextStyle(color: Color(0xFF888888), fontSize: 13)),
          const Text('오늘 동선에 넣었어요. 🥚',
              style: TextStyle(color: Color(0xFF1F1F1F), fontSize: 15, fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          ...items.asMap().entries.map((e) => Padding(
                padding: EdgeInsets.only(bottom: e.key == items.length - 1 ? 0 : 12),
                child: _RouteRow(index: e.key + 1, item: e.value),
              )),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: onOpenMap,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3158),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('🗺️  오늘의 마이 루나 보기',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  const _Pill({required this.text});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(color: const Color(0xFF1E3158), borderRadius: BorderRadius.circular(99)),
      child: Text(text,
          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

class _RouteRow extends StatelessWidget {
  final int index;
  final _RouteItem item;
  const _RouteRow({required this.index, required this.item});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24, height: 24,
          decoration: const BoxDecoration(color: Color(0xFF1E3158), shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text('$index',
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            '${item.emoji} ${item.name}',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1F1F1F)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(4)),
                          child: Text(item.type,
                              style: const TextStyle(fontSize: 10, color: Color(0xFF888888), fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 6, height: 6, decoration: BoxDecoration(color: item.crowdColor, shape: BoxShape.circle)),
                      const SizedBox(width: 4),
                      Text(item.crowd,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: item.crowdColor)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text('⏱ 예상 대기 ${item.waitMin}분',
                  style: const TextStyle(fontSize: 10, color: Color(0xFF888888))),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── 오늘의 이벤트 ─────────────────────────────────────────
class _TodayEventsSection extends StatelessWidget {
  const _TodayEventsSection();
  @override
  Widget build(BuildContext context) {
    const events = [
      (tag: '[D-DAY]', bg: Color(0xFFE60012), name: '🎭 퍼레이드', time: '오후 2:00'),
      (tag: '[인기]', bg: Color(0xFF1E3158), name: '🎪 서커스쇼', time: '오후 4:30'),
      (tag: '[신규]', bg: Color(0xFF8E24AA), name: '✨ 불빛 쇼', time: '오후 8:00'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: const [
            Text('오늘의 이벤트',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1F1F1F))),
            Spacer(),
            Text('전체보기', style: TextStyle(fontSize: 12, color: Color(0xFF888888), fontWeight: FontWeight.w500)),
            Icon(Icons.chevron_right_rounded, size: 14, color: Color(0xFF888888)),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 104,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: events.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final e = events[i];
              return Container(
                width: 150,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: e.bg, borderRadius: BorderRadius.circular(4)),
                      child: Text(e.tag,
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(height: 8),
                    Text(e.name,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1F1F1F))),
                    const Spacer(),
                    Text('⏱ ${e.time}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF888888), fontWeight: FontWeight.w600)),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
