import 'package:flutter/material.dart';

class ArchiveScreen extends StatefulWidget {
  const ArchiveScreen({super.key});

  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen> {
  String _selectedSeason = '봄';
  int _collectedBooks = 0;

  final List<String> _seasons = ['봄', '여름', '가을', '겨울'];

  final Map<String, Map<String, dynamic>> _chapterData = {
    '봄': {
      'icon': '🌸',
      'title': '봄 챕터',
      'desc': '벚꽃 흩날리는 봄날의 기억',
      'bgColor': Color(0xFFFCEFF6),
      'accentColor': Color(0xFFE91E63),
      'books': 0,
    },
    '여름': {
      'icon': '🌊',
      'title': '여름 챕터',
      'desc': '짜릿한 물놀이의 여름 기억',
      'bgColor': Color(0xFFE3F2FD),
      'accentColor': Color(0xFF1565C0),
      'books': 0,
    },
    '가을': {
      'icon': '🍂',
      'title': '가을 챕터',
      'desc': '단풍 물든 가을날의 추억',
      'bgColor': Color(0xFFFFF8E1),
      'accentColor': Color(0xFFE65100),
      'books': 0,
    },
    '겨울': {
      'icon': '❄️',
      'title': '겨울 챕터',
      'desc': '눈 내리는 겨울의 특별한 기억',
      'bgColor': Color(0xFFE8EAF6),
      'accentColor': Color(0xFF283593),
      'books': 0,
    },
  };

  void _simulateCollect() {
    final chapter = _chapterData[_selectedSeason]!;
    final currentBooks = chapter['books'] as int;
    if (currentBooks >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 이미 챕터를 완성했어요!'),
          backgroundColor: Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() {
      _chapterData[_selectedSeason]!['books'] = currentBooks + 1;
      _collectedBooks++;
    });

    final newCount = currentBooks + 1;
    String msg = '📖 기억 조각이 수집되었습니다! ($newCount/5)';
    if (newCount == 3) msg = '🎁 서울랜드 한정 굿즈 획득! ($newCount/5)';
    if (newCount == 5) msg = '🎟️ 무료 입장권 획득! 챕터 완성! ($newCount/5)';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFF1E3158),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chapter = _chapterData[_selectedSeason]!;
    final books = chapter['books'] as int;
    final accentColor = chapter['accentColor'] as Color;

    return Scaffold(
      backgroundColor: chapter['bgColor'] as Color,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // 헤더
            SliverToBoxAdapter(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.menu_book_rounded, size: 26, color: Color(0xFF1E2D4E)),
                        const SizedBox(width: 8),
                        const Text(
                          'Retrace Archive',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF1E2D4E),
                            letterSpacing: -0.5,
                          ),
                        ),
                        const Spacer(),
                        const Text('📚', style: TextStyle(fontSize: 28)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '계절별 기억의 조각을 모아 책장을 채워보세요.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF888888)),
                    ),
                    const SizedBox(height: 16),
                    // 계절 탭
                    Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: _seasons.map((season) {
                          final isActive = _selectedSeason == season;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedSeason = season),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: isActive ? const Color(0xFF1E3158) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    season,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                                      color: isActive ? Colors.white : const Color(0xFF666666),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 챕터 카드
                    _ChapterCard(chapter: chapter, accentColor: accentColor),
                    const SizedBox(height: 16),

                    // 책장 섹션
                    _BookshelfSection(books: books, accentColor: accentColor),
                    const SizedBox(height: 16),

                    // 수집 안내 + CTA
                    _CollectSection(
                      books: books,
                      onCollect: _simulateCollect,
                    ),
                    const SizedBox(height: 16),

                    // 챕터 달성 보상
                    _RewardSection(accentColor: accentColor, books: books),
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

// ─── 챕터 카드 ─────────────────────────────────────────────
class _ChapterCard extends StatelessWidget {
  final Map<String, dynamic> chapter;
  final Color accentColor;

  const _ChapterCard({required this.chapter, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(chapter['icon'], style: const TextStyle(fontSize: 26)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  chapter['title'],
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: accentColor,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  chapter['desc'],
                  style: const TextStyle(fontSize: 13, color: Color(0xFF888888)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 책장 섹션 ─────────────────────────────────────────────
class _BookshelfSection extends StatelessWidget {
  final int books;
  final Color accentColor;

  const _BookshelfSection({required this.books, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('기억의 책장', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1F1F1F))),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: books > 0 ? accentColor : const Color(0xFFEEEEEE),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$books / 5 권',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: books > 0 ? Colors.white : const Color(0xFF888888),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // 책장 그래픽
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 160,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF8B5A2B), Color(0xFF6D4520)],
              ),
            ),
            child: Stack(
              children: [
                // 선반 라인들
                ...List.generate(3, (i) => Positioned(
                  top: 50.0 + (i * 50),
                  left: 0, right: 0,
                  child: Container(
                    height: 6,
                    color: const Color(0xFF5C3A1E),
                  ),
                )),
                // 책들
                Positioned(
                  bottom: 6, left: 12,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(5, (i) {
                      final hasBook = i < books;
                      return _BookSpine(
                        index: i,
                        hasBook: hasBook,
                        accentColor: accentColor,
                      );
                    }),
                  ),
                ),
                // 비어있을 때 안내
                if (books == 0)
                  const Center(
                    child: Text(
                      '기억 조각을 수집하면\n책장이 채워집니다 ✨',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        // 진행 바
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: books / 5,
            backgroundColor: const Color(0xFFE0E0E0),
            valueColor: AlwaysStoppedAnimation<Color>(accentColor),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}

class _BookSpine extends StatelessWidget {
  final int index;
  final bool hasBook;
  final Color accentColor;

  const _BookSpine({required this.index, required this.hasBook, required this.accentColor});

  static const List<Color> _bookColors = [
    Color(0xFFE91E63),
    Color(0xFF9C27B0),
    Color(0xFF2196F3),
    Color(0xFF4CAF50),
    Color(0xFFFF9800),
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutBack,
      width: 22,
      height: hasBook ? (80 + (index % 3) * 10).toDouble() : 0,
      margin: const EdgeInsets.only(right: 5),
      decoration: BoxDecoration(
        color: hasBook ? _bookColors[index % _bookColors.length] : Colors.transparent,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
        boxShadow: hasBook ? [
          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4, offset: const Offset(2, 0)),
        ] : null,
      ),
    );
  }
}

// ─── 수집 CTA 섹션 ─────────────────────────────────────────
class _CollectSection extends StatelessWidget {
  final int books;
  final VoidCallback onCollect;

  const _CollectSection({required this.books, required this.onCollect});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          const Text(
            '이스터에그를 발견할 때마다 챕터가 기록됩니다.',
            style: TextStyle(fontSize: 13, color: Color(0xFF666666)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: books < 5 ? onCollect : null,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(
                books < 5 ? '(시뮬레이션) 책 한 권 획득하기' : '챕터 완성! 🎉',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3158),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFF4CAF50),
                disabledForegroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 보상 섹션 ─────────────────────────────────────────────
class _RewardSection extends StatelessWidget {
  final Color accentColor;
  final int books;

  const _RewardSection({required this.accentColor, required this.books});

  @override
  Widget build(BuildContext context) {
    return Container(
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
          const Row(
            children: [
              Text('🎁', style: TextStyle(fontSize: 18)),
              SizedBox(width: 8),
              Text('챕터 달성 보상', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1F1F1F))),
            ],
          ),
          const SizedBox(height: 16),
          _RewardItem(
            icon: Icons.card_giftcard_rounded,
            text: '책 3권 수집 시 : 서울랜드 한정 굿즈',
            unlocked: books >= 3,
            accentColor: accentColor,
          ),
          const SizedBox(height: 12),
          _RewardItem(
            icon: Icons.confirmation_number_rounded,
            text: '책 5권 수집 시 : 무료 입장권 (1매)',
            unlocked: books >= 5,
            accentColor: accentColor,
          ),
        ],
      ),
    );
  }
}

class _RewardItem extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool unlocked;
  final Color accentColor;

  const _RewardItem({
    required this.icon,
    required this.text,
    required this.unlocked,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: unlocked ? accentColor.withValues(alpha: 0.08) : const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: unlocked ? accentColor.withValues(alpha: 0.3) : const Color(0xFFEEEEEE),
        ),
      ),
      child: Row(
        children: [
          Icon(
            unlocked ? Icons.lock_open_rounded : icon,
            color: unlocked ? accentColor : const Color(0xFFBBBBBB),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: unlocked ? const Color(0xFF1F1F1F) : const Color(0xFF999999),
              ),
            ),
          ),
          if (unlocked)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('획득!', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }
}
