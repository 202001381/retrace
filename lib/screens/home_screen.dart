import 'package:flutter/material.dart';
import '../widgets/companion_bottom_sheet.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onOpenMyLuna;
  const HomeScreen({super.key, this.onOpenMyLuna});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _companion = '가족';
  String _style = '스릴·액티비티';

  // ── 시나리오 (하드코딩) ────────────────────────────────────
  static const _weather = (
    icon: '☁️',
    label: '오늘 흐림',
    temp: '18°C',
    lo: '15°C',
    hi: '20°C',
    rainPct: '60%',
    region: '과천, 경기도',
  );
  static const _crowd = (
    label: '중간',
    color: Color(0xFFFFC107),
    tipBg: Color(0xFFFFF8E1),
    tipColor: Color(0xFFE6A817),
    tip: '오전 11시 이후 방문을 추천드려요',
  );
  static const int _discountPct = 15;

  // Top-3 더미 동선 (default: 가족·스릴)
  List<_RouteItem> get _routeItems => const [
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
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                children: [
                  const _UsageBanner(),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _WeatherCard(weather: _weather)),
                      const SizedBox(width: 12),
                      Expanded(child: _CrowdCard(crowd: _crowd)),
                    ],
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
          ],
        ),
      ),
    );
  }
}

// ─── Header ────────────────────────────────────────────────
class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF7F7F7),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '서울랜드',
                style: TextStyle(
                  color: Color(0xFF888888),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.2,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  const Text(
                    'RE-TRACE',
                    style: TextStyle(
                      color: Color(0xFFE60012),
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE60012),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'BETA',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
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
            child: Text(
              '앱 사용 사용법 총정리!!',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1F1F1F)),
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: Color(0xFF888888), size: 20),
        ],
      ),
    );
  }
}

// ─── 날씨 카드 ─────────────────────────────────────────────
class _WeatherCard extends StatelessWidget {
  final ({String icon, String label, String temp, String lo, String hi, String rainPct, String region}) weather;
  const _WeatherCard({required this.weather});

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
          Row(
            children: [
              Text(weather.icon, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 6),
              Text(weather.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF1F1F1F))),
              const Spacer(),
              Text(weather.temp, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF1E3158))),
            ],
          ),
          const SizedBox(height: 10),
          Text('최저 ${weather.lo} / 최고 ${weather.hi}', style: const TextStyle(fontSize: 11, color: Color(0xFF888888))),
          const SizedBox(height: 2),
          Text('강수확률 ${weather.rainPct} | ${weather.region}', style: const TextStyle(fontSize: 10, color: Color(0xFF888888))),
        ],
      ),
    );
  }
}

// ─── 혼잡도 카드 ───────────────────────────────────────────
class _CrowdCard extends StatelessWidget {
  final ({String label, Color color, Color tipBg, Color tipColor, String tip}) crowd;
  const _CrowdCard({required this.crowd});

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
          const Text('현재 혼잡도', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF888888))),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: crowd.color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(crowd.label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1F1F1F))),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: crowd.tipBg, borderRadius: BorderRadius.circular(8)),
            child: Row(
              children: [
                const Text('💡', style: TextStyle(fontSize: 11)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    crowd.tip,
                    style: TextStyle(fontSize: 10, color: crowd.tipColor, height: 1.3),
                  ),
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
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E3158),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE60012),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        '💰 루나 프라이싱',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('3개월 만이네요.', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800, height: 1.3)),
                    const SizedBox(height: 6),
                    Text(
                      '흐린 오늘 서울랜드엔 사람이 적당해요.\n지난번 못 찾은 이스터에그, 오늘 만날 수 있어요.',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12, height: 1.5),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE60012),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '루나 티켓 받기 →',
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$discountPct%',
                    style: const TextStyle(
                      color: Color(0xFFF4B633),
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '오늘의\n할인율',
                    textAlign: TextAlign.right,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11, height: 1.2),
                  ),
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

  @override
  Widget build(BuildContext context) {
    const original = 30000;
    final discounted = original * (100 - discountPct) ~/ 100;
    final saved = original - discounted;
    final reasons = [
      ('☁️', '흐린 평일', '+8%'),
      ('📅', '3개월 만의 재방문', '+5%'),
      ('🥚', '미수집 이스터에그 2개', '+2%'),
    ];

    String fmt(int n) => n.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );

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
                  width: 32,
                  height: 32,
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
          const SizedBox(height: 4),
          const Divider(color: Color(0xFFEEEEEE), height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${fmt(original)}원',
                  style: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 15, decoration: TextDecoration.lineThrough)),
              const SizedBox(width: 6),
              const Text('→', style: TextStyle(color: Color(0xFF888888))),
              const SizedBox(width: 6),
              Text('${fmt(discounted)}원',
                  style: const TextStyle(color: Color(0xFFE60012), fontSize: 24, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 4),
          Text('오늘 ${fmt(saved)}원 아끼는 중', style: const TextStyle(color: Color(0xFF888888), fontSize: 12)),
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
              child: Text('루나 티켓 ${fmt(saved)}원 아끼기',
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
        children: [
          Row(
            children: [
              const Text('🌙', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 6),
              const Text('마이 루나', style: TextStyle(color: Color(0xFF1E3158), fontSize: 16, fontWeight: FontWeight.w900)),
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
                      Text('조건 변경', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF555555))),
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
          const Text('지난번 못 찾은 이스터에그,', style: TextStyle(color: Color(0xFF888888), fontSize: 13)),
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
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
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
          width: 24,
          height: 24,
          decoration: const BoxDecoration(color: Color(0xFF1E3158), shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text('$index',
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(item.type, style: const TextStyle(fontSize: 10, color: Color(0xFF888888), fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6, height: 6,
                        decoration: BoxDecoration(color: item.crowdColor, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 4),
                      Text(item.crowd, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: item.crowdColor)),
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
    final events = const [
      (tag: '[D-DAY]', bg: Color(0xFFE60012), name: '🎭 퍼레이드', time: '오후 2:00'),
      (tag: '[인기]', bg: Color(0xFF1E3158), name: '🎪 서커스쇼', time: '오후 4:30'),
      (tag: '[신규]', bg: Color(0xFF8E24AA), name: '✨ 불빛 쇼', time: '오후 8:00'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Text('오늘의 이벤트', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1F1F1F))),
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
                      child: Text(e.tag, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(height: 8),
                    Text(e.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1F1F1F))),
                    const Spacer(),
                    Text('⏱ ${e.time}', style: const TextStyle(fontSize: 11, color: Color(0xFF888888), fontWeight: FontWeight.w600)),
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
