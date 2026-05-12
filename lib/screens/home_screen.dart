import 'package:flutter/material.dart';
import '../widgets/companion_bottom_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _companionType = '가족';
  List<String> _preferences = ['스릴·액티비티'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showCompanionSheet();
    });
  }

  void _showCompanionSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CompanionBottomSheet(
        initialCompanion: _companionType,
        initialPreferences: _preferences,
        onConfirm: (companion, prefs) {
          setState(() {
            _companionType = companion;
            _preferences = prefs;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: Colors.white,
              elevation: 0,
              scrolledUnderElevation: 1,
              shadowColor: Colors.black12,
              title: const Text(
                'SeoulLand',
                style: TextStyle(
                  color: Color(0xFFE60012),
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.search_rounded, color: Color(0xFF1F1F1F)),
                  onPressed: () {},
                ),
                IconButton(
                  icon: const Icon(Icons.notifications_outlined, color: Color(0xFF1F1F1F)),
                  onPressed: () {},
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 사용법 배너
                    _UsageBanner(),
                    const SizedBox(height: 14),
                    // 날씨 + 혼잡도 카드
                    Row(
                      children: [
                        Expanded(child: _WeatherCard()),
                        const SizedBox(width: 12),
                        Expanded(child: _CrowdCard()),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // 선제적 동선 추천
                    _RouteRecommendCard(
                      companionType: _companionType,
                      preferences: _preferences,
                      onConditionChange: _showCompanionSheet,
                    ),
                    const SizedBox(height: 16),
                    // 오늘의 이벤트
                    _TodayEventSection(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 사용법 배너 ───────────────────────────────────────────
class _UsageBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          const Text('📱', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              '앱 사용 사용법 총정리!!',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1F1F1F)),
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFF9E9E9E), size: 20),
        ],
      ),
    );
  }
}

// ─── 날씨 카드 ─────────────────────────────────────────────
class _WeatherCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Text('☀️', style: TextStyle(fontSize: 24)),
              SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('오늘 맑음', style: TextStyle(fontSize: 12, color: Color(0xFF666666))),
                  Text('18°C', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFFE60012))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text('최저 12°C / 최고 21°C', style: TextStyle(fontSize: 11, color: Color(0xFF888888))),
          const SizedBox(height: 2),
          const Text('강수확률 5% | 과천, 경기도', style: TextStyle(fontSize: 11, color: Color(0xFF888888))),
        ],
      ),
    );
  }
}

// ─── 혼잡도 카드 ───────────────────────────────────────────
class _CrowdCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('현재 혼잡도', style: TextStyle(fontSize: 12, color: Color(0xFF666666))),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 10, height: 10,
                decoration: const BoxDecoration(color: Color(0xFFFFB300), shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              const Text('중간', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1F1F1F))),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FFF4),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Text('💡', style: TextStyle(fontSize: 11)),
                SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '오전 11시 이후 방문을 추천드려요',
                    style: TextStyle(fontSize: 10, color: Color(0xFF2E7D32)),
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

// ─── 선제적 동선 추천 카드 ──────────────────────────────────
class _RouteRecommendCard extends StatelessWidget {
  final String companionType;
  final List<String> preferences;
  final VoidCallback onConditionChange;

  const _RouteRecommendCard({
    required this.companionType,
    required this.preferences,
    required this.onConditionChange,
  });

  @override
  Widget build(BuildContext context) {
    final attractions = _getAttractions(companionType);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('⚡', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              const Text('선제적 동선 추천', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1F1F1F))),
              const Spacer(),
              GestureDetector(
                onTap: onConditionChange,
                child: Row(
                  children: const [
                    Icon(Icons.tune_rounded, size: 14, color: Color(0xFF888888)),
                    SizedBox(width: 3),
                    Text('조건 변경', style: TextStyle(fontSize: 12, color: Color(0xFF888888))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 선택된 조건 칩
          Wrap(
            spacing: 6,
            children: [
              _ConditionChip(label: companionType, color: const Color(0xFF1F1F1F)),
              ...preferences.map((p) => _ConditionChip(label: p, color: const Color(0xFFE60012))),
              const Text(' 에 딱 맞는 코스! 🚀', style: TextStyle(fontSize: 13, color: Color(0xFF1F1F1F), fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 14),
          // 어트랙션 리스트
          ...attractions.asMap().entries.map((e) => _AttractionItem(
            rank: e.key + 1,
            name: e.value['name']!,
            tag: e.value['tag']!,
            wait: e.value['wait']!,
            status: e.value['status']!,
          )),
          const SizedBox(height: 14),
          // 경로 지도 보기
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE0E0E0)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Text(
                '경로 지도로 보기 〉',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF555555)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, String>> _getAttractions(String companion) {
    if (companion == '가족') {
      return [
        {'name': '급류타기', 'tag': '어드벤처', 'wait': '15분', 'status': '보통'},
        {'name': '킹바이킹', 'tag': '스릴', 'wait': '5분', 'status': '여유'},
        {'name': '범퍼카', 'tag': '가족', 'wait': '10분', 'status': '보통'},
      ];
    } else if (companion == '연인') {
      return [
        {'name': '대관람차', 'tag': '낭만', 'wait': '10분', 'status': '여유'},
        {'name': '후룸라이드', 'tag': '스릴', 'wait': '20분', 'status': '보통'},
        {'name': '회전목마', 'tag': '감성', 'wait': '5분', 'status': '여유'},
      ];
    } else if (companion == '친구') {
      return [
        {'name': '자이로스윙', 'tag': '스릴', 'wait': '25분', 'status': '혼잡'},
        {'name': '후룸라이드', 'tag': '물놀이', 'wait': '15분', 'status': '보통'},
        {'name': '범퍼카', 'tag': '재미', 'wait': '10분', 'status': '여유'},
      ];
    } else {
      return [
        {'name': '후룸라이드', 'tag': '스릴', 'wait': '5분', 'status': '여유'},
        {'name': '킹바이킹', 'tag': '스릴', 'wait': '5분', 'status': '여유'},
        {'name': '자이로스윙', 'tag': '익스트림', 'wait': '10분', 'status': '보통'},
      ];
    }
  }
}

class _ConditionChip extends StatelessWidget {
  final String label;
  final Color color;
  const _ConditionChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

class _AttractionItem extends StatelessWidget {
  final int rank;
  final String name, tag, wait, status;

  const _AttractionItem({
    required this.rank, required this.name, required this.tag,
    required this.wait, required this.status,
  });

  Color get _statusColor {
    switch (status) {
      case '여유': return const Color(0xFF4CAF50);
      case '혼잡': return const Color(0xFFE60012);
      default: return const Color(0xFFFFB300);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 26, height: 26,
            decoration: const BoxDecoration(color: Color(0xFF1F1F1F), shape: BoxShape.circle),
            child: Center(
              child: Text('$rank', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1F1F1F))),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(tag, style: const TextStyle(fontSize: 10, color: Color(0xFF888888))),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded, size: 12, color: Color(0xFF999999)),
                    const SizedBox(width: 3),
                    Text('예상 대기 $wait', style: const TextStyle(fontSize: 12, color: Color(0xFF999999))),
                  ],
                ),
              ],
            ),
          ),
          Row(
            children: [
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(color: _statusColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
              Text(status, style: TextStyle(fontSize: 13, color: _statusColor, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── 오늘의 이벤트 ──────────────────────────────────────────
class _TodayEventSection extends StatelessWidget {
  final List<Map<String, String>> _events = const [
    {'badge': 'D-DAY', 'badgeColor': 'red', 'title': '미래일로 퍼레이드', 'desc': '매일 오후 2시, 4시 세계광장 출발'},
    {'badge': '인기', 'badgeColor': 'blue', 'title': '신나는 서커스', 'desc': '스타월드 특별공연 3월 한정'},
    {'badge': '신규', 'badgeColor': 'green', 'title': '포토존 이벤트', 'desc': '봄 한정 벚꽃 포토존 오픈'},
    {'badge': 'SALE', 'badgeColor': 'orange', 'title': '가족 패키지 할인', 'desc': '4인 이상 입장권 20% 할인'},
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('오늘의 이벤트', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1F1F1F))),
            const Spacer(),
            GestureDetector(
              onTap: () {},
              child: const Text('전체보기 〉', style: TextStyle(fontSize: 13, color: Color(0xFF888888))),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 140,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _events.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) => _EventCard(event: _events[i]),
          ),
        ),
      ],
    );
  }
}

class _EventCard extends StatelessWidget {
  final Map<String, String> event;
  const _EventCard({required this.event});

  Color get _badgeColor {
    switch (event['badgeColor']) {
      case 'red': return const Color(0xFFE60012);
      case 'blue': return const Color(0xFF1565C0);
      case 'green': return const Color(0xFF2E7D32);
      default: return const Color(0xFFE65100);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _badgeColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '[${event['badge']}]',
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 10),
          // 이미지 플레이스홀더
          Container(
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFFF0F0F0),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                _getEventEmoji(event['badge']!),
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            event['title']!,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1F1F1F)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            event['desc']!,
            style: const TextStyle(fontSize: 10, color: Color(0xFF888888)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  String _getEventEmoji(String badge) {
    switch (badge) {
      case 'D-DAY': return '🎉';
      case '인기': return '🎪';
      case '신규': return '🌸';
      default: return '🎟️';
    }
  }
}
