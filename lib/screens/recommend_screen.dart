import 'package:flutter/material.dart';

class RecommendScreen extends StatefulWidget {
  const RecommendScreen({super.key});

  @override
  State<RecommendScreen> createState() => _RecommendScreenState();
}

class _RecommendScreenState extends State<RecommendScreen> {
  String _topTab = '어트랙션';
  String _categoryFilter = '전체';

  final List<String> _categories = ['전체', '스릴', '가족', '여유', '포토'];

  final List<Map<String, dynamic>> _attractions = [
    {
      'name': '후룸라이드',
      'rating': 4.8,
      'reviewCount': 1240,
      'desc': '시원한 물줄기를 가르며 스릴을 만끽하세요!',
      'tags': ['#짜릿함', '#여름필수', '#물놀이'],
      'category': '스릴',
      'status': '지금 가기 최적',
      'statusDetail': '여유 · 대기 5분',
      'statusColor': const Color(0xFF4CAF50),
      'icon': '🌊',
      'liked': false,
    },
    {
      'name': '자이로스윙',
      'rating': 4.6,
      'reviewCount': 987,
      'desc': '360도 회전하며 하늘을 나는 느낌!',
      'tags': ['#아찔함', '#익스트림', '#스릴만점'],
      'category': '스릴',
      'status': '대기 있음',
      'statusDetail': '보통 · 대기 25분',
      'statusColor': const Color(0xFFFFB300),
      'icon': '🎡',
      'liked': false,
    },
    {
      'name': '대관람차',
      'rating': 4.7,
      'reviewCount': 2100,
      'desc': '서울랜드 전경을 한눈에! 낭만적인 뷰.',
      'tags': ['#낭만', '#포토명소', '#커플추천'],
      'category': '여유',
      'status': '지금 가기 최적',
      'statusDetail': '여유 · 대기 없음',
      'statusColor': const Color(0xFF4CAF50),
      'icon': '🎠',
      'liked': true,
    },
    {
      'name': '킹바이킹',
      'rating': 4.5,
      'reviewCount': 756,
      'desc': '바다를 정복하는 해적선! 용감한 자만 탑승.',
      'tags': ['#해적선', '#가족', '#스릴'],
      'category': '가족',
      'status': '여유',
      'statusDetail': '여유 · 대기 5분',
      'statusColor': const Color(0xFF4CAF50),
      'icon': '⚓',
      'liked': false,
    },
    {
      'name': '범퍼카',
      'rating': 4.3,
      'reviewCount': 1560,
      'desc': '신나게 부딪히며 즐기는 가족 필수 코스!',
      'tags': ['#가족', '#어린이', '#신남'],
      'category': '가족',
      'status': '여유',
      'statusDetail': '여유 · 대기 없음',
      'statusColor': const Color(0xFF4CAF50),
      'icon': '🚗',
      'liked': false,
    },
  ];

  final List<Map<String, dynamic>> _courses = [
    {
      'emoji': '🔥',
      'name': '스릴 만점 코스',
      'duration': '3~4시간',
      'attractionCount': 4,
      'route': '롤러코스터 > 자이로스윙 > 후룸라이드 > 범퍼카',
      'routeColor': const Color(0xFFFFEBEE),
      'routeBorderColor': const Color(0xFFFF5A5A),
      'routeTextColor': const Color(0xFFE60012),
    },
    {
      'emoji': '🌸',
      'name': '가족 힐링 코스',
      'duration': '2~3시간',
      'attractionCount': 5,
      'route': '회전목마 > 대관람차 > 범퍼카 > 워터건 > 퍼레이드',
      'routeColor': const Color(0xFFF1F8E9),
      'routeBorderColor': const Color(0xFF81C784),
      'routeTextColor': const Color(0xFF2E7D32),
    },
    {
      'emoji': '📸',
      'name': '포토존 투어 코스',
      'duration': '2시간',
      'attractionCount': 4,
      'route': '대관람차 > 벚꽃포토존 > 세계광장 > 미래의나라',
      'routeColor': const Color(0xFFFCE4EC),
      'routeBorderColor': const Color(0xFFF48FB1),
      'routeTextColor': const Color(0xFFC2185B),
    },
  ];

  List<Map<String, dynamic>> get _filteredAttractions {
    if (_categoryFilter == '전체') return _attractions;
    return _attractions.where((a) => a['category'] == _categoryFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Text('⚡', style: TextStyle(fontSize: 22)),
                        SizedBox(width: 6),
                        Text(
                          '맞춤 추천',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1F1F1F)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '지금 가기 딱 좋은 어트랙션을 추천해드려요 ✨',
                      style: TextStyle(fontSize: 13, color: Color(0xFF888888)),
                    ),
                    const SizedBox(height: 14),
                    // 상단 탭 (어트랙션 / 추천 코스)
                    Row(
                      children: [
                        _TopTab(
                          icon: '🎡',
                          label: '어트랙션',
                          isActive: _topTab == '어트랙션',
                          activeColor: const Color(0xFFE60012),
                          onTap: () => setState(() => _topTab = '어트랙션'),
                        ),
                        const SizedBox(width: 10),
                        _TopTab(
                          icon: '🗺️',
                          label: '추천 코스',
                          isActive: _topTab == '추천 코스',
                          activeColor: const Color(0xFF1E3158),
                          onTap: () => setState(() => _topTab = '추천 코스'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 0),
                  ],
                ),
              ),
            ),

            if (_topTab == '어트랙션') ...[
              // 카테고리 필터
              SliverToBoxAdapter(
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _categories.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final cat = _categories[i];
                        final isActive = _categoryFilter == cat;
                        return GestureDetector(
                          onTap: () => setState(() => _categoryFilter = cat),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: isActive ? const Color(0xFF1F1F1F) : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isActive ? const Color(0xFF1F1F1F) : const Color(0xFFE0E0E0),
                              ),
                            ),
                            child: Row(
                              children: [
                                if (cat == '전체') const Text('✨ ', style: TextStyle(fontSize: 12)),
                                if (cat == '스릴') const Text('🎢 ', style: TextStyle(fontSize: 12)),
                                if (cat == '가족') const Text('👨‍👩‍👧 ', style: TextStyle(fontSize: 12)),
                                if (cat == '여유') const Text('☁️ ', style: TextStyle(fontSize: 12)),
                                if (cat == '포토') const Text('📸 ', style: TextStyle(fontSize: 12)),
                                Text(
                                  cat,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isActive ? Colors.white : const Color(0xFF555555),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),

              // AI 기반 맞춤 추천 배너
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF4FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBBDEFB)),
                  ),
                  child: Row(
                    children: [
                      const Text('🤖', style: TextStyle(fontSize: 22)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'AI 기반 맞춤 추천',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1565C0)),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  width: 7, height: 7,
                                  decoration: const BoxDecoration(color: Color(0xFF4CAF50), shape: BoxShape.circle),
                                ),
                              ],
                            ),
                            const Text(
                              '현재 혼잡도 + 날씨 + 선호도를 분석했어요',
                              style: TextStyle(fontSize: 11, color: Color(0xFF1565C0)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 어트랙션 카드 리스트
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _AttractionCard(
                    attraction: _filteredAttractions[index],
                    onLike: () {
                      setState(() {
                        _filteredAttractions[index]['liked'] = !_filteredAttractions[index]['liked'];
                      });
                    },
                  ),
                  childCount: _filteredAttractions.length,
                ),
              ),
            ],

            if (_topTab == '추천 코스') ...[
              // AI 코스 추천 헤더
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('🗺️', style: TextStyle(fontSize: 20)),
                          SizedBox(width: 8),
                          Text(
                            'AI가 최적의 동선으로\n코스를 짜드려요!',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1F1F1F)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // 코스 카드 리스트
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _CourseCard(course: _courses[index]),
                  childCount: _courses.length,
                ),
              ),
            ],

            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}

// ─── 탭 버튼 ───────────────────────────────────────────────
class _TopTab extends StatelessWidget {
  final String icon, label;
  final bool isActive;
  final Color activeColor;
  final VoidCallback onTap;

  const _TopTab({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? activeColor : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isActive ? activeColor : const Color(0xFFE0E0E0)),
        ),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isActive ? Colors.white : const Color(0xFF555555),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 어트랙션 카드 ─────────────────────────────────────────
class _AttractionCard extends StatelessWidget {
  final Map<String, dynamic> attraction;
  final VoidCallback onLike;

  const _AttractionCard({required this.attraction, required this.onLike});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상태 배지
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (attraction['statusColor'] as Color).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: (attraction['statusColor'] as Color).withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🎯', style: TextStyle(fontSize: 10)),
                      const SizedBox(width: 4),
                      Text(
                        attraction['status'],
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: attraction['statusColor'] as Color,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(
                        color: attraction['statusColor'] as Color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      attraction['statusDetail'],
                      style: const TextStyle(fontSize: 11, color: Color(0xFF888888)),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: onLike,
                      child: Icon(
                        attraction['liked'] ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: attraction['liked'] ? const Color(0xFFE60012) : const Color(0xFFCCCCCC),
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // 이미지 + 정보
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 90, height: 90,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F0F0),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(attraction['icon'], style: const TextStyle(fontSize: 44)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              attraction['name'],
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF1F1F1F)),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {},
                            child: const Text('바로가기 〉', style: TextStyle(fontSize: 12, color: Color(0xFFE60012), fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, color: Color(0xFFFFC107), size: 16),
                          const SizedBox(width: 4),
                          Text(
                            '${attraction['rating']}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1F1F1F)),
                          ),
                          Text(
                            ' (${attraction['reviewCount'].toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')})',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF888888)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        attraction['desc'],
                        style: const TextStyle(fontSize: 12, color: Color(0xFF555555)),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        children: (attraction['tags'] as List<String>)
                            .map((tag) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF5F5F5),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(tag, style: const TextStyle(fontSize: 10, color: Color(0xFF666666))),
                                ))
                            .toList(),
                      ),
                    ],
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

// ─── 코스 카드 ─────────────────────────────────────────────
class _CourseCard extends StatelessWidget {
  final Map<String, dynamic> course;
  const _CourseCard({required this.course});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(course['emoji'], style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                course['name'],
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1F1F1F)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF888888)),
              const SizedBox(width: 4),
              Text('${course['duration']}', style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
              const Text(' · ', style: TextStyle(color: Color(0xFF888888))),
              const Text('😊 ', style: TextStyle(fontSize: 12)),
              Text('${course['attractionCount']}개 어트랙션', style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
            ],
          ),
          const SizedBox(height: 12),
          // 경로 표시
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: course['routeColor'] as Color,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: (course['routeBorderColor'] as Color).withValues(alpha: 0.5)),
            ),
            child: Text(
              course['route'],
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: course['routeTextColor'] as Color,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${course['name']} 코스를 시작합니다! 🚀'),
                    backgroundColor: const Color(0xFF1E3158),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: course['routeBorderColor'] as Color),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                '이 코스로 시작하기 〉',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: course['routeTextColor'] as Color,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
