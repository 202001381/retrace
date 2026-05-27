import 'dart:io' as io;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/attraction.dart';

/// 아카이브 — '1일 1권' 디지털 책장.
/// 책장에 꽂힌 책 한 권 = 하루의 추억. 책등에 날짜가 각인됨.
/// 책 탭 → Dialog + PageView 3페이지 (사진/스토리/어트랙션).
class ArchiveScreen extends StatefulWidget {
  const ArchiveScreen({super.key});
  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

// ─── 시즌 / 색상 팔레트 ──────────────────────────────────
enum _Season { spring, summer, autumn, winter }

/// 빈티지 종이·가죽 톤 — 전체 화면 공통.
class _Vintage {
  static const creamBg = Color(0xFFF5EFE0);
  static const paper = Color(0xFFEDE3CC);
  static const paperLight = Color(0xFFF8F1DD);
  static const inkDark = Color(0xFF3D2817);
  static const inkMid = Color(0xFF7A5C42);
  static const leather = Color(0xFF6B4423);
  static const leatherDark = Color(0xFF4A2E18);
  static const shelfWood = Color(0xFF8B5A2B);
  static const shelfShadow = Color(0xFF5C3A21);
  static const gold = Color(0xFFB8860B);
  static const fadedRed = Color(0xFFA8485A);
}

class _SeasonConfig {
  final String label, emoji, tagline;
  final Color titleColor;
  final IconData icon;
  final List<Color> bookSpineColors;
  const _SeasonConfig({
    required this.label,
    required this.emoji,
    required this.tagline,
    required this.titleColor,
    required this.icon,
    required this.bookSpineColors,
  });
}

const Map<_Season, _SeasonConfig> _kConfigs = {
  _Season.spring: _SeasonConfig(
    label: '봄',
    emoji: '🌸',
    tagline: '벚꽃 흩날리는 봄날의 기억',
    titleColor: Color(0xFFA8485A),
    icon: Icons.local_florist_rounded,
    // 빈티지 로즈 톤
    bookSpineColors: [
      Color(0xFFA8485A),
      Color(0xFF8B3A4A),
      Color(0xFFB85C6E),
      Color(0xFF9A4054),
      Color(0xFFC97B89),
    ],
  ),
  _Season.summer: _SeasonConfig(
    label: '여름',
    emoji: '🌊',
    tagline: '눈부신 태양 아래 여름날',
    titleColor: Color(0xFF3A6A8C),
    icon: Icons.wb_sunny_rounded,
    bookSpineColors: [
      Color(0xFF3A6A8C),
      Color(0xFF2E5470),
      Color(0xFF4682B4),
      Color(0xFF1D4E5F),
      Color(0xFF5B8FA8),
    ],
  ),
  _Season.autumn: _SeasonConfig(
    label: '가을',
    emoji: '🍁',
    tagline: '단풍 물든 가을의 낭만',
    titleColor: Color(0xFFB8651E),
    icon: Icons.eco_rounded,
    bookSpineColors: [
      Color(0xFFB8651E),
      Color(0xFF8B4513),
      Color(0xFF9A6324),
      Color(0xFFA0522D),
      Color(0xFFCD7F32),
    ],
  ),
  _Season.winter: _SeasonConfig(
    label: '겨울',
    emoji: '❄️',
    tagline: '눈 내리는 겨울밤의 동화',
    titleColor: Color(0xFF4A5A6A),
    icon: Icons.ac_unit_rounded,
    bookSpineColors: [
      Color(0xFF4A5A6A),
      Color(0xFF6B7A8C),
      Color(0xFF5F7080),
      Color(0xFF3D4A56),
      Color(0xFF829AAD),
    ],
  ),
};

// ─── 데이터 모델 ─────────────────────────────────────────
/// 하루 한 권의 일기. 백엔드 붙으면 GET /api/diary/books 로 교체.
class _DiaryBook {
  final String id;
  final DateTime date;
  final String title;
  final String story;
  final List<String> attractionIds;
  final String fallbackEmoji; // 사진 업로드 전 placeholder.
  const _DiaryBook({
    required this.id,
    required this.date,
    required this.title,
    required this.story,
    required this.attractionIds,
    required this.fallbackEmoji,
  });
}

// ─── 사진 영속 저장소 ────────────────────────────────────
/// 책 id → 로컬 사진 경로. SharedPreferences 에 책 ID 별로 저장.
/// 웹에서는 path 가 blob URL — 새로고침 시 무효화될 수 있음 (프로토타입 한정).
class _PhotoStore {
  static const _kPrefix = 'diary_photo_';
  static final Map<String, String> _cache = {};

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys()) {
      if (key.startsWith(_kPrefix)) {
        final id = key.substring(_kPrefix.length);
        final v = prefs.getString(key);
        if (v != null) _cache[id] = v;
      }
    }
  }

  static String? photoOf(String bookId) => _cache[bookId];

  static Future<void> setPhoto(String bookId, String path) async {
    _cache[bookId] = path;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_kPrefix$bookId', path);
  }

  static Future<void> remove(String bookId) async {
    _cache.remove(bookId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_kPrefix$bookId');
  }
}

// ─── 메인 화면 ───────────────────────────────────────────
class _ArchiveScreenState extends State<ArchiveScreen> {
  _Season _season = _Season.spring;
  bool _ready = false;

  late final Map<_Season, List<_DiaryBook>> _diaries = _buildMockDiaries();

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _PhotoStore.load();
    if (!mounted) return;
    setState(() => _ready = true);
  }

  void _openDiary(int index) {
    showGeneralDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      barrierDismissible: true,
      barrierLabel: '닫기',
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (ctx, anim, secAnim) {
        return _DiaryDialog(
          config: _kConfigs[_season]!,
          books: _diaries[_season]!,
          initialBookIndex: index,
          onPhotoChanged: () => setState(() {}),
        );
      },
      transitionBuilder: (ctx, anim, secAnim, child) {
        // 스케일 + 페이드로 책이 열리는 듯한 트랜지션.
        final curve = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curve,
          child: ScaleTransition(
            scale: Tween(begin: 0.92, end: 1.0).animate(curve),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = _kConfigs[_season]!;
    final books = _diaries[_season]!;
    if (!_ready) {
      return const ColoredBox(
        color: _Vintage.creamBg,
        child: Center(
          child: CircularProgressIndicator(color: _Vintage.leather),
        ),
      );
    }
    return ColoredBox(
      color: _Vintage.creamBg,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(season: _season, onChange: (s) => setState(() => _season = s)),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                children: [
                  _SeasonBanner(config: config),
                  const SizedBox(height: 24),
                  _Bookshelf(
                    config: config,
                    books: books,
                    onBookTap: _openDiary,
                  ),
                  const SizedBox(height: 24),
                  _DiaryStats(books: books, config: config),
                  const SizedBox(height: 24),
                  _PaperHint(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 목업 데이터 ────────────────────────────────────────
  static Map<_Season, List<_DiaryBook>> _buildMockDiaries() {
    return {
      _Season.spring: [
        _DiaryBook(
          id: 'spring_001',
          date: DateTime(2026, 4, 14, 14, 30),
          title: '벚꽃 흩날리던 첫 봄나들이',
          story:
              '벚꽃이 만개한 4월의 오후, 친구들과 손을 잡고 걸었던 그 길. 바람이 불 때마다 머리 위로 꽃잎이 쏟아져 내렸어요. '
              '카메라를 꺼낼 새도 없이 그 순간이 너무 빠르게 지나가서, 결국엔 눈에 담는 것으로 만족했답니다.',
          attractionIds: const ['cherry_blossom_path', 'carousel'],
          fallbackEmoji: '🌸',
        ),
        _DiaryBook(
          id: 'spring_002',
          date: DateTime(2026, 4, 21, 11, 15),
          title: '회전목마 위의 동심',
          story:
              '어릴 적 엄마 손을 잡고 처음 탔던 회전목마. 어른이 되어 다시 올라타니 그 시절의 설렘이 그대로 떠올랐어요. '
              '음악도, 조명도, 거울에 비친 풍경도 모두 그대로였답니다.',
          attractionIds: const ['carousel'],
          fallbackEmoji: '🎠',
        ),
        _DiaryBook(
          id: 'spring_003',
          date: DateTime(2026, 4, 28, 13, 0),
          title: '비 오는 날의 실내 어드벤처',
          story:
              '오전부터 부슬비가 내렸어요. 야외 어트랙션은 포기하고 실내 위주로 즐긴 날. '
              '오히려 사람이 적어서 여유롭게 다닐 수 있었어요.',
          attractionIds: const ['bumper_car', 'time_machine_5d'],
          fallbackEmoji: '☔',
        ),
        _DiaryBook(
          id: 'spring_004',
          date: DateTime(2026, 5, 5, 12, 0),
          title: '어린이날, 가족 총출동',
          story:
              '온 가족이 다 모인 어린이날. 조카들이 처음 타본 미니바이킹에서 환하게 웃던 그 표정, 평생 기억에 남을 것 같아요.',
          attractionIds: const ['mini_viking', 'carousel'],
          fallbackEmoji: '👨‍👩‍👧‍👦',
        ),
        _DiaryBook(
          id: 'spring_005',
          date: DateTime(2026, 5, 18, 15, 20),
          title: '봄의 마지막 킹바이킹',
          story:
              '이제 곧 여름이 온다는 게 실감 나는 5월 중순. 마지막 봄나들이로 친구들과 킹바이킹을 탔어요. '
              '비명소리가 너무 컸는지 옆 사람들이 다 웃었어요.',
          attractionIds: const ['viking'],
          fallbackEmoji: '🏴‍☠️',
        ),
      ],
      _Season.summer: [
        _DiaryBook(
          id: 'summer_001',
          date: DateTime(2025, 6, 10, 14, 0),
          title: '급류타기의 시원함',
          story:
              '6월 초인데 벌써 무더웠어요. 첫 라이드로 고른 급류타기. 물벼락에 옷이 다 젖었지만 그 시원함은 잊을 수 없어요.',
          attractionIds: const ['flume_ride'],
          fallbackEmoji: '🌊',
        ),
        _DiaryBook(
          id: 'summer_002',
          date: DateTime(2025, 7, 4, 19, 30),
          title: '한여름 야간 개장의 매력',
          story:
              '해가 진 후의 서울랜드는 완전 다른 분위기예요. 낮엔 봐도 그냥 지나치던 조명들이 모두 살아 움직였어요.',
          attractionIds: const ['galaxy_888', 'carousel'],
          fallbackEmoji: '🌃',
        ),
        _DiaryBook(
          id: 'summer_003',
          date: DateTime(2025, 7, 20, 13, 30),
          title: '스카이엑스에서 본 여름 하늘',
          story:
              '70m 상공에서 떨어지던 그 순간, 시간이 멈춘 듯했어요. 떨어지는 동안 본 푸른 여름 하늘이 잊혀지지 않아요.',
          attractionIds: const ['sky_x'],
          fallbackEmoji: '🪂',
        ),
        _DiaryBook(
          id: 'summer_004',
          date: DateTime(2025, 8, 5, 15, 10),
          title: '에어컨 빵빵 실내 범퍼카',
          story:
              '38도 폭염을 피해 실내 범퍼카로 도망. 한 시간 동안 5번이나 다시 줄을 섰답니다.',
          attractionIds: const ['bumper_car'],
          fallbackEmoji: '🚗',
        ),
        _DiaryBook(
          id: 'summer_005',
          date: DateTime(2025, 8, 20, 16, 0),
          title: '여름의 끝, 샷드롭',
          story:
              '발사되는 순간의 그 무중력감. 옆 사람이 비명을 지르고, 나도 모르게 따라 질렀어요. 다리가 후들거리는 채로 카메라를 보며 웃었어요.',
          attractionIds: const ['shot_drop'],
          fallbackEmoji: '🚀',
        ),
      ],
      _Season.autumn: [
        _DiaryBook(
          id: 'autumn_001',
          date: DateTime(2025, 9, 15, 14, 20),
          title: '가을의 시작, 은하열차',
          story:
              '아직 단풍은 들지 않았지만 바람이 선선해진 9월 중순. 은하열차의 바람을 가르는 속도감이 가을과 잘 어울렸어요.',
          attractionIds: const ['galaxy_888'],
          fallbackEmoji: '🎢',
        ),
        _DiaryBook(
          id: 'autumn_002',
          date: DateTime(2025, 10, 5, 13, 0),
          title: '블랙홀 2000의 어둠',
          story:
              '어둠 속에서 회전하던 그 순간, 방향감을 완전히 잃었어요. 출구로 나와 친구와 마주보며 웃었던 그 표정.',
          attractionIds: const ['blackhole_2000'],
          fallbackEmoji: '🌀',
        ),
        _DiaryBook(
          id: 'autumn_003',
          date: DateTime(2025, 10, 18, 15, 30),
          title: '단풍 사이의 알포스윙',
          story:
              '360도 회전하며 거꾸로 본 가을 하늘과 단풍. 무섭다고 했지만 다시 타고 싶다고 했던 그 모순.',
          attractionIds: const ['gyro_swing'],
          fallbackEmoji: '🎡',
        ),
        _DiaryBook(
          id: 'autumn_004',
          date: DateTime(2025, 10, 25, 16, 10),
          title: '가을 야경 데이트',
          story:
              '단풍이 절정이던 날, 둘이서 천천히 걸으며 본 풍경. 시간이 멈췄으면 좋겠다 싶었어요.',
          attractionIds: const ['shot_drop', 'galaxy_888'],
          fallbackEmoji: '🍁',
        ),
        _DiaryBook(
          id: 'autumn_005',
          date: DateTime(2025, 11, 2, 17, 0),
          title: '가을의 마지막 바이킹',
          story:
              '시즌이 끝나기 전 마지막 바이킹. 흩날리는 낙엽 사이로 흔들렸던 그 순간이 올 가을의 마침표였어요.',
          attractionIds: const ['viking'],
          fallbackEmoji: '⚓',
        ),
      ],
      _Season.winter: [
        _DiaryBook(
          id: 'winter_001',
          date: DateTime(2024, 12, 24, 18, 30),
          title: '눈 내리는 회전목마',
          story:
              '함박눈이 내리던 12월 24일 저녁, 조명이 켜진 회전목마. 한 폭의 동화 같았던 그 풍경을 잊을 수 없어요.',
          attractionIds: const ['carousel'],
          fallbackEmoji: '🎄',
        ),
        _DiaryBook(
          id: 'winter_002',
          date: DateTime(2025, 1, 1, 13, 0),
          title: '새해 첫날, 타임머신 5D',
          story:
              '새해 첫날 가족과 함께 본 5D 영상. 미래의 한 장면 같았던 그 경험이 새해의 시작을 특별하게 만들어줬어요.',
          attractionIds: const ['time_machine_5d'],
          fallbackEmoji: '🎬',
        ),
        _DiaryBook(
          id: 'winter_003',
          date: DateTime(2025, 1, 18, 14, 30),
          title: '눈 오는 날의 실내 범퍼카',
          story:
              '바깥은 영하인데 실내는 따뜻하고 신났어요. 친구 5명이서 단체로 부딪치며 깔깔 웃었던 시간.',
          attractionIds: const ['bumper_car'],
          fallbackEmoji: '🚗',
        ),
        _DiaryBook(
          id: 'winter_004',
          date: DateTime(2025, 1, 25, 19, 0),
          title: '산타레스토랑의 따뜻함',
          story:
              '추운 날 산타레스토랑에서 먹었던 따뜻한 한 끼. 창밖에 눈이 내리고, 안에서는 캐롤이 흘러나오던 그 순간.',
          attractionIds: const ['santa_restaurant'],
          fallbackEmoji: '🎅',
        ),
        _DiaryBook(
          id: 'winter_005',
          date: DateTime(2025, 2, 14, 16, 0),
          title: '발렌타인 블랙홀 챌린지',
          story:
              '함께 견뎌낸 블랙홀의 어둠. 끝나고 나니 마음이 더 가까워진 느낌.',
          attractionIds: const ['blackhole_2000'],
          fallbackEmoji: '💝',
        ),
      ],
    };
  }
}

// ─── 헤더 (시즌 탭) ──────────────────────────────────────
class _Header extends StatelessWidget {
  final _Season season;
  final ValueChanged<_Season> onChange;
  const _Header({required this.season, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _Vintage.paperLight,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.auto_stories_rounded, color: _Vintage.leather, size: 26),
              SizedBox(width: 8),
              Text(
                'Retrace Archive',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: _Vintage.inkDark,
                  letterSpacing: 0.5,
                ),
              ),
              Spacer(),
              Text('📖', style: TextStyle(fontSize: 22)),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            '하루 한 권. 그날의 추억을 책에 담아 책장에 꽂아두세요.',
            style: TextStyle(
              fontSize: 12,
              color: _Vintage.inkMid,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: _Vintage.paper,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: _Vintage.leather.withOpacity(0.2)),
            ),
            child: Row(
              children: _Season.values
                  .map((s) => Expanded(
                        child: GestureDetector(
                          onTap: () => onChange(s),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOut,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: season == s ? _Vintage.leather : Colors.transparent,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              _kConfigs[s]!.label,
                              style: TextStyle(
                                color: season == s ? _Vintage.creamBg : _Vintage.inkMid,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 시즌 배너 ───────────────────────────────────────────
class _SeasonBanner extends StatelessWidget {
  final _SeasonConfig config;
  const _SeasonBanner({required this.config});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _Vintage.paperLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _Vintage.leather.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: _Vintage.leatherDark.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: config.titleColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(config.icon, color: config.titleColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${config.label} 챕터',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: config.titleColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  config.tagline,
                  style: const TextStyle(
                    fontSize: 12,
                    color: _Vintage.inkMid,
                    fontWeight: FontWeight.w600,
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

// ─── 책장 (가죽 + 나무 선반) ─────────────────────────────
class _Bookshelf extends StatelessWidget {
  final _SeasonConfig config;
  final List<_DiaryBook> books;
  final void Function(int index) onBookTap;
  const _Bookshelf({
    required this.config,
    required this.books,
    required this.onBookTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              const Icon(Icons.menu_book_rounded,
                  size: 16, color: _Vintage.leather),
              const SizedBox(width: 6),
              const Text(
                '기억의 책장',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: _Vintage.inkDark,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _Vintage.paperLight,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: _Vintage.leather.withOpacity(0.2)),
                ),
                child: Text(
                  '${books.length} 권',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: _Vintage.leather,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // 책장 본체 — 가죽 등판 + 나무 선반
        Container(
          decoration: BoxDecoration(
            color: _Vintage.shelfWood,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: _Vintage.leatherDark.withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
          child: Column(
            children: [
              SizedBox(
                height: 160,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(books.length, (i) {
                    final color = config.bookSpineColors[i % config.bookSpineColors.length];
                    return _BookSpine(
                      book: books[i],
                      color: color,
                      onTap: () => onBookTap(i),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 10),
              // 선반 바닥 (어두운 나무 결)
              Container(
                height: 12,
                decoration: const BoxDecoration(
                  color: _Vintage.shelfShadow,
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(6)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── 책등 ────────────────────────────────────────────────
class _BookSpine extends StatelessWidget {
  final _DiaryBook book;
  final Color color;
  final VoidCallback onTap;
  const _BookSpine({
    required this.book,
    required this.color,
    required this.onTap,
  });

  String get _spineDate {
    final y = book.date.year.toString();
    final m = book.date.month.toString().padLeft(2, '0');
    final d = book.date.day.toString().padLeft(2, '0');
    return '$y.$m.$d';
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = _PhotoStore.photoOf(book.id) != null;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutBack,
        builder: (context, t, child) {
          return Transform.translate(
            offset: Offset(0, (1 - t) * 12),
            child: Opacity(opacity: t, child: child),
          );
        },
        child: Container(
          width: 46,
          height: 150,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color, Color.lerp(color, Colors.black, 0.25)!],
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(2),
              topRight: Radius.circular(2),
            ),
            border: const Border(
              left: BorderSide(color: Colors.white24, width: 2),
              top: BorderSide(color: Colors.black26, width: 1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 5,
                offset: const Offset(2, 2),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 책등 상하단 금박 라인
              Positioned(
                top: 8,
                child: Container(
                  width: 30, height: 1,
                  color: _Vintage.gold.withOpacity(0.7),
                ),
              ),
              Positioned(
                bottom: 30,
                child: Container(
                  width: 30, height: 1,
                  color: _Vintage.gold.withOpacity(0.7),
                ),
              ),
              // 세로 날짜 각인
              RotatedBox(
                quarterTurns: 3,
                child: Text(
                  _spineDate,
                  style: TextStyle(
                    color: _Vintage.gold.withOpacity(0.95),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ),
              // 사진 업로드 표시 (책등 하단 작은 점)
              if (hasPhoto)
                Positioned(
                  bottom: 10,
                  child: Container(
                    width: 6, height: 6,
                    decoration: const BoxDecoration(
                      color: _Vintage.gold,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── 다이어리 다이얼로그 (PageView 3 페이지) ──────────────
class _DiaryDialog extends StatefulWidget {
  final _SeasonConfig config;
  final List<_DiaryBook> books;
  final int initialBookIndex;
  final VoidCallback onPhotoChanged;
  const _DiaryDialog({
    required this.config,
    required this.books,
    required this.initialBookIndex,
    required this.onPhotoChanged,
  });

  @override
  State<_DiaryDialog> createState() => _DiaryDialogState();
}

class _DiaryDialogState extends State<_DiaryDialog> {
  late int _bookIndex;
  late PageController _pageCtrl;
  int _pageIndex = 0;

  @override
  void initState() {
    super.initState();
    _bookIndex = widget.initialBookIndex;
    _pageCtrl = PageController();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  _DiaryBook get _book => widget.books[_bookIndex];

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (file == null) return;
      await _PhotoStore.setPhoto(_book.id, file.path);
      if (!mounted) return;
      setState(() {});
      widget.onPhotoChanged();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('사진을 가져오지 못했어요: $e')),
      );
    }
  }

  void _goPrevBook() {
    if (_bookIndex == 0) return;
    setState(() {
      _bookIndex--;
      _pageIndex = 0;
    });
    _pageCtrl.jumpToPage(0);
  }

  void _goNextBook() {
    if (_bookIndex >= widget.books.length - 1) return;
    setState(() {
      _bookIndex++;
      _pageIndex = 0;
    });
    _pageCtrl.jumpToPage(0);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 책 한 권 비율 — 모바일에선 세로형, 작은 화면도 잘 맞춤.
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOutCubic,
            child: Container(
              key: ValueKey(_book.id),
              decoration: BoxDecoration(
                color: _Vintage.paperLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _Vintage.leather.withOpacity(0.3), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: Column(
                  children: [
                    _DialogTopBar(
                      config: widget.config,
                      bookIndex: _bookIndex + 1,
                      totalBooks: widget.books.length,
                      onPrev: _bookIndex > 0 ? _goPrevBook : null,
                      onNext: _bookIndex < widget.books.length - 1 ? _goNextBook : null,
                      onClose: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: PageView(
                        controller: _pageCtrl,
                        onPageChanged: (i) => setState(() => _pageIndex = i),
                        children: [
                          _PagePhoto(
                            book: _book,
                            config: widget.config,
                            onPickGallery: () => _pickPhoto(ImageSource.gallery),
                            onPickCamera: () => _pickPhoto(ImageSource.camera),
                            onRemovePhoto: () async {
                              await _PhotoStore.remove(_book.id);
                              if (!mounted) return;
                              setState(() {});
                              widget.onPhotoChanged();
                            },
                          ),
                          _PageStory(book: _book, config: widget.config),
                          _PageAttraction(book: _book, config: widget.config),
                        ],
                      ),
                    ),
                    _PageIndicator(current: _pageIndex, total: 3),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DialogTopBar extends StatelessWidget {
  final _SeasonConfig config;
  final int bookIndex;
  final int totalBooks;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final VoidCallback onClose;
  const _DialogTopBar({
    required this.config,
    required this.bookIndex,
    required this.totalBooks,
    required this.onPrev,
    required this.onNext,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: _Vintage.leather,
        border: Border(
          bottom: BorderSide(color: _Vintage.gold.withOpacity(0.4), width: 1),
        ),
      ),
      child: Row(
        children: [
          _IconBtn(
            icon: Icons.chevron_left_rounded,
            onTap: onPrev,
            enabled: onPrev != null,
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${config.label} CHAPTER',
                    style: TextStyle(
                      color: _Vintage.gold.withOpacity(0.9),
                      fontSize: 9,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    '$bookIndex / $totalBooks',
                    style: const TextStyle(
                      color: _Vintage.creamBg,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
          _IconBtn(
            icon: Icons.chevron_right_rounded,
            onTap: onNext,
            enabled: onNext != null,
          ),
          const SizedBox(width: 4),
          _IconBtn(
            icon: Icons.close_rounded,
            onTap: onClose,
            enabled: true,
          ),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool enabled;
  const _IconBtn({required this.icon, required this.onTap, required this.enabled});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.25,
      child: InkResponse(
        onTap: enabled ? onTap : null,
        radius: 20,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, color: _Vintage.creamBg, size: 22),
        ),
      ),
    );
  }
}

// ─── 페이지 1: 사진 + 날짜 (폴라로이드) ─────────────────────
class _PagePhoto extends StatelessWidget {
  final _DiaryBook book;
  final _SeasonConfig config;
  final VoidCallback onPickGallery;
  final VoidCallback onPickCamera;
  final VoidCallback onRemovePhoto;
  const _PagePhoto({
    required this.book,
    required this.config,
    required this.onPickGallery,
    required this.onPickCamera,
    required this.onRemovePhoto,
  });

  String _formatDate(DateTime d) {
    final wd = const ['일', '월', '화', '수', '목', '금', '토'][d.weekday % 7];
    return '${d.year}년 ${d.month}월 ${d.day}일 ($wd요일)';
  }

  @override
  Widget build(BuildContext context) {
    final photoPath = _PhotoStore.photoOf(book.id);
    return Container(
      color: _Vintage.paperLight,
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
      child: Column(
        children: [
          Text(
            _formatDate(book.date),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: config.titleColor,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            book.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: _Vintage.inkDark,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 20),
          // 폴라로이드
          Expanded(
            child: Center(
              child: _Polaroid(
                photoPath: photoPath,
                fallbackEmoji: book.fallbackEmoji,
                caption: '${book.date.month}.${book.date.day}',
              ),
            ),
          ),
          const SizedBox(height: 14),
          // 업로드 / 변경 버튼
          if (photoPath == null)
            Row(
              children: [
                Expanded(
                  child: _PhotoActionBtn(
                    icon: Icons.photo_library_rounded,
                    label: '갤러리에서 선택',
                    onTap: onPickGallery,
                    primary: true,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PhotoActionBtn(
                    icon: Icons.camera_alt_rounded,
                    label: '직접 촬영',
                    onTap: onPickCamera,
                    primary: false,
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: _PhotoActionBtn(
                    icon: Icons.edit_rounded,
                    label: '사진 변경',
                    onTap: onPickGallery,
                    primary: true,
                  ),
                ),
                const SizedBox(width: 10),
                _PhotoActionBtn(
                  icon: Icons.delete_outline_rounded,
                  label: '삭제',
                  onTap: onRemovePhoto,
                  primary: false,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Polaroid extends StatelessWidget {
  final String? photoPath;
  final String fallbackEmoji;
  final String caption;
  const _Polaroid({
    required this.photoPath,
    required this.fallbackEmoji,
    required this.caption,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.035, // 약 -2도 비스듬히
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 14,
              offset: const Offset(4, 8),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 사진 영역
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: AspectRatio(
                aspectRatio: 1,
                child: photoPath == null
                    ? Container(
                        color: _Vintage.paper,
                        alignment: Alignment.center,
                        child: Text(
                          fallbackEmoji,
                          style: const TextStyle(fontSize: 72),
                        ),
                      )
                    : SizedBox.expand(
                        child: _NetworkOrFileImage(path: photoPath!),
                      ),
              ),
            ),
            const SizedBox(height: 14),
            // 캡션 (손글씨 느낌)
            SizedBox(
              height: 32,
              child: Center(
                child: Text(
                  caption,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _Vintage.inkMid,
                    fontStyle: FontStyle.italic,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 웹/모바일 분기. 웹은 blob URL → Image.network, 모바일은 Image.file.
class _NetworkOrFileImage extends StatelessWidget {
  final String path;
  const _NetworkOrFileImage({required this.path});

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _broken(),
      );
    }
    return Image.file(
      io.File(path),
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _broken(),
    );
  }

  Widget _broken() => Container(
        color: _Vintage.paper,
        alignment: Alignment.center,
        child: const Icon(Icons.broken_image_rounded,
            color: _Vintage.inkMid, size: 32),
      );
}

class _PhotoActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;
  const _PhotoActionBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16),
        label: Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: primary ? _Vintage.leather : _Vintage.paper,
          foregroundColor: primary ? _Vintage.creamBg : _Vintage.inkDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 0,
          side: BorderSide(
            color: primary ? Colors.transparent : _Vintage.leather.withOpacity(0.3),
          ),
        ),
      ),
    );
  }
}

// ─── 페이지 2: 스토리 + 기록 시간 ────────────────────────
class _PageStory extends StatelessWidget {
  final _DiaryBook book;
  final _SeasonConfig config;
  const _PageStory({required this.book, required this.config});

  String _formatDateTime(DateTime d) {
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')} · $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _Vintage.paperLight,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.edit_note_rounded, size: 18, color: config.titleColor),
              const SizedBox(width: 6),
              Text(
                '그날의 이야기',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: config.titleColor,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _Vintage.paper,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _formatDateTime(book.date),
                  style: const TextStyle(
                    fontSize: 10,
                    color: _Vintage.inkMid,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            book.title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: _Vintage.inkDark,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 14),
          // 종이 줄 라인 효과
          Expanded(
            child: SingleChildScrollView(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _Vintage.paper.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(6),
                  border: Border(
                    left: BorderSide(color: _Vintage.fadedRed, width: 2),
                  ),
                ),
                child: Text(
                  book.story,
                  style: const TextStyle(
                    fontSize: 14,
                    color: _Vintage.inkDark,
                    height: 1.8,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 페이지 3: 어트랙션 + 위치 ───────────────────────────
class _PageAttraction extends StatelessWidget {
  final _DiaryBook book;
  final _SeasonConfig config;
  const _PageAttraction({required this.book, required this.config});

  List<Attraction> get _attractions {
    final byId = {for (final a in kAttractions) a.id: a};
    return book.attractionIds
        .map((id) => byId[id])
        .whereType<Attraction>()
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final attrs = _attractions;
    return Container(
      color: _Vintage.paperLight,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.place_rounded, size: 18, color: config.titleColor),
              const SizedBox(width: 6),
              Text(
                '그날 방문한 곳',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: config.titleColor,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              Text(
                '${attrs.length} 곳',
                style: const TextStyle(
                  fontSize: 11,
                  color: _Vintage.inkMid,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: attrs.isEmpty
                ? const Center(
                    child: Text(
                      '기록된 어트랙션이 없어요',
                      style: TextStyle(color: _Vintage.inkMid, fontSize: 12),
                    ),
                  )
                : ListView.separated(
                    itemCount: attrs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _AttractionCard(
                      attraction: attrs[i],
                      accent: config.titleColor,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _AttractionCard extends StatelessWidget {
  final Attraction attraction;
  final Color accent;
  const _AttractionCard({required this.attraction, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _Vintage.leather.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(attraction.icon, style: const TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      attraction.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: _Vintage.inkDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${attraction.category} · ${attraction.zone}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: _Vintage.inkMid,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _Vintage.paper.withOpacity(0.6),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                const Icon(Icons.my_location_rounded,
                    size: 12, color: _Vintage.inkMid),
                const SizedBox(width: 6),
                Text(
                  '${attraction.lat.toStringAsFixed(4)}, ${attraction.lng.toStringAsFixed(4)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: _Vintage.inkMid,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (attraction.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              attraction.description,
              style: const TextStyle(
                fontSize: 12,
                color: _Vintage.inkMid,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── 페이지 인디케이터 ────────────────────────────────────
class _PageIndicator extends StatelessWidget {
  final int current;
  final int total;
  const _PageIndicator({required this.current, required this.total});

  static const _kLabels = ['사진', '이야기', '장소'];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _Vintage.paper,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(total, (i) {
          final active = i == current;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  width: active ? 20 : 8,
                  height: 4,
                  decoration: BoxDecoration(
                    color: active ? _Vintage.leather : _Vintage.leather.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _kLabels[i],
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: active ? _Vintage.leather : _Vintage.inkMid,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

// ─── 통계 카드 ───────────────────────────────────────────
class _DiaryStats extends StatelessWidget {
  final List<_DiaryBook> books;
  final _SeasonConfig config;
  const _DiaryStats({required this.books, required this.config});

  @override
  Widget build(BuildContext context) {
    final withPhotos = books.where((b) => _PhotoStore.photoOf(b.id) != null).length;
    final firstDate = books.isEmpty ? null : books.first.date;
    final lastDate = books.isEmpty ? null : books.last.date;

    String fmt(DateTime? d) {
      if (d == null) return '-';
      return '${d.month}.${d.day}';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _Vintage.paperLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _Vintage.leather.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatItem(
              label: '수집한 추억',
              value: '${books.length}',
              unit: '권',
              color: config.titleColor,
            ),
          ),
          Container(
              width: 1, height: 36, color: _Vintage.leather.withOpacity(0.15)),
          Expanded(
            child: _StatItem(
              label: '사진 첨부',
              value: '$withPhotos',
              unit: '권',
              color: config.titleColor,
            ),
          ),
          Container(
              width: 1, height: 36, color: _Vintage.leather.withOpacity(0.15)),
          Expanded(
            child: _StatItem(
              label: '기록 기간',
              value: '${fmt(firstDate)}~${fmt(lastDate)}',
              unit: '',
              color: config.titleColor,
              compact: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label, value, unit;
  final Color color;
  final bool compact;
  const _StatItem({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: compact ? 13 : 20,
                fontWeight: FontWeight.w900,
                color: color,
                letterSpacing: -0.2,
              ),
            ),
            if (unit.isNotEmpty) ...[
              const SizedBox(width: 2),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  unit,
                  style: const TextStyle(
                    fontSize: 10,
                    color: _Vintage.inkMid,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: _Vintage.inkMid,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ─── 안내 ────────────────────────────────────────────────
class _PaperHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _Vintage.paper.withOpacity(0.6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: _Vintage.leather.withOpacity(0.2),
            style: BorderStyle.solid),
      ),
      child: Row(
        children: const [
          Icon(Icons.tips_and_updates_rounded,
              color: _Vintage.gold, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '책을 터치해 그날의 일기를 펼쳐보세요. 사진을 추가하면 책등에 금빛 점이 빛나요 ✨',
              style: TextStyle(
                fontSize: 11,
                color: _Vintage.inkMid,
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
