import 'package:flutter/material.dart';

class RecommendScreen extends StatefulWidget {
  const RecommendScreen({super.key});
  @override
  State<RecommendScreen> createState() => _RecommendScreenState();
}

class _RecommendScreenState extends State<RecommendScreen> {
  int _mainTab = 0; // 0: 어트랙션, 1: 추천 코스
  String _category = '전체';

  static const _categories = [
    ('전체', '✨'),
    ('스릴', '🎢'),
    ('가족', '👨‍👩‍👧'),
    ('여유', '☁️'),
    ('포토', '📷'),
  ];

  final List<_AttractionItem> _attractions = [
    const _AttractionItem(
      name: '후룸라이드',
      desc: '시원한 물줄기를 가르며 스릴을 만끽하세요!',
      tags: ['#짜릿함', '#여름필수', '#물놀이'],
      rating: 4.8,
      reviewCount: 1240,
      wait: '대기 5분',
      crowdLabel: '여유',
      crowdColor: Color(0xFF4CAF50),
      coverGradient: [Color(0xFF87CEEB), Color(0xFF1976D2)],
      emoji: '🌊',
      badge: '🎉 지금 가기 최적',
      category: '스릴',
    ),
    const _AttractionItem(
      name: '대관람차',
      desc: '서울랜드의 랜드마크. 펼쳐지는 관악산 전경.',
      tags: ['#뷰맛집', '#커플', '#야경'],
      rating: 4.6,
      reviewCount: 982,
      wait: '대기 5분',
      crowdLabel: '여유',
      crowdColor: Color(0xFF4CAF50),
      coverGradient: [Color(0xFFFFC107), Color(0xFFFF8A65)],
      emoji: '🎠',
      badge: '☁️ 비 와도 OK',
      category: '여유',
    ),
    const _AttractionItem(
      name: '은하열차 888',
      desc: '1988년 개장 당시 최초 롤러코스터. 38년의 레전드.',
      tags: ['#레전드', '#스릴', '#기억의장소'],
      rating: 4.5,
      reviewCount: 3240,
      wait: '대기 15분',
      crowdLabel: '보통',
      crowdColor: Color(0xFFFFC107),
      coverGradient: [Color(0xFFE91E63), Color(0xFFE60012)],
      emoji: '🎢',
      badge: '🥚 이스터에그',
      category: '스릴',
    ),
  ];

  final List<_CourseItem> _courses = const [
    _CourseItem(
      title: '🔥 스릴 만점 코스',
      duration: '3~4시간',
      count: 4,
      flow: '롤러코스터 > 자이로스윙 > 후룸라이드 > 범퍼카',
      accent: Color(0xFFE60012),
    ),
    _CourseItem(
      title: '🌸 가족 힐링 코스',
      duration: '2~3시간',
      count: 5,
      flow: '회전목마 > 대관람차 > 범퍼카 > 워터건 > 퍼레이드',
      accent: Color(0xFF4CAF50),
    ),
  ];

  List<_AttractionItem> get _filtered {
    if (_category == '전체') return _attractions;
    return _attractions.where((a) => a.category == _category).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.flash_on_rounded, color: Color(0xFFE60012), size: 24),
                      SizedBox(width: 6),
                      Text('맞춤 추천',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFFE60012))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text('지금 가기 딱 좋은 어트랙션을 추천해드려요 ✨',
                      style: TextStyle(fontSize: 13, color: Color(0xFF1F1F1F), fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(top: 16, bottom: 28),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFEEEEEE)),
                      ),
                      child: Row(
                        children: [
                          _MainTab(label: '🎡 어트랙션', active: _mainTab == 0, onTap: () => setState(() => _mainTab = 0)),
                          _MainTab(label: '🗺 추천 코스', active: _mainTab == 1, onTap: () => setState(() => _mainTab = 1)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_mainTab == 0) ..._buildAttractionsTab() else ..._buildCoursesTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildAttractionsTab() {
    return [
      SizedBox(
        height: 36,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          scrollDirection: Axis.horizontal,
          itemCount: _categories.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final c = _categories[i];
            final active = _category == c.$1;
            return GestureDetector(
              onTap: () => setState(() => _category = c.$1),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: active ? const Color(0xFF1F1F1F) : Colors.white,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: active ? const Color(0xFF1F1F1F) : const Color(0xFFE0E0E0)),
                ),
                alignment: Alignment.center,
                child: Text('${c.$2} ${c.$1}',
                    style: TextStyle(color: active ? Colors.white : const Color(0xFF1F1F1F), fontSize: 13, fontWeight: FontWeight.w800)),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 16),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF87CEEB).withValues(alpha: 0.15),
            border: Border.all(color: const Color(0xFF87CEEB).withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Text('🤖', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Text('AI 기반 맞춤 추천',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF1E3158))),
                        SizedBox(width: 4),
                        _LiveDot(),
                      ],
                    ),
                    Text(
                      '현재 혼잡도(중간) + 날씨(흐림 18°C) + 선호도를 분석했어요',
                      style: TextStyle(fontSize: 10, color: const Color(0xFF1E3158).withValues(alpha: 0.7)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      ..._filtered.map((a) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: _AttractionCard(item: a),
          )),
      if (_filtered.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(
            child: Text('해당 카테고리의 추천이 없어요',
                style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 13, fontWeight: FontWeight.w700)),
          ),
        ),
    ];
  }

  List<Widget> _buildCoursesTab() {
    return [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🗺 AI가 최적의 동선으로\n코스를 짜드려요!',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1F1F1F), height: 1.4)),
            const SizedBox(height: 16),
            ..._courses.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _CourseCard(item: c),
                )),
          ],
        ),
      ),
    ];
  }
}

class _MainTab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _MainTab({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? const Color(0xFFE60012) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(label,
              style: TextStyle(color: active ? Colors.white : const Color(0xFF888888), fontSize: 13, fontWeight: FontWeight.w800)),
        ),
      ),
    );
  }
}

class _LiveDot extends StatelessWidget {
  const _LiveDot();
  @override
  Widget build(BuildContext context) {
    return Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF4CAF50), shape: BoxShape.circle));
  }
}

class _AttractionItem {
  final String name, desc, wait, crowdLabel, emoji, badge, category;
  final List<String> tags;
  final double rating;
  final int reviewCount;
  final Color crowdColor;
  final List<Color> coverGradient;

  const _AttractionItem({
    required this.name,
    required this.desc,
    required this.tags,
    required this.rating,
    required this.reviewCount,
    required this.wait,
    required this.crowdLabel,
    required this.crowdColor,
    required this.coverGradient,
    required this.emoji,
    required this.badge,
    required this.category,
  });
}

class _AttractionCard extends StatefulWidget {
  final _AttractionItem item;
  const _AttractionCard({required this.item});
  @override
  State<_AttractionCard> createState() => _AttractionCardState();
}

class _AttractionCardState extends State<_AttractionCard> {
  bool _liked = false;
  String _fmt(int n) => n.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  @override
  Widget build(BuildContext context) {
    final a = widget.item;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEEE)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE60012).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(a.badge,
                      style: const TextStyle(fontSize: 11, color: Color(0xFFE60012), fontWeight: FontWeight.w900)),
                ),
                const SizedBox(width: 6),
                Container(width: 6, height: 6, decoration: BoxDecoration(color: a.crowdColor, shape: BoxShape.circle)),
                const SizedBox(width: 4),
                Text('${a.crowdLabel} • ⏱ ${a.wait}',
                    style: TextStyle(fontSize: 11, color: a.crowdColor, fontWeight: FontWeight.w700)),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() => _liked = !_liked),
                  child: Icon(
                    _liked ? Icons.favorite : Icons.favorite_border,
                    color: _liked ? const Color(0xFFE60012) : const Color(0xFF888888),
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 140,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: a.coverGradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
            ),
            alignment: Alignment.center,
            child: Text(a.emoji, style: const TextStyle(fontSize: 64)),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(a.name,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1F1F1F))),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text('바로가기', style: TextStyle(color: Color(0xFFE60012), fontSize: 11, fontWeight: FontWeight.w800)),
                        Icon(Icons.chevron_right, color: Color(0xFFE60012), size: 14),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.star, color: Color(0xFFFFC107), size: 14),
                    const SizedBox(width: 2),
                    Text('${a.rating}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFFFFC107))),
                    const SizedBox(width: 4),
                    Text('(${_fmt(a.reviewCount)})',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF888888), fontWeight: FontWeight.w500)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(a.desc, style: const TextStyle(fontSize: 13, color: Color(0xFF1F1F1F))),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  children: a.tags
                      .map((t) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(99)),
                            child: Text(t, style: const TextStyle(fontSize: 11, color: Color(0xFF888888))),
                          ))
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseItem {
  final String title, duration, flow;
  final int count;
  final Color accent;
  const _CourseItem({required this.title, required this.duration, required this.count, required this.flow, required this.accent});
}

class _CourseCard extends StatelessWidget {
  final _CourseItem item;
  const _CourseCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEEE)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF1F1F1F))),
          const SizedBox(height: 4),
          Text('⏱ ${item.duration} • 😊 ${item.count}개 어트랙션',
              style: const TextStyle(fontSize: 11, color: Color(0xFF888888))),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: item.accent.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
            child: Text(item.flow, style: TextStyle(fontSize: 13, color: item.accent, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                foregroundColor: item.accent,
                side: BorderSide(color: item.accent),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('이 코스로 시작하기 >', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }
}
