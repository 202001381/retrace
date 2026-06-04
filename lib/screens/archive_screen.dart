import 'dart:io' as io;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/attraction.dart';
import '../services/easter_egg_service.dart';

/// 아카이브 — '일일 탐험 매거진' 컨셉.
///   · 방문 날짜 하나당 단 한 권의 책 (date = 고유키).
///   · 사진은 옵션 — 없으면 빈티지 스탬프/일러스트, 있으면 폴라로이드 레이어.
///   · 표지/탐험일지/추억의 장 3페이지 PageView.
class ArchiveScreen extends StatefulWidget {
  const ArchiveScreen({super.key});
  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

// ─── 시즌 ────────────────────────────────────────────────
enum _Season { spring, summer, autumn, winter }

// ─── 빈티지 팔레트 ───────────────────────────────────────
/// v3 — vintage "brown leather" 톤에서 cream paper + 빨간 액센트로 전환.
/// 책장 plank만 따뜻한 우디 톤(shelfWood) 유지, 나머지는 백색/크림.
class _Vintage {
  static const parchmentLight = Color(0xFFFFFFFF); // 거의 흰색 (시안 11 BG)
  static const parchment = Color(0xFFFAFAF8);     // bgCardWarm
  static const parchmentDark = Color(0xFFF4F1EA); // 미세 cream
  static const inkDark = Color(0xFF111111);       // ink900
  static const inkBody = Color(0xFF333333);       // ink700
  static const inkMid = Color(0xFF707070);        // ink500
  static const leather = Color(0xFF8A6300);       // 옅은 brown (eyebrow 용)
  static const gold = Color(0xFFC99500);
  static const stampRed = Color(0xFFE60023);      // 브랜드 레드
  static const stampInk = Color(0xFF111111);
}

/// 아카이브 본문 공용 텍스트 헬퍼 — theme default (Pretendard fallback system sans)
/// 를 그대로 inherit. fontFamily 명시는 절대 금지 (기기에 번들 안 된 폰트 명시 →
/// iOS 가 Times 류 세리프 폴백 골라 톤 깨짐).
TextStyle _serif({
  double size = 14,
  FontWeight weight = FontWeight.w500,
  Color color = _Vintage.inkBody,
  double height = 1.5,
  double letterSpacing = 0,
  FontStyle? style,
}) =>
    TextStyle(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
      fontStyle: style,
    );

/// v3 시즌별 spine 팔레트 — 스파인 컬러 + 텍스트 컬러 쌍.
class _SpinePalette {
  final Color spine;
  final Color text;
  const _SpinePalette(this.spine, this.text);
}

/// ko/en 페어 (Archive 데모 시드 데이터 영문화 — 별도 ARB 키 안 만들고 인라인 페어).
class _LocPair {
  final String ko;
  final String en;
  const _LocPair(this.ko, this.en);
  String of(BuildContext ctx) =>
      Localizations.localeOf(ctx).languageCode == 'en' ? en : ko;
}

class _SeasonConfig {
  final _LocPair label;
  final _LocPair tagline;
  final Color titleColor;     // chapter eyebrow 대표 컬러 (브랜드 톤)
  final Color accentColor;    // 시안 def.accent — chapter eyebrow 소프트 컬러
  final Color bgColor;        // shelf 내부 옅은 시즌 BG
  final Color plankTop;       // plank 그라디언트 위
  final Color plankBottom;    // plank 그라디언트 아래
  final Color dotColor;       // 시즌 탭 dot
  final IconData icon;
  final List<_SpinePalette> spines;
  const _SeasonConfig({
    required this.label,
    required this.tagline,
    required this.titleColor,
    required this.accentColor,
    required this.bgColor,
    required this.plankTop,
    required this.plankBottom,
    required this.dotColor,
    required this.icon,
    required this.spines,
  });
}

const Map<_Season, _SeasonConfig> _kConfigs = {
  _Season.spring: _SeasonConfig(
    label: _LocPair('봄', 'Spring'),
    tagline: _LocPair('벚꽃 흩날리는 봄날', 'Cherry blossoms in the breeze'),
    titleColor: Color(0xFFE60023),
    accentColor: Color(0xFFE89AB0),
    bgColor: Color(0xFFFDEFF2),
    plankTop: Color(0xFFE8C7CC),
    plankBottom: Color(0xFFBC8A91),
    dotColor: Color(0xFFF4A4B7),
    icon: Icons.local_florist_rounded,
    spines: [
      _SpinePalette(Color(0xFFE89AB0), Color(0xFFFFF5F0)), // cherry pink
      _SpinePalette(Color(0xFFB8D8E8), Color(0xFF1A3A4A)), // pale sky
      _SpinePalette(Color(0xFFF4D88A), Color(0xFF5A4015)), // soft yellow
      _SpinePalette(Color(0xFFA8D8C0), Color(0xFF1A4A35)), // fresh mint
      _SpinePalette(Color(0xFFF5EBD8), Color(0xFF8A5A2A)), // cream
    ],
  ),
  _Season.summer: _SeasonConfig(
    label: _LocPair('여름', 'Summer'),
    tagline: _LocPair('바다 냄새 나는 여름', 'Salt air, sun-bleached afternoons'),
    titleColor: Color(0xFF0084E0),
    accentColor: Color(0xFF1F8FB0),
    bgColor: Color(0xFFE5F4F9),
    plankTop: Color(0xFFB5D5DD),
    plankBottom: Color(0xFF6B9AA8),
    dotColor: Color(0xFF39B5D6),
    icon: Icons.wb_sunny_rounded,
    spines: [
      _SpinePalette(Color(0xFF1F5A6E), Color(0xFFE8F0E5)), // deep teal
      _SpinePalette(Color(0xFFFF6B5A), Color(0xFFFFF5F0)), // coral
      _SpinePalette(Color(0xFF39B5D6), Color(0xFFFFFFFF)), // bright sky
      _SpinePalette(Color(0xFF88C04A), Color(0xFF1A2A0A)), // lime
      _SpinePalette(Color(0xFFF5C84A), Color(0xFF3A2400)), // sun yellow
    ],
  ),
  _Season.autumn: _SeasonConfig(
    label: _LocPair('가을', 'Autumn'),
    tagline: _LocPair('단풍이 깊어가는 가을', 'Maples burning red, the year tipping over'),
    titleColor: Color(0xFF8A6300),
    accentColor: Color(0xFFB5491E),
    bgColor: Color(0xFFFAF0E2),
    plankTop: Color(0xFFD2B080),
    plankBottom: Color(0xFF8C6B3F),
    dotColor: Color(0xFFC9A04A),
    icon: Icons.eco_rounded,
    spines: [
      _SpinePalette(Color(0xFFB5491E), Color(0xFFFFF1DC)), // burnt orange
      _SpinePalette(Color(0xFF6B4423), Color(0xFFF4D88A)), // dark brown
      _SpinePalette(Color(0xFFC9A04A), Color(0xFF3A2A0A)), // mustard
      _SpinePalette(Color(0xFF7A2828), Color(0xFFF4D88A)), // wine
      _SpinePalette(Color(0xFFA05E2C), Color(0xFFFFF5E8)), // amber
    ],
  ),
  _Season.winter: _SeasonConfig(
    label: _LocPair('겨울', 'Winter'),
    tagline: _LocPair('눈 내리는 고요한 겨울', 'Quiet winter, snow falling all evening'),
    titleColor: Color(0xFF1F2A44),
    accentColor: Color(0xFF2A4A6E),
    bgColor: Color(0xFFEAEFF5),
    plankTop: Color(0xFFBCC8D6),
    plankBottom: Color(0xFF6E7E92),
    dotColor: Color(0xFF85A8C4),
    icon: Icons.ac_unit_rounded,
    spines: [
      _SpinePalette(Color(0xFF1A2B4A), Color(0xFFE8F0FA)), // deep navy
      _SpinePalette(Color(0xFF5C6B7A), Color(0xFFFFFFFF)), // slate
      _SpinePalette(Color(0xFF2D2D38), Color(0xFFD8DCE8)), // charcoal
      _SpinePalette(Color(0xFF85A8C4), Color(0xFF0A1F35)), // ice blue
      _SpinePalette(Color(0xFF2C4D3F), Color(0xFFD8E8DC)), // evergreen
    ],
  ),
};

// ─── 이벤트(행사) 챕터 ────────────────────────────────
/// 시즌 안의 행사 chapters. 시드 책은 date 기준으로 자동 매핑.
/// 시즌 갱신일(3/1, 6/1, 9/1, 12/1) 과 별개로 행사는 더 짧은 윈도우.
class _EventChapter {
  final String id;
  final _Season season;
  final _LocPair title;          // "벚꽃 페스티벌" / "Cherry Blossom Festival"
  final String displayRange;     // "4.1—4.20" (UI 노출)
  final (int, int) matchStart;   // (month, day) — 책 자동 매핑 윈도우 시작
  final (int, int) matchEnd;     // (month, day) — 끝
  final String emoji;            // 카드 좌측 점 옆 작은 데코
  final Color accent;            // 점/뱃지 컬러

  const _EventChapter({
    required this.id,
    required this.season,
    required this.title,
    required this.displayRange,
    required this.matchStart,
    required this.matchEnd,
    required this.emoji,
    required this.accent,
  });

  /// 시즌 cross-year (겨울 11→2월) 대응 (m,d) 비교.
  bool contains(DateTime d) {
    final md = (d.month, d.day);
    int rank((int, int) v) => v.$1 * 100 + v.$2;
    final s = rank(matchStart);
    final e = rank(matchEnd);
    final cur = rank(md);
    if (s <= e) return cur >= s && cur <= e;
    // 윈도우가 연말→연초 (겨울 루나 라이트 11.20–2.10 등)
    return cur >= s || cur <= e;
  }
}

const Map<_Season, List<_EventChapter>> _kEventCatalog = {
  _Season.spring: [
    _EventChapter(
      id: 'spring_cherry',
      season: _Season.spring,
      title: _LocPair('벚꽃 페스티벌', 'Cherry Blossom Festival'),
      displayRange: '4.1—4.30',
      matchStart: (4, 1), matchEnd: (4, 30),
      emoji: '🌸',
      accent: Color(0xFFE8688A),
    ),
    _EventChapter(
      id: 'spring_kids',
      season: _Season.spring,
      title: _LocPair('어린이날 페스타', "Children's Day Fest"),
      displayRange: '5.1—5.7',
      matchStart: (5, 1), matchEnd: (5, 7),
      emoji: '🎈',
      accent: Color(0xFFF5A623),
    ),
    _EventChapter(
      id: 'spring_garden',
      season: _Season.spring,
      title: _LocPair('봄 플라워가든', 'Spring Flower Garden'),
      displayRange: '5.8—5.31',
      matchStart: (5, 8), matchEnd: (5, 31),
      emoji: '🌼',
      accent: Color(0xFF7AB55C),
    ),
  ],
  _Season.summer: [
    _EventChapter(
      id: 'summer_extreme',
      season: _Season.summer,
      title: _LocPair('익스트림 데이즈', 'Extreme Days'),
      displayRange: '6.20—7.15',
      matchStart: (6, 20), matchEnd: (7, 15),
      emoji: '🪂',
      accent: Color(0xFF2A8FD6),
    ),
    _EventChapter(
      id: 'summer_night',
      season: _Season.summer,
      title: _LocPair('야간개장 위크', 'Night Park Week'),
      displayRange: '7.16—7.31',
      matchStart: (7, 16), matchEnd: (7, 31),
      emoji: '🌃',
      accent: Color(0xFF6E5BC9),
    ),
    _EventChapter(
      id: 'summer_water',
      season: _Season.summer,
      title: _LocPair('물놀이 페스티벌', 'Water Festival'),
      displayRange: '8.1—8.31',
      matchStart: (8, 1), matchEnd: (8, 31),
      emoji: '💦',
      accent: Color(0xFF39B5D6),
    ),
  ],
  _Season.autumn: [
    _EventChapter(
      id: 'autumn_lights',
      season: _Season.autumn,
      title: _LocPair('가을 야경', 'Autumn Lights'),
      displayRange: '9.15—10.14',
      matchStart: (9, 15), matchEnd: (10, 14),
      emoji: '✨',
      accent: Color(0xFFC9A04A),
    ),
    _EventChapter(
      id: 'autumn_maple',
      season: _Season.autumn,
      title: _LocPair('단풍 페스티벌', 'Maple Festival'),
      displayRange: '10.15—11.15',
      matchStart: (10, 15), matchEnd: (11, 15),
      emoji: '🍁',
      accent: Color(0xFFB5491E),
    ),
    _EventChapter(
      id: 'autumn_halloween',
      season: _Season.autumn,
      title: _LocPair('할로윈 위크', 'Halloween Week'),
      displayRange: '10.25—10.31',
      matchStart: (10, 25), matchEnd: (10, 31),
      emoji: '🎃',
      accent: Color(0xFFE0742C),
    ),
  ],
  _Season.winter: [
    _EventChapter(
      id: 'winter_luna',
      season: _Season.winter,
      title: _LocPair('루나 라이트', 'Luna Lights'),
      displayRange: '11.20—2.10',
      matchStart: (11, 20), matchEnd: (2, 10),
      emoji: '🌙',
      accent: Color(0xFF85A8C4),
    ),
    _EventChapter(
      id: 'winter_xmas',
      season: _Season.winter,
      title: _LocPair('크리스마스 마켓', 'Christmas Market'),
      displayRange: '12.10—12.25',
      matchStart: (12, 10), matchEnd: (12, 25),
      emoji: '🎄',
      accent: Color(0xFFD4361F),
    ),
    _EventChapter(
      id: 'winter_new',
      season: _Season.winter,
      title: _LocPair('새해 페스타', 'New Year Fest'),
      displayRange: '12.31—1.5',
      matchStart: (12, 31), matchEnd: (1, 5),
      emoji: '🎊',
      accent: Color(0xFFE0B84A),
    ),
  ],
};

/// 시즌 KST 갱신일 기준 displayRange (예: 봄 3—5월).
const Map<_Season, _LocPair> _kSeasonRange = {
  _Season.spring: _LocPair('3—5월', 'Mar—May'),
  _Season.summer: _LocPair('6—8월', 'Jun—Aug'),
  _Season.autumn: _LocPair('9—11월', 'Sep—Nov'),
  _Season.winter: _LocPair('12—2월', 'Dec—Feb'),
};

/// 책을 (가능하면) 이벤트 챕터에 자동 매핑. 매칭 안 되면 null.
_EventChapter? _matchEventFor(_DiaryBook book) {
  final cands = _kEventCatalog[_seasonOf(book.date)] ?? const [];
  // 짧은 윈도우 우선(더 구체적인 이벤트가 우선) — 예: 어린이날(5.1-5.7) > 봄가든(5.8-)
  // 정렬 후 첫 매치 반환.
  final sorted = [...cands]..sort((a, b) {
    int span(_EventChapter e) {
      final s = e.matchStart.$1 * 100 + e.matchStart.$2;
      final t = e.matchEnd.$1 * 100 + e.matchEnd.$2;
      return t >= s ? t - s : (1200 - s) + t;
    }
    return span(a).compareTo(span(b));
  });
  for (final e in sorted) {
    if (e.contains(book.date)) return e;
  }
  return null;
}

_Season _seasonOf(DateTime d) {
  if (d.month >= 3 && d.month <= 5) return _Season.spring;
  if (d.month >= 6 && d.month <= 8) return _Season.summer;
  if (d.month >= 9 && d.month <= 11) return _Season.autumn;
  return _Season.winter;
}

// ─── 데이터 모델 ─────────────────────────────────────────
/// 방문 날짜 = 고유키. 같은 날짜에 두 권이 생기지 않도록 데이터 단에서 보장.
class _DiaryBook {
  final String id;
  final DateTime date;
  final _Weather weather;
  final _LocPair headline;
  final List<String> attractionIds;
  final List<_Mission> missions;
  final List<_BadgeSpec> badges;
  final _LocPair story;
  /// 사진 placeholder (그라데이션 + 이모지). null = 사진 없음 → 빈티지 스탬프 표시.
  final _SampleIllustration? sampleIllustration;
  const _DiaryBook({
    required this.id,
    required this.date,
    required this.weather,
    required this.headline,
    required this.attractionIds,
    required this.missions,
    required this.badges,
    required this.story,
    this.sampleIllustration,
  });

  /// 방문 날짜 키 (YYYY-MM-DD) — '1일 1권' 보장 시 사용.
  String get dateKey =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

class _Weather {
  final String icon; // ☀️ ⛅ 🌧️ ❄️ ⛈️
  final _LocPair label; // ('맑음 22°C', 'Clear 22°C')
  final Color stampColor;
  const _Weather(
      {required this.icon, required this.label, required this.stampColor});
}

class _Mission {
  final _LocPair label;
  final bool completed;
  final IconData icon;
  const _Mission({required this.label, required this.completed, required this.icon});
}

class _BadgeSpec {
  final String emoji;
  final _LocPair label;
  const _BadgeSpec({required this.emoji, required this.label});
}

class _SampleIllustration {
  final List<Color> gradient;
  final String emoji;
  const _SampleIllustration({required this.gradient, required this.emoji});
}

// ─── 사진 영속 저장소 ────────────────────────────────────
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
  late final PageController _seasonPager = PageController(initialPage: 0);

  late final Map<_Season, List<_DiaryBook>> _diaries = _buildMockDiaries();

  void _onTabChange(_Season s) {
    final idx = _Season.values.indexOf(s);
    _seasonPager.animateToPage(
      idx,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

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

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const ColoredBox(
        color: _Vintage.parchmentLight,
        child: Center(child: CircularProgressIndicator(color: _Vintage.leather)),
      );
    }
    return _ParchmentBackground(
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(
              season: _season,
              onChange: _onTabChange,
              currentSeasonBooks: _diaries[_season] ?? const [],
              onSearch: _openSearch,
              onAdd: _openAddBook,
            ),
            Expanded(
              child: PageView.builder(
                controller: _seasonPager,
                itemCount: _Season.values.length,
                onPageChanged: (i) =>
                    setState(() => _season = _Season.values[i]),
                itemBuilder: (ctx, i) {
                  final s = _Season.values[i];
                  final cfg = _kConfigs[s]!;
                  final list = _diaries[s] ?? const <_DiaryBook>[];
                  return ListView(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      20,
                      20,
                      140 + MediaQuery.of(context).viewPadding.bottom,
                    ),
                    children: [
                      _EventShelf(
                        season: s,
                        config: cfg,
                        books: list,
                        onBookTap: (book) => _openDiaryForBook(s, book),
                      ),
                      const SizedBox(height: 20),
                      _DiaryStats(books: list, config: cfg, season: s),
                      const SizedBox(height: 16),
                      _RewardProgressCard(season: s),
                      const SizedBox(height: 16),
                      _PaperHint(),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _seasonPager.dispose();
    super.dispose();
  }

  void _openSearch() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ArchiveSearchSheet(
        allBooks: _diaries,
        onBookTap: (s, book) {
          Navigator.of(context).pop();
          _openDiaryForBook(s, book);
        },
      ),
    );
  }

  void _openAddBook() {
    final l = const _L10n();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l.archive_add_book_coming_soon),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _openDiaryForBook(_Season s, _DiaryBook book) {
    final all = _diaries[s] ?? const <_DiaryBook>[];
    final idx = all.indexWhere((b) => b.id == book.id);
    _openDiaryForSeason(s, idx >= 0 ? idx : 0);
  }

  void _openDiaryForSeason(_Season s, int index) {
    showGeneralDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.65),
      barrierDismissible: true,
      barrierLabel: const _L10n().archive_close_label,
      transitionDuration: const Duration(milliseconds: 360),
      pageBuilder: (ctx, anim, secAnim) {
        return _DiaryDialog(
          config: _kConfigs[s]!,
          books: _diaries[s]!,
          initialBookIndex: index,
          onPhotoChanged: () => setState(() {}),
        );
      },
      transitionBuilder: (ctx, anim, secAnim, child) {
        final curve =
            CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curve,
          child: ScaleTransition(
            scale: Tween(begin: 0.9, end: 1.0).animate(curve),
            child: child,
          ),
        );
      },
    );
  }

  // ── 목업 데이터 ────────────────────────────────────────
  // 1일 1권 — 각 책 date 가 시즌 내에서 유일.
  // 사진 있는 책 vs 사진 없는 책 — sampleIllustration 으로 시뮬레이션.
  static Map<_Season, List<_DiaryBook>> _buildMockDiaries() {
    return {
      _Season.spring: [
        _DiaryBook(
          id: 'd_2026_04_14',
          date: DateTime(2026, 4, 14, 14, 30),
          weather: _Weather(icon: '☀️', label: _LocPair('맑음 22°C', 'Clear 22°C'), stampColor: _Vintage.stampRed),
          headline: _LocPair('벚꽃 흩날리는 첫 봄나들이', 'First spring outing under falling petals'),
          attractionIds: const ['cherry_blossom_path', 'carousel'],
          missions: [
            _Mission(label: _LocPair('회전목마 50m 진입', 'Within 50m of the carousel'), completed: true, icon: Icons.celebration_rounded),
            _Mission(label: _LocPair('벚꽃길 산책 완주', 'Cherry blossom walk completed'), completed: true, icon: Icons.directions_walk_rounded),
            _Mission(label: _LocPair('오후 야외 어트랙션 3회', '3 outdoor rides in the afternoon'), completed: false, icon: Icons.sunny),
          ],
          badges: const [
            _BadgeSpec(emoji: '🌸', label: _LocPair('봄의 시작', 'Spring begins')),
            _BadgeSpec(emoji: '📷', label: _LocPair('첫 방문 기록자', 'First visit logged')),
          ],
          story: _LocPair(
            '벚꽃이 만개한 4월의 오후, 친구들과 손을 잡고 걸었던 그 길. 바람이 불 때마다 머리 위로 꽃잎이 쏟아져 내렸어요. '
            '카메라를 꺼낼 새도 없이 그 순간이 너무 빠르게 지나가서, 결국엔 눈에 담는 것으로 만족했답니다. '
            '점심엔 회전목마 옆 카페에서 봄 한정 음료를 마셨고, 해가 기울 무렵에야 천천히 정문을 나왔습니다.',
            'An April afternoon under full bloom, walking hand in hand with friends. Every breeze brought another shower of petals over our heads. '
            'There was no time to grab a camera — the moment moved too fast, so we just kept it in our eyes. '
            'For lunch we tried a spring-only drink at the café next to the carousel, and only when the sun started to dip did we slowly head out the front gate.',
          ),
          sampleIllustration: const _SampleIllustration(
            gradient: [Color(0xFFFCE4EC), Color(0xFFF8BBD0), Color(0xFFE91E63)],
            emoji: '🌸',
          ),
        ),
        _DiaryBook(
          id: 'd_2026_04_21',
          date: DateTime(2026, 4, 21, 11, 15),
          weather: _Weather(icon: '⛅', label: _LocPair('구름 많음 18°C', 'Mostly cloudy 18°C'), stampColor: _Vintage.stampInk),
          headline: _LocPair('어른의 회전목마, 다시 동심', "A grown-up's carousel — childhood comes back"),
          attractionIds: const ['carousel'],
          missions: [
            _Mission(label: _LocPair('회전목마 탑승', 'Rode the carousel'), completed: true, icon: Icons.attractions_rounded),
            _Mission(label: _LocPair('캐릭터 타운 전체 산책', 'Walked all of Character Town'), completed: true, icon: Icons.map_rounded),
          ],
          badges: const [
            _BadgeSpec(emoji: '🎠', label: _LocPair('동심 회복', 'Childhood, restored')),
          ],
          story: _LocPair(
            '어릴 적 엄마 손을 잡고 처음 탔던 회전목마. 어른이 되어 다시 올라타니 그 시절의 설렘이 그대로 떠올랐어요. '
            '음악도, 조명도, 거울에 비친 풍경도 모두 그대로였답니다.',
            "The first carousel I ever rode, holding mom's hand. Climbing on again as an adult, the same thrill from back then came rushing back. "
            'The music, the lights, the reflection in the mirror — all of it untouched.',
          ),
          // sampleIllustration 없음 → 빈티지 스탬프 표시
        ),
        _DiaryBook(
          id: 'd_2026_05_05',
          date: DateTime(2026, 5, 5, 12, 0),
          weather: _Weather(icon: '☀️', label: _LocPair('맑음 24°C', 'Clear 24°C'), stampColor: _Vintage.stampRed),
          headline: _LocPair('어린이날, 가족 총출동', "Children's Day — the whole family showed up"),
          attractionIds: const ['mini_viking', 'carousel', 'bumper_car'],
          missions: [
            _Mission(label: _LocPair('가족 단체 사진 촬영', 'Took the family group photo'), completed: true, icon: Icons.groups_rounded),
            _Mission(label: _LocPair('미니바이킹 첫 탑승', 'First mini Viking ride'), completed: true, icon: Icons.sailing_rounded),
            _Mission(label: _LocPair('범퍼카 5회 이상', '5+ bumper car rounds'), completed: false, icon: Icons.directions_car_rounded),
          ],
          badges: const [
            _BadgeSpec(emoji: '👨‍👩‍👧‍👦', label: _LocPair('패밀리 데이', 'Family Day')),
            _BadgeSpec(emoji: '🎈', label: _LocPair('어린이날 마스터', "Children's Day master")),
          ],
          story: _LocPair(
            '온 가족이 다 모인 어린이날. 조카들이 처음 타본 미니바이킹에서 환하게 웃던 그 표정, 평생 기억에 남을 것 같아요. '
            '점심엔 다 같이 모여 사진을 찍었는데 아빠가 셀카봉을 처음 써보셨답니다.',
            "Children's Day with everyone together. The way my niece and nephew lit up on their first mini Viking ride — I'll remember that look forever. "
            'At lunch we all crowded in for a photo and dad tried a selfie stick for the very first time.',
          ),
          sampleIllustration: const _SampleIllustration(
            gradient: [Color(0xFFFFF3E0), Color(0xFFFFCC80), Color(0xFFFF7043)],
            emoji: '👨‍👩‍👧‍👦',
          ),
        ),
      ],
      _Season.summer: [
        _DiaryBook(
          id: 'd_2025_07_04',
          date: DateTime(2025, 7, 4, 19, 30),
          weather: _Weather(icon: '☀️', label: _LocPair('맑음 31°C', 'Clear 31°C'), stampColor: _Vintage.stampRed),
          headline: _LocPair('한여름 야간개장의 매력', 'Midsummer after-hours, a different park'),
          attractionIds: const ['galaxy_888', 'carousel'],
          missions: [
            _Mission(label: _LocPair('야간 어트랙션 3종', '3 rides after dark'), completed: true, icon: Icons.nightlight_round),
            _Mission(label: _LocPair('21시 이후 분수쇼 관람', 'Watched the 9pm fountain show'), completed: true, icon: Icons.celebration_rounded),
          ],
          badges: const [
            _BadgeSpec(emoji: '🌃', label: _LocPair('야경 헌터', 'Nightscape hunter')),
          ],
          story: _LocPair(
            '해가 진 후의 서울랜드는 완전 다른 분위기예요. 낮엔 봐도 그냥 지나치던 조명들이 모두 살아 움직였어요. '
            '은하열차의 야간 라이드는 그 어떤 어트랙션보다도 짜릿했답니다.',
            'Seoul Land after sundown is a whole different mood. Lights I would have walked right past in daylight were suddenly alive. '
            "The Galaxy 888's night ride was the most thrilling thing of the trip — easily.",
          ),
          // 사진 없음 → 빈티지 스탬프
        ),
        _DiaryBook(
          id: 'd_2025_07_20',
          date: DateTime(2025, 7, 20, 13, 30),
          weather: _Weather(icon: '☀️', label: _LocPair('폭염 33°C', 'Heatwave 33°C'), stampColor: _Vintage.stampRed),
          headline: _LocPair('스카이엑스에서 본 여름 하늘', 'The summer sky from Sky X'),
          attractionIds: const ['sky_x'],
          missions: [
            _Mission(label: _LocPair('스카이엑스 첫 도전', 'First Sky X attempt'), completed: true, icon: Icons.paragliding_rounded),
            _Mission(label: _LocPair('익스트림 라이드 2회', '2 extreme rides'), completed: true, icon: Icons.bolt_rounded),
          ],
          badges: const [
            _BadgeSpec(emoji: '🪂', label: _LocPair('스릴 마스터', 'Thrill master')),
            _BadgeSpec(emoji: '☀️', label: _LocPair('여름의 정점', 'Peak summer')),
          ],
          story: _LocPair(
            '70m 상공에서 떨어지던 그 순간, 시간이 멈춘 듯했어요. 떨어지는 동안 본 푸른 여름 하늘이 잊혀지지 않아요. '
            '내려와서 다시 줄을 섰더니 친구가 어이없어했답니다.',
            "In the moment we dropped from 70m up, time just stopped. That blue summer sky I saw on the way down — I can't shake it. "
            'I got off and immediately got back in line. My friend was speechless.',
          ),
          sampleIllustration: const _SampleIllustration(
            gradient: [Color(0xFFE3F2FD), Color(0xFF64B5F6), Color(0xFF1976D2)],
            emoji: '🪂',
          ),
        ),
        _DiaryBook(
          id: 'd_2025_08_05',
          date: DateTime(2025, 8, 5, 15, 10),
          weather: _Weather(icon: '⛈️', label: _LocPair('뇌우 28°C', 'Thunderstorm 28°C'), stampColor: _Vintage.stampInk),
          headline: _LocPair('뇌우 피해 실내 어트랙션 종일', 'Ducking the storm — all indoors, all day'),
          attractionIds: const ['bumper_car', 'time_machine_5d'],
          missions: [
            _Mission(label: _LocPair('실내 어트랙션 3종 클리어', 'Cleared 3 indoor rides'), completed: true, icon: Icons.house_rounded),
            _Mission(label: _LocPair('범퍼카 단체전', 'Bumper car group battle'), completed: true, icon: Icons.directions_car_rounded),
          ],
          badges: const [
            _BadgeSpec(emoji: '☂️', label: _LocPair('비 오는 날 탐험가', 'Rainy-day explorer')),
          ],
          story: _LocPair(
            '오후부터 비가 쏟아져서 실내 위주로 다녔어요. 오히려 사람이 적어서 여유로웠고, '
            '범퍼카는 같은 자리에서 30분 동안 연속으로 탔답니다.',
            'Rain poured down from the afternoon on so we stayed indoors. Fewer people around — actually a relief — and '
            'we rode the bumper cars in the same spot for 30 minutes straight.',
          ),
        ),
      ],
      _Season.autumn: [
        _DiaryBook(
          id: 'd_2025_10_18',
          date: DateTime(2025, 10, 18, 14, 20),
          weather: _Weather(icon: '☀️', label: _LocPair('맑음 19°C', 'Clear 19°C'), stampColor: _Vintage.stampRed),
          headline: _LocPair('단풍 사이로 달린 은하열차', 'Galaxy 888 racing through red maples'),
          attractionIds: const ['galaxy_888', 'gyro_swing'],
          missions: [
            _Mission(label: _LocPair('단풍 명소 3곳 방문', 'Visited 3 maple spots'), completed: true, icon: Icons.park_rounded),
            _Mission(label: _LocPair('은하열차 야간 라이드', 'Galaxy 888 night ride'), completed: false, icon: Icons.train_rounded),
          ],
          badges: const [
            _BadgeSpec(emoji: '🍁', label: _LocPair('단풍 헌터', 'Maple hunter')),
          ],
          story: _LocPair(
            '단풍이 물든 풍경 사이로 질주하는 은하열차. 바람에 실려오는 가을 향기와 함께 달렸던 그 코스가 최고였어요.',
            'Galaxy 888 tearing through a landscape soaked in maple red. Riding it with the autumn air streaming in — best track of the day.',
          ),
          sampleIllustration: const _SampleIllustration(
            gradient: [Color(0xFFFFF3E0), Color(0xFFFFB74D), Color(0xFFE65100)],
            emoji: '🍁',
          ),
        ),
        _DiaryBook(
          id: 'd_2025_10_25',
          date: DateTime(2025, 10, 25, 16, 10),
          weather: _Weather(icon: '⛅', label: _LocPair('구름 16°C', 'Cloudy 16°C'), stampColor: _Vintage.stampInk),
          headline: _LocPair('가을 야경 둘만의 데이트', 'Autumn nightscape, just the two of us'),
          attractionIds: const ['shot_drop', 'galaxy_888'],
          missions: [
            _Mission(label: _LocPair('저녁 야경 어트랙션', 'Evening night-view ride'), completed: true, icon: Icons.nightlight_round),
            _Mission(label: _LocPair('단풍 포토스팟 통과', 'Maple photo spots cleared'), completed: true, icon: Icons.camera_alt_rounded),
          ],
          badges: const [
            _BadgeSpec(emoji: '💕', label: _LocPair('데이트 마스터', 'Date-night master')),
          ],
          story: _LocPair(
            '단풍이 절정이던 날, 둘이서 천천히 걸으며 본 풍경. 시간이 멈췄으면 좋겠다 싶었어요. '
            '저녁엔 야경 명소에서 잠시 쉬며 그날의 모든 것을 마음에 담았습니다.',
            'Peak maple, walking slowly together — I caught myself wishing time would just stop. '
            'In the evening we paused at a viewpoint and quietly took in everything from the day.',
          ),
        ),
      ],
      _Season.winter: [
        _DiaryBook(
          id: 'd_2024_12_24',
          date: DateTime(2024, 12, 24, 18, 30),
          weather: _Weather(icon: '❄️', label: _LocPair('눈 -2°C', 'Snow -2°C'), stampColor: _Vintage.stampInk),
          headline: _LocPair('눈 내리는 회전목마, 동화의 밤', 'Snow on the carousel — a fairytale night'),
          attractionIds: const ['carousel', 'santa_restaurant'],
          missions: [
            _Mission(label: _LocPair('눈 오는 날 야간 방문', 'Night visit on a snowy day'), completed: true, icon: Icons.ac_unit_rounded),
            _Mission(label: _LocPair('산타레스토랑 식사', 'Dinner at Santa Restaurant'), completed: true, icon: Icons.restaurant_rounded),
            _Mission(label: _LocPair('눈 인증샷 5장', '5 snow photos saved'), completed: false, icon: Icons.camera_alt_rounded),
          ],
          badges: const [
            _BadgeSpec(emoji: '🎄', label: _LocPair('크리스마스 이브', 'Christmas Eve')),
            _BadgeSpec(emoji: '❄️', label: _LocPair('겨울 동화', 'Winter fairytale')),
          ],
          story: _LocPair(
            '함박눈이 내리던 12월 24일 저녁, 조명이 켜진 회전목마. 한 폭의 동화 같았던 그 풍경을 잊을 수 없어요. '
            '추워서 손이 곱아도 카메라 셔터를 멈출 수 없었답니다.',
            "Big fat flakes coming down on Christmas Eve, lights on the carousel. The whole scene looked pulled out of a storybook — I can't forget it. "
            'My hands were numb but I just kept hitting the shutter.',
          ),
          sampleIllustration: const _SampleIllustration(
            gradient: [Color(0xFFE1F5FE), Color(0xFFB3E5FC), Color(0xFF0288D1)],
            emoji: '🎄',
          ),
        ),
        _DiaryBook(
          id: 'd_2025_01_01',
          date: DateTime(2025, 1, 1, 13, 0),
          weather: _Weather(icon: '☀️', label: _LocPair('맑음 1°C', 'Clear 1°C'), stampColor: _Vintage.stampRed),
          headline: _LocPair('새해 첫 방문, 타임머신 5D', "New Year's first visit — Time Machine 5D"),
          attractionIds: const ['time_machine_5d'],
          missions: [
            _Mission(label: _LocPair('새해 첫 어트랙션', "New Year's first ride"), completed: true, icon: Icons.celebration_rounded),
            _Mission(label: _LocPair('5D 영상 관람', 'Watched the 5D feature'), completed: true, icon: Icons.movie_rounded),
          ],
          badges: const [
            _BadgeSpec(emoji: '🎊', label: _LocPair('새해 첫 도전', "New Year's first run")),
          ],
          story: _LocPair(
            '새해 첫날 가족과 함께 본 5D 영상. 미래의 한 장면 같았던 그 경험이 새해의 시작을 특별하게 만들어줬어요.',
            "Watched the 5D feature with family on New Year's Day. It felt like a scene from the future and made the start of the year feel special.",
          ),
        ),
      ],
    };
  }
}

// ─── Parchment 배경 (질감 시뮬레이션) ─────────────────────
class _ParchmentBackground extends StatelessWidget {
  final Widget child;
  const _ParchmentBackground({required this.child});

  @override
  Widget build(BuildContext context) {
    // v3 — 거의 흰색에 가까운 cream 단색. 시안 11 의 깨끗한 background.
    return Container(
      color: const Color(0xFFFAFAF8),
      child: child,
    );
  }
}

class _Header extends StatelessWidget {
  final _Season season;
  final ValueChanged<_Season> onChange;
  final List<_DiaryBook> currentSeasonBooks;
  final VoidCallback onSearch;
  final VoidCallback onAdd;
  const _Header({
    required this.season,
    required this.onChange,
    required this.currentSeasonBooks,
    required this.onSearch,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
      decoration: BoxDecoration(
        color: _Vintage.parchmentLight.withOpacity(0.8),
        border: Border(
          bottom: BorderSide(
            color: _Vintage.leather.withOpacity(0.15),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // RETRACE ARCHIVE eyebrow.
          Text(
            'RETRACE ARCHIVE',
            style: _serif(
              size: 10,
              weight: FontWeight.w800,
              color: _Vintage.leather,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 4),
          // 타이틀 + 연도 + 우상단 액션.
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      const _L10n().archive_bookshelf_title,
                      style: _serif(
                        size: 28,
                        weight: FontWeight.w900,
                        color: _Vintage.inkDark,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        '${DateTime.now().year}',
                        style: const TextStyle(
                          color: Color(0xFF9A8A7A),
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _CircleAction(
                icon: Icons.search_rounded,
                onTap: onSearch,
              ),
              const SizedBox(width: 8),
              _CircleAction(
                icon: Icons.add_rounded,
                onTap: onAdd,
              ),
            ],
          ),
          const SizedBox(height: 14),
          // v3 시즌 탭 — bgCardWarm pill bar + active=ink900 채움 + 컬러 dot
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAF8),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: const Color(0xFFECECEC)),
            ),
            // 모든 세그먼트가 균등 너비·높이 — Apple HIG segmented control 정합.
            // Expanded + 명시 height 36 + maxLines 1 로 글자수 차이(봄 vs 여름)에
            // 따른 시각 변형을 차단.
            child: SizedBox(
              height: 36,
              child: Row(
                children: _Season.values
                    .map((s) {
                      final active = season == s;
                      final cfg = _kConfigs[s]!;
                      return Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onChange(s),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOut,
                            decoration: BoxDecoration(
                              // 시안 v3 — active 시 ink-900 검정 채움, 컬러 dot
                              color: active
                                  ? const Color(0xFF111111)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: cfg.dotColor,
                                    boxShadow: active
                                        ? [
                                            BoxShadow(
                                              color: cfg.dotColor
                                                  .withOpacity(0.4),
                                              blurRadius: 0,
                                              spreadRadius: 2,
                                            ),
                                          ]
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  cfg.label.of(context),
                                  maxLines: 1,
                                  overflow: TextOverflow.clip,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: active
                                        ? Colors.white
                                        : const Color(0xFF333333),
                                    letterSpacing: -0.1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    })
                    .toList(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // 시즌 tagline (왼쪽) + 행사·권 카운트 (오른쪽).
          Row(
            children: [
              Expanded(
                child: Text(
                  _kConfigs[season]!.tagline.of(context),
                  style: const TextStyle(
                    color: Color(0xFF6E5A4A),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              Text(
                const _L10n().archive_events_books_count(
                  _EventShelf.eventChaptersUnlocked(currentSeasonBooks),
                  currentSeasonBooks.length,
                ),
                style: const TextStyle(
                  color: Color(0xFF8A7A6A),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleAction({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.7),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: _Vintage.leather.withOpacity(0.18)),
          ),
          child: Icon(icon, size: 18, color: _Vintage.inkDark),
        ),
      ),
    );
  }
}

class _EventShelf extends StatelessWidget {
  final _Season season;
  final _SeasonConfig config;
  final List<_DiaryBook> books;
  final void Function(_DiaryBook book) onBookTap;
  const _EventShelf({
    required this.season,
    required this.config,
    required this.books,
    required this.onBookTap,
  });

  @override
  Widget build(BuildContext context) {
    final l = const _L10n();
    final events = _kEventCatalog[season] ?? const <_EventChapter>[];
    final byEvent = <String, List<_DiaryBook>>{};
    for (final b in books) {
      final e = _matchEventFor(b);
      if (e != null) byEvent.putIfAbsent(e.id, () => []).add(b);
    }
    final range = _kSeasonRange[season]!.of(context);

    return Container(
      decoration: BoxDecoration(
        color: config.bgColor.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: config.accentColor.withValues(alpha: 0.25)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 시즌 eyebrow
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
            child: Text(
              l.archive_season_range_label(config.label.en.toUpperCase(), range),
              style: const TextStyle(
                color: Color(0xFF6E5A4A),
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ),
          // 이벤트 카드들
          for (final e in events) ...[
            _EventCard(
              event: e,
              books: byEvent[e.id] ?? const [],
              palettes: config.spines,
              onBookTap: onBookTap,
            ),
            const SizedBox(height: 8),
          ],
          // 마지막 점선 placeholder
          const _NextEventPlaceholder(),
        ],
      ),
    );
  }

  static int eventChaptersUnlocked(List<_DiaryBook> books) {
    final set = <String>{};
    for (final b in books) {
      final e = _matchEventFor(b);
      if (e != null) set.add(e.id);
    }
    return set.length;
  }
}

/// 행사 1건 카드 — 점/이모지 + 제목 + 날짜범위 + 우측 권수 뱃지 + 책 spine row.
class _EventCard extends StatelessWidget {
  final _EventChapter event;
  final List<_DiaryBook> books;
  final List<_SpinePalette> palettes;
  final void Function(_DiaryBook book) onBookTap;

  const _EventCard({
    required this.event,
    required this.books,
    required this.palettes,
    required this.onBookTap,
  });

  @override
  Widget build(BuildContext context) {
    final l = const _L10n();
    final hasBooks = books.isNotEmpty;
    return Container(
      padding: EdgeInsets.fromLTRB(14, 12, 14, hasBooks ? 14 : 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: event.accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  event.title.of(context),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF1F1F1F),
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                event.displayRange,
                style: const TextStyle(
                  color: Color(0xFF888888),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              // 권수 뱃지 — 책이 있을 때만.
              if (hasBooks)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: event.accent.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    l.archive_event_books_badge(books.length),
                    style: TextStyle(
                      color: event.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),
          if (hasBooks) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: books.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, i) {
                  final b = books[i];
                  return _MiniBookSpine(
                    book: b,
                    palette: palettes[i % palettes.length],
                    onTap: () => onBookTap(b),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 이벤트 카드 안 작은 책 — 28×96 spine + 단축 제목 + 날짜.
class _MiniBookSpine extends StatelessWidget {
  final _DiaryBook book;
  final _SpinePalette palette;
  final VoidCallback onTap;
  const _MiniBookSpine({
    required this.book,
    required this.palette,
    required this.onTap,
  });

  String _spineTitle(BuildContext ctx) {
    final cleaned = book.headline.of(ctx).replaceAll(RegExp(r'[\s·,.!?]'), '');
    return cleaned.characters.take(4).toString();
  }

  String get _spineDate {
    final m = book.date.month.toString();
    final d = book.date.day.toString().padLeft(2, '0');
    return '$m.$d';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 32,
        decoration: BoxDecoration(
          color: palette.spine,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(2),
            bottom: Radius.circular(3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 3,
              offset: const Offset(1, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 10),
            for (final ch in _spineTitle(context).characters)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Text(
                  ch,
                  style: TextStyle(
                    color: palette.text,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                _spineDate,
                style: TextStyle(
                  fontFamily: 'Menlo',
                  fontFamilyFallback: const ['Courier New', 'monospace'],
                  color: palette.text.withValues(alpha: 0.7),
                  fontSize: 7,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 마지막 점선 placeholder — '다음 행사 칸 · 방문하면 채워져요'.
class _NextEventPlaceholder extends StatelessWidget {
  const _NextEventPlaceholder();

  @override
  Widget build(BuildContext context) {
    final l = const _L10n();
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(14),
      ),
      child: CustomPaint(
        painter: _DashedBoxPainter(
          color: const Color(0xFF8A6A5A).withValues(alpha: 0.45),
          radius: 14,
          dash: 5,
          gap: 4,
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_circle_outline_rounded,
                  size: 16, color: Color(0xFF8A6A5A)),
              const SizedBox(width: 6),
              Text(
                l.archive_next_event_placeholder,
                style: const TextStyle(
                  color: Color(0xFF6E5A4A),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedBoxPainter extends CustomPainter {
  final Color color;
  final double radius;
  final double dash;
  final double gap;
  _DashedBoxPainter({
    required this.color,
    required this.radius,
    required this.dash,
    required this.gap,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rect);
    final metrics = path.computeMetrics();
    for (final m in metrics) {
      double dist = 0;
      while (dist < m.length) {
        final seg = m.extractPath(dist, (dist + dash).clamp(0, m.length));
        canvas.drawPath(seg, paint);
        dist += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBoxPainter o) =>
      o.color != color || o.radius != radius || o.dash != dash || o.gap != gap;
}

class _ArchiveSearchSheet extends StatefulWidget {
  final Map<_Season, List<_DiaryBook>> allBooks;
  final void Function(_Season season, _DiaryBook book) onBookTap;
  const _ArchiveSearchSheet({required this.allBooks, required this.onBookTap});

  @override
  State<_ArchiveSearchSheet> createState() => _ArchiveSearchSheetState();
}

class _ArchiveSearchSheetState extends State<_ArchiveSearchSheet> {
  final _ctrl = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  List<(_Season, _DiaryBook)> _matches(BuildContext ctx) {
    if (_q.trim().isEmpty) return const [];
    final q = _q.trim().toLowerCase();
    final out = <(_Season, _DiaryBook)>[];
    for (final entry in widget.allBooks.entries) {
      for (final b in entry.value) {
        final hl = b.headline.of(ctx).toLowerCase();
        final ev = _matchEventFor(b)?.title.of(ctx).toLowerCase() ?? '';
        if (hl.contains(q) || ev.contains(q)) out.add((entry.key, b));
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final l = const _L10n();
    final results = _matches(context);
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFFFFCF6),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0D5C0),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              l.archive_search_title,
              style: _serif(
                size: 18,
                weight: FontWeight.w900,
                color: _Vintage.inkDark,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: _Vintage.leather.withOpacity(0.15)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded,
                      size: 16, color: Color(0xFF8A7A6A)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      autofocus: true,
                      onChanged: (v) => setState(() => _q = v),
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        isCollapsed: true,
                        border: InputBorder.none,
                        hintText: l.archive_search_hint,
                        hintStyle:
                            const TextStyle(color: Color(0xFFB0A090), fontSize: 13),
                      ),
                    ),
                  ),
                  if (_q.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _ctrl.clear();
                        setState(() => _q = '');
                      },
                      child: const Icon(Icons.close_rounded,
                          size: 16, color: Color(0xFF8A7A6A)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.45,
              ),
              child: _q.isEmpty
                  ? const SizedBox.shrink()
                  : (results.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 28),
                          child: Center(
                            child: Text(l.archive_search_empty,
                                style: const TextStyle(
                                    color: Color(0xFF8A7A6A), fontSize: 13)),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: results.length,
                          separatorBuilder: (_, __) => const Divider(
                              height: 14, color: Color(0xFFEFE6D5)),
                          itemBuilder: (_, i) {
                            final (s, b) = results[i];
                            final ev = _matchEventFor(b);
                            return InkWell(
                              onTap: () => widget.onBookTap(s, b),
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 6),
                                child: Row(
                                  children: [
                                    Text(b.weather.icon,
                                        style: const TextStyle(fontSize: 18)),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            b.headline.of(context),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF1F1F1F),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${b.date.year}.${b.date.month}.${b.date.day} · ${ev?.title.of(context) ?? ''}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF8A7A6A),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.chevron_right_rounded,
                                        size: 18, color: Color(0xFFB0A090)),
                                  ],
                                ),
                              ),
                            );
                          },
                        )),
            ),
          ],
        ),
      ),
    );
  }
}


/// v3 책장 빈 슬롯 — 22×100 dashed 윤곽.
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
        SnackBar(content: Text(const _L10n().archive_photo_load_failed('$e'))),
      );
    }
  }

  Future<void> _removePhoto() async {
    await _PhotoStore.remove(_book.id);
    if (!mounted) return;
    setState(() {});
    widget.onPhotoChanged();
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
    // 첫 페이지는 dark cover, 펼침 페이지는 white. PageView 가 전환 중일 때를
    // 대비해 배경은 black 으로 고정하고 각 페이지가 자체 BG 를 갖는다.
    return Dialog.fullscreen(
      backgroundColor: const Color(0xFF1C1814),
      child: SafeArea(
        child: Column(
            children: [
              _DialogTopBar(
                config: widget.config,
                bookIndex: _bookIndex + 1,
                totalBooks: widget.books.length,
                onPrev: _bookIndex > 0 ? _goPrevBook : null,
                onNext: _bookIndex < widget.books.length - 1
                    ? _goNextBook
                    : null,
                onClose: () => Navigator.of(context).pop(),
                isDark: _pageIndex == 0,
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageCtrl,
                  onPageChanged: (i) => setState(() => _pageIndex = i),
                  itemCount: 3,
                  itemBuilder: (ctx, i) {
                    final pages = [
                      _PageCover(book: _book, config: widget.config),
                      _PageJournal(book: _book, config: widget.config),
                      _PageMemory(
                        book: _book,
                        config: widget.config,
                        onPickGallery: () => _pickPhoto(ImageSource.gallery),
                        onPickCamera: () => _pickPhoto(ImageSource.camera),
                        onRemovePhoto: _removePhoto,
                      ),
                    ];
                    return pages[i];
                    },
                  ),
                ),
              _PageIndicator(current: _pageIndex, total: 3, isDark: _pageIndex == 0),
            ],
        ),
      ),
    );
  }
}

class _DialogTopBar extends StatelessWidget {
  final _SeasonConfig config;
  final int bookIndex, totalBooks;
  final VoidCallback? onPrev, onNext;
  final VoidCallback onClose;
  final bool isDark;
  const _DialogTopBar({
    required this.config,
    required this.bookIndex,
    required this.totalBooks,
    required this.onPrev,
    required this.onNext,
    required this.onClose,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final fg = isDark
        ? Colors.white.withOpacity(0.85)
        : _Vintage.inkDark;
    final eyebrow = isDark
        ? Colors.white.withOpacity(0.55)
        : _Vintage.inkMid;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1814) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withOpacity(0.08)
                : _Vintage.parchmentDark,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          _IconBtn(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: onClose,
            enabled: true,
            isDark: isDark,
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${config.label.en.toUpperCase()} · VOL.1',
                    style: TextStyle(
                      color: eyebrow,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.6,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${book(bookIndex)}',
                    style: TextStyle(
                      color: fg,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
          _IconBtn(
            icon: Icons.add_rounded,
            onTap: onNext,
            enabled: onNext != null,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  String book(int i) => '$i / $totalBooks';
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool enabled;
  final bool isDark;
  const _IconBtn({
    required this.icon,
    required this.onTap,
    required this.enabled,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDark
        ? Colors.white.withOpacity(0.9)
        : _Vintage.inkDark;
    return Opacity(
      opacity: enabled ? 1.0 : 0.25,
      child: InkResponse(
        onTap: enabled ? onTap : null,
        radius: 20,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }
}

// ─── 페이지 1: 표지 / 개요 ───────────────────────────────
class _PageCover extends StatelessWidget {
  final _DiaryBook book;
  final _SeasonConfig config;
  const _PageCover({required this.book, required this.config});

  String _formatDate(DateTime d) {
    const months = ['January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'];
    return '${months[d.month - 1]} ${d.day} · ${d.year}';
  }

  String _formatKoreanDate(BuildContext ctx, DateTime d) {
    final l = const _L10n();
    final wd = [
      l.archive_weekday_sun, l.archive_weekday_mon, l.archive_weekday_tue,
      l.archive_weekday_wed, l.archive_weekday_thu, l.archive_weekday_fri,
      l.archive_weekday_sat,
    ][d.weekday % 7];
    return l.archive_date_full(d.month, d.day, wd);
  }

  @override
  Widget build(BuildContext context) {
    // v3 시안 B (책 꺼냄) — 다크 BG + 떠 있는 빨간 책 표지 + 인용구.
    return Container(
      color: const Color(0xFF1C1814),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          children: [
            // 우상단 노란 글로우 (시안 B 의 떠 있는 달)
            SizedBox(
              height: 380,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 글로우
                  Positioned(
                    top: 0,
                    right: -30,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          center: const Alignment(-0.2, -0.2),
                          colors: [
                            Colors.white.withOpacity(0.45),
                            const Color(0xFFC7B68A).withOpacity(0.35),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.45, 0.85],
                        ),
                      ),
                    ),
                  ),
                  // 빨간 책 표지
                  _BookCoverCard(
                      book: book, formatDate: _formatDate, config: config),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // 날짜 + 통계 row
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${_formatKoreanDate(context, book.date)} · 11:42-18:30',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                Text(
                  '${book.attractionIds.length * 2} STAMPS · ${book.badges.length} EGGS',
                  style: TextStyle(
                    color: const Color(0xFFFFC700).withOpacity(0.85),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // 빨간 좌측 막대 + 인용구 (book.story 앞부분)
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                border: const Border(
                  left: BorderSide(color: Color(0xFFE60023), width: 3),
                ),
              ),
              child: Text(
                '"${book.story.of(context).split(RegExp(r'[.。!?]'))[0]}."',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.92),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.55,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 시안 B 의 떠 있는 빨간 책 표지 카드.
class _BookCoverCard extends StatelessWidget {
  final _DiaryBook book;
  final _SeasonConfig config;
  final String Function(DateTime) formatDate;
  const _BookCoverCard({
    required this.book,
    required this.config,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    final spineColor = config.spines.first.spine;
    return Container(
      width: 240,
      height: 340,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            spineColor,
            Color.lerp(spineColor, Colors.black, 0.35)!,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.55),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SEOULLAND · RE·TRACE',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.6,
              ),
            ),
            const SizedBox(height: 40),
            Builder(builder: (ctx) {
              final h = book.headline.of(ctx);
              return Text(
                h.length > 8 ? '${h.characters.take(8).toString()}…' : h,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  height: 1.25,
                  letterSpacing: -0.4,
                ),
              );
            }),
            const SizedBox(height: 14),
            Text(
              formatDate(book.date),
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
            const Spacer(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // 작은 stamp 2개 (실 어트랙션 매핑)
                for (final id in book.attractionIds.take(2))
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white.withOpacity(0.6), width: 1.2),
                      ),
                      child: Text(
                        _stampCode(id),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ),
                const Spacer(),
                Text(
                  'VOL · ${book.date.year - 2025}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 어트랙션 id 에서 stamp code 추출 — 영문 약자.
  String _stampCode(String id) {
    final byId = {for (final a in kAttractions) a.id: a};
    final name = byId[id]?.name ?? id;
    final ascii = RegExp(r'[A-Za-z]{2,3}').firstMatch(name);
    if (ascii != null) return ascii.group(0)!.toUpperCase();
    final num = RegExp(r'\d{3}').firstMatch(name);
    if (num != null) return num.group(0)!;
    return name.characters.take(2).toString();
  }
}

// ─── 페이지 2: 탐험 일지 ──────────────────────────────────
class _PageJournal extends StatelessWidget {
  final _DiaryBook book;
  final _SeasonConfig config;
  const _PageJournal({required this.book, required this.config});

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
    // v3 시안 C 왼쪽 페이지 — 흰 BG + CH·02 탐험 일지 빨간 eyebrow + 어트랙션 stamps
    return Container(
      color: Colors.white,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        children: [
          Text(
            const _L10n().archive_ch_02_log,
            style: TextStyle(
              color: const Color(0xFFE60023),
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            const _L10n().archive_visited_count(attrs.length),
            style: const TextStyle(
              color: Color(0xFF111111),
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '11:42 → 18:30 · 6h 48m',
            style: TextStyle(
              color: const Color(0xFF707070),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          // 어트랙션 stamp 리스트 (시안 C)
          if (attrs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Text(
                const _L10n().archive_no_attractions,
                style: const TextStyle(color: Color(0xFF9A9A9A), fontSize: 13),
              ),
            )
          else
            for (final a in attrs)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _JournalAttractionRow(attraction: a),
              ),
          const SizedBox(height: 20),
          // dashed divider
          const _JournalDashedRule(),
          const SizedBox(height: 14),
          // 미션 섹션 (compact list)
          Text(
            const _L10n().archive_todays_missions,
            style: TextStyle(
              color: const Color(0xFFE60023),
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          for (final m in book.missions)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(
                    m.completed
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 16,
                    color: m.completed
                        ? const Color(0xFFE60023)
                        : const Color(0xFFC4C4C4),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      m.label.of(context),
                      style: TextStyle(
                        color: const Color(0xFF333333),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        decoration: m.completed
                            ? null
                            : TextDecoration.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (book.badges.isNotEmpty) ...[
            const SizedBox(height: 18),
            const _JournalDashedRule(),
            const SizedBox(height: 14),
            Text(
              const _L10n().archive_earned_badges,
              style: TextStyle(
                color: const Color(0xFFE60023),
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  book.badges.map((b) => _BadgeChip(spec: b)).toList(),
            ),
          ],
          const SizedBox(height: 28),
          // 페이지 번호
          Center(
            child: Text(
              '— p. 8 of 12 —',
              style: TextStyle(
                color: const Color(0xFF9A9A9A),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _JournalDashedRule extends StatelessWidget {
  const _JournalDashedRule();
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 1,
      child: CustomPaint(painter: _HDashPainter()),
    );
  }
}

class _HDashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE5E5E5)
      ..strokeWidth = 1;
    const dash = 4.0, gap = 4.0;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + dash, 0), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_HDashPainter o) => false;
}

class _JournalAttractionRow extends StatelessWidget {
  final Attraction attraction;
  const _JournalAttractionRow({required this.attraction});

  String get _stampCode {
    final n = attraction.name;
    final ascii = RegExp(r'[A-Za-z]{2,3}').firstMatch(n);
    if (ascii != null) return ascii.group(0)!.toUpperCase();
    final num = RegExp(r'\d{3}').firstMatch(n);
    if (num != null) return num.group(0)!;
    return n.characters.take(2).toString();
  }

  String get _timeLabel {
    // 시안 — 11:42, 13:10 형식 mock time
    final h = (attraction.waitMinutes.hashCode % 8 + 10).toString();
    final m = ((attraction.id.hashCode.abs()) % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final tone = attraction.category == '카페'
        ? const Color(0xFFFFC700)
        : attraction.category == '음식점'
            ? const Color(0xFFFFF4C7)
            : attraction.category == '포토스팟'
                ? const Color(0xFFFFE0E6)
                : attraction.thrillLevel >= 4
                    ? const Color(0xFFE60023)
                    : const Color(0xFFDDEEFB);
    final ink = attraction.category == '카페' || attraction.thrillLevel >= 4
        ? Colors.white
        : const Color(0xFF111111);
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: tone,
            border: Border.all(
                color: Colors.black.withOpacity(0.08), width: 1),
          ),
          child: Text(
            _stampCode,
            style: TextStyle(
              color: ink,
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
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
                  color: Color(0xFF111111),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _timeLabel,
                style: const TextStyle(
                  color: Color(0xFF707070),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BadgeChip extends StatelessWidget {
  final _BadgeSpec spec;
  const _BadgeChip({required this.spec});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_Vintage.parchmentLight, _Vintage.parchmentDark],
        ),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: _Vintage.gold.withOpacity(0.6), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(spec.emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text(
            spec.label.of(context),
            style: _serif(
              size: 11,
              weight: FontWeight.w800,
              color: _Vintage.inkDark,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 페이지 3: 추억의 장 (스토리 + 사진 옵션) ─────────────
class _PageMemory extends StatelessWidget {
  final _DiaryBook book;
  final _SeasonConfig config;
  final VoidCallback onPickGallery;
  final VoidCallback onPickCamera;
  final VoidCallback onRemovePhoto;
  const _PageMemory({
    required this.book,
    required this.config,
    required this.onPickGallery,
    required this.onPickCamera,
    required this.onRemovePhoto,
  });

  @override
  Widget build(BuildContext context) {
    final userPhoto = _PhotoStore.photoOf(book.id);
    final hasPhoto = userPhoto != null || book.sampleIllustration != null;
    // v3 시안 C 오른쪽 페이지 — 흰 BG + CH·03 추억의 장 빨간 eyebrow + 사진 + 인용
    return Container(
      color: Colors.white,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        children: [
          Text(
            const _L10n().archive_ch_03_memory,
            style: TextStyle(
              color: const Color(0xFFE60023),
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 16),
          // 스토리 (필기체 느낌 — 세리프 + 줄 라인)
          Container(
            padding: const EdgeInsets.all(16),
            // Non-uniform Border + borderRadius is illegal; left red-accent
            // bar rendered as a separate Container via Stack below would have
            // worked, but here we drop the radius — the left rule is the
            // pull-quote signal.
            decoration: BoxDecoration(
              color: _Vintage.parchmentLight,
              border: Border(
                left: BorderSide(
                    color: _Vintage.stampRed.withOpacity(0.6), width: 3),
              ),
            ),
            child: Text(
              book.story.of(context),
              style: _serif(
                size: 14,
                color: _Vintage.inkBody,
                height: 1.9,
                letterSpacing: 0.2,
              ),
            ),
          ),
          const SizedBox(height: 24),
          // 사진 영역 (옵션)
          Center(
            child: hasPhoto
                ? _Polaroid(
                    userPhotoPath: userPhoto,
                    sample: book.sampleIllustration,
                    caption: '${book.date.month}.${book.date.day}',
                  )
                : _VintageStamp(
                    main: const _L10n().archive_explore_success,
                    sub: 'MISSION COMPLETE',
                    color: _Vintage.stampRed,
                  ),
          ),
          const SizedBox(height: 18),
          // 사진 액션 — 단순한 텍스트 버튼들
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (userPhoto == null) ...[
                _PhotoActionBtn(
                  icon: Icons.photo_library_rounded,
                  label: const _L10n().archive_photo_gallery,
                  onTap: onPickGallery,
                  primary: true,
                ),
                const SizedBox(width: 10),
                _PhotoActionBtn(
                  icon: Icons.camera_alt_rounded,
                  label: const _L10n().archive_photo_camera,
                  onTap: onPickCamera,
                  primary: false,
                ),
              ] else ...[
                _PhotoActionBtn(
                  icon: Icons.edit_rounded,
                  label: const _L10n().archive_photo_replace,
                  onTap: onPickGallery,
                  primary: true,
                ),
                const SizedBox(width: 10),
                _PhotoActionBtn(
                  icon: Icons.delete_outline_rounded,
                  label: const _L10n().archive_photo_delete,
                  onTap: onRemovePhoto,
                  primary: false,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ─── 폴라로이드 (사진 있을 때 레이어) ─────────────────────
class _Polaroid extends StatelessWidget {
  final String? userPhotoPath;
  final _SampleIllustration? sample;
  final String caption;
  const _Polaroid({
    required this.userPhotoPath,
    required this.sample,
    required this.caption,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.045,
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
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: SizedBox(
                width: 200,
                height: 200,
                child: userPhotoPath != null
                    ? _NetworkOrFileImage(path: userPhotoPath!)
                    : _IllustrationFill(sample: sample!),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 32,
              child: Center(
                child: Text(
                  caption,
                  style: _serif(
                    size: 14,
                    weight: FontWeight.w700,
                    color: _Vintage.inkMid,
                    style: FontStyle.italic,
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

class _IllustrationFill extends StatelessWidget {
  final _SampleIllustration sample;
  const _IllustrationFill({required this.sample});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: sample.gradient,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        sample.emoji,
        style: const TextStyle(fontSize: 80),
      ),
    );
  }
}

class _NetworkOrFileImage extends StatelessWidget {
  final String path;
  const _NetworkOrFileImage({required this.path});

  Widget _broken() => Container(
        color: _Vintage.parchment,
        alignment: Alignment.center,
        child: const Icon(Icons.broken_image_rounded,
            color: _Vintage.inkMid, size: 32),
      );

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Image.network(path,
          fit: BoxFit.cover, errorBuilder: (_, __, ___) => _broken());
    }
    return Image.file(io.File(path),
        fit: BoxFit.cover, errorBuilder: (_, __, ___) => _broken());
  }
}

// ─── 빈티지 도장 (사진 없을 때) ──────────────────────────
class _VintageStamp extends StatelessWidget {
  final String main;
  final String sub;
  final Color color;
  const _VintageStamp(
      {required this.main, required this.sub, required this.color});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.09,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
        decoration: BoxDecoration(
          border: Border.all(color: color, width: 3),
          borderRadius: BorderRadius.circular(10),
          // 도장 잉크 번짐 느낌 — 안쪽 라인
          gradient: RadialGradient(
            colors: [color.withOpacity(0.05), color.withOpacity(0.0)],
            radius: 1.0,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                border: Border.all(color: color.withOpacity(0.6), width: 1),
              ),
              child: Text(
                sub,
                style: _serif(
                  size: 9,
                  weight: FontWeight.w900,
                  color: color.withOpacity(0.85),
                  letterSpacing: 3,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              main,
              style: _serif(
                size: 22,
                weight: FontWeight.w900,
                color: color,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: 80, height: 1,
              color: color.withOpacity(0.6),
            ),
            const SizedBox(height: 6),
            Text(
              'RETRACE · SEOULLAND',
              style: _serif(
                size: 8,
                weight: FontWeight.w900,
                color: color.withOpacity(0.7),
                letterSpacing: 2.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 사진 액션 버튼 ──────────────────────────────────────
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
      height: 40,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 14),
        label: Text(
          label,
          style: _serif(
              size: 12,
              weight: FontWeight.w800,
              color: primary ? _Vintage.parchmentLight : _Vintage.inkDark),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor:
              primary ? _Vintage.leather : _Vintage.parchmentLight,
          foregroundColor:
              primary ? _Vintage.parchmentLight : _Vintage.inkDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
          side: BorderSide(
            color: primary
                ? Colors.transparent
                : _Vintage.leather.withOpacity(0.3),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
        ),
      ),
    );
  }
}

// ─── 페이지 인디케이터 ────────────────────────────────────
class _PageIndicator extends StatelessWidget {
  final int current;
  final int total;
  final bool isDark;
  const _PageIndicator({
    required this.current,
    required this.total,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final active = isDark ? Colors.white : _Vintage.inkDark;
    final inactive = isDark
        ? Colors.white.withOpacity(0.25)
        : _Vintage.inkDark.withOpacity(0.2);
    return Container(
      color: isDark ? const Color(0xFF1C1814) : Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(total, (i) {
          final isActive = i == current;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: isActive ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: isActive ? active : inactive,
                borderRadius: BorderRadius.circular(99),
              ),
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
  final _Season season;
  const _DiaryStats({required this.books, required this.config, required this.season});

  @override
  Widget build(BuildContext context) {
    final withPhoto = books.where((b) {
      return _PhotoStore.photoOf(b.id) != null ||
          b.sampleIllustration != null;
    }).length;
    final eventChapters = _EventShelf.eventChaptersUnlocked(books);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _Vintage.parchmentLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _Vintage.leather.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Expanded(
              child: _StatItem(
                  label: const _L10n().archive_stat_collected,
                  value: '${books.length}',
                  unit: const _L10n().archive_book_count_unit,
                  color: config.titleColor)),
          Container(
              width: 1,
              height: 36,
              color: _Vintage.leather.withOpacity(0.15)),
          Expanded(
              child: _StatItem(
                  label: const _L10n().archive_stat_photo_attached,
                  value: '$withPhoto',
                  unit: const _L10n().archive_book_count_unit,
                  color: config.titleColor)),
          Container(
              width: 1,
              height: 36,
              color: _Vintage.leather.withOpacity(0.15)),
          Expanded(
              child: _StatItem(
                  label: const _L10n().archive_stat_event_chapters,
                  value: '$eventChapters',
                  unit: '',
                  color: config.titleColor)),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label, value, unit;
  final Color color;
  const _StatItem({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
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
            Text(value,
                style: _serif(
                  size: 20,
                  weight: FontWeight.w900,
                  color: color,
                )),
            if (unit.isNotEmpty) ...[
              const SizedBox(width: 2),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(unit,
                    style: _serif(
                      size: 10,
                      weight: FontWeight.w700,
                      color: _Vintage.inkMid,
                    )),
              ),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Text(label,
            style: _serif(
              size: 10,
              weight: FontWeight.w700,
              color: _Vintage.inkMid,
            )),
      ],
    );
  }
}

// ─── 시즌 리워드 진행도 카드 (3개 → 굿즈 / 5개 → 자유이용권) ──
class _RewardProgressCard extends StatefulWidget {
  final _Season season;
  const _RewardProgressCard({required this.season});

  @override
  State<_RewardProgressCard> createState() => _RewardProgressCardState();
}

class _RewardProgressCardState extends State<_RewardProgressCard> {
  // 시즌별 챕터 타겟 (lib/models/chapter.dart 와 동일)
  static const Map<_Season, List<String>> _targets = {
    _Season.spring: ['a08', 'a14', 'a09', 'a15', 'a07'],
    _Season.summer: ['a03', 'a06', 'a04', 'a05', 'a02'],
    _Season.autumn: ['a01', 'a07', 'a12', 'a14', 'a08'],
    _Season.winter: ['a13', 'a11', 'a02', 'a10', 'a08'],
  };

  int _found = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void didUpdateWidget(covariant _RewardProgressCard old) {
    super.didUpdateWidget(old);
    if (old.season != widget.season) _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final discovered = await EasterEggService.discoveredAll();
    final targets = _targets[widget.season] ?? const <String>[];
    final found = targets.where(discovered.contains).length;
    if (!mounted) return;
    setState(() {
      _found = found;
      _loading = false;
    });
  }

  Future<void> _claimNow() async {
    // RewardController stub — backend reward flow not on this branch
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l = const _L10n();
    final total = (_targets[widget.season] ?? const []).length;
    final hasThreshold = _found >= 3;
    final allDone = _found >= 5;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0B84A), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(l.reward_progress_title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF8A6300),
                      letterSpacing: -0.3,
                    )),
              ),
              Text(
                _loading ? '—' : l.reward_progress_books(_found, total),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF8A6300),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: total > 0 ? (_found / total).clamp(0.0, 1.0) : 0,
              minHeight: 8,
              backgroundColor: const Color(0xFFE0B84A).withValues(alpha: 0.25),
              valueColor: const AlwaysStoppedAnimation(Color(0xFFD49A00)),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            allDone
                ? l.reward_progress_completed
                : (hasThreshold
                    ? l.reward_progress_next_at_5
                    : l.reward_progress_next_at_3),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF8A6300),
              height: 1.4,
            ),
          ),
          if (hasThreshold && !_loading) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: ElevatedButton(
                onPressed: _claimNow,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD49A00),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
                ),
                child: Text(l.reward_action_view_code,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ],
      ),
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
        color: const Color(0xFFFFF8E0), // bgYellow (밝은 노랑 틴트 — 가독성↑)
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFC700).withOpacity(0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.tips_and_updates_rounded,
              color: Color(0xFF8A6300), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              const _L10n().archive_hint,
              style: _serif(
                size: 12,
                color: const Color(0xFF5A3F18), // 충분히 진한 갈색 — 가독성
                height: 1.55,
                weight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


// ─── L10n stub — feat/full-backend-stack 의 AppL10n 을 이 브랜치엔 i18n 인프라가 없어 하드코딩 Korean 으로 대체.
// 추후 메인 브랜치 머지 시 이 클래스 제거 + 원본 import 복구.
class _L10n {
  const _L10n();

  // ── archive_screen 에서 사용하는 키 ──
  String get archive_search_title => '책 / 행사 검색';
  String get archive_search_hint => '책 제목 또는 행사명';
  String get archive_search_empty => '검색 결과가 없어요';
  String get archive_next_event_placeholder => '다음 행사 칸 · 방문하면 채워져요';
  String get archive_add_book_coming_soon => '수동 추가는 곧 열려요';
  String get archive_weekday_sun => '일';
  String get archive_weekday_mon => '월';
  String get archive_weekday_tue => '화';
  String get archive_weekday_wed => '수';
  String get archive_weekday_thu => '목';
  String get archive_weekday_fri => '금';
  String get archive_weekday_sat => '토';
  String get reward_progress_title => '🎁 시즌 보상';
  String get reward_progress_next_at_3 => '3개 발견 시 굿즈 쿠폰';
  String get reward_progress_next_at_5 => '5개 발견 시 자유이용권';
  String get reward_progress_completed => '이번 시즌 보상 전부 수령했어요 🎉';
  String get reward_action_view_code => '코드 보기';

  String archive_date_full(int month, int day, String wd) => '$month월 $day일 · $wd요일';
  String archive_event_books_badge(int count) => '$count권';
  String archive_season_range_label(String season, String range) => '$season $range · 서울랜드';
  String reward_progress_books(int n, int total) => '발견 $n / $total';
}
