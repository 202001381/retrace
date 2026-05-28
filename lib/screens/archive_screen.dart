import 'dart:io' as io;
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/attraction.dart';

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
  static const inkFaded = Color(0xFF9A9A9A);      // ink400
  static const leather = Color(0xFF8A6300);       // 옅은 brown (eyebrow 용)
  static const leatherDark = Color(0xFF5A3F18);
  static const shelfWood = Color(0xFF8B5A2B);     // plank 유지
  static const shelfShadow = Color(0xFF5C3A21);
  static const gold = Color(0xFFC99500);
  static const stampRed = Color(0xFFE60023);      // 브랜드 레드
  static const stampInk = Color(0xFF111111);
}

/// 가독성 좋은 세리프 패밀리 — 시스템 폰트 폴백.
const String _kSerif = 'Georgia';
const List<String> _kSerifFallback = ['Times New Roman', 'Times', 'serif'];

TextStyle _serif({
  double size = 14,
  FontWeight weight = FontWeight.w500,
  Color color = _Vintage.inkBody,
  double height = 1.5,
  double letterSpacing = 0,
  FontStyle? style,
}) =>
    TextStyle(
      fontFamily: _kSerif,
      fontFamilyFallback: _kSerifFallback,
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
      fontStyle: style,
    );

class _SeasonConfig {
  final String label, tagline;
  final Color titleColor;
  final IconData icon;
  final List<Color> spines;
  const _SeasonConfig({
    required this.label,
    required this.tagline,
    required this.titleColor,
    required this.icon,
    required this.spines,
  });
}

const Map<_Season, _SeasonConfig> _kConfigs = {
  _Season.spring: _SeasonConfig(
    label: '봄',
    tagline: '벚꽃 흩날리는 봄날의 기억',
    titleColor: Color(0xFFA4321E),
    icon: Icons.local_florist_rounded,
    spines: [
      Color(0xFFA8485A), Color(0xFF8B3A4A), Color(0xFFB85C6E),
      Color(0xFF9A4054), Color(0xFFC97B89),
    ],
  ),
  _Season.summer: _SeasonConfig(
    label: '여름',
    tagline: '눈부신 태양 아래 여름날',
    titleColor: Color(0xFF2E5470),
    icon: Icons.wb_sunny_rounded,
    spines: [
      Color(0xFF3A6A8C), Color(0xFF2E5470), Color(0xFF4682B4),
      Color(0xFF1D4E5F), Color(0xFF5B8FA8),
    ],
  ),
  _Season.autumn: _SeasonConfig(
    label: '가을',
    tagline: '단풍 물든 가을의 낭만',
    titleColor: Color(0xFF8B4513),
    icon: Icons.eco_rounded,
    spines: [
      Color(0xFFB8651E), Color(0xFF8B4513), Color(0xFF9A6324),
      Color(0xFFA0522D), Color(0xFFCD7F32),
    ],
  ),
  _Season.winter: _SeasonConfig(
    label: '겨울',
    tagline: '눈 내리는 겨울밤의 동화',
    titleColor: Color(0xFF3D4A56),
    icon: Icons.ac_unit_rounded,
    spines: [
      Color(0xFF4A5A6A), Color(0xFF6B7A8C), Color(0xFF5F7080),
      Color(0xFF3D4A56), Color(0xFF829AAD),
    ],
  ),
};

// ─── 데이터 모델 ─────────────────────────────────────────
/// 방문 날짜 = 고유키. 같은 날짜에 두 권이 생기지 않도록 데이터 단에서 보장.
class _DiaryBook {
  final String id;
  final DateTime date;
  final _Weather weather;
  final String headline;
  final List<String> attractionIds;
  final List<_Mission> missions;
  final List<_BadgeSpec> badges;
  final String story;
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
  final String label; // '맑음 22°C'
  final Color stampColor;
  const _Weather(
      {required this.icon, required this.label, required this.stampColor});
}

class _Mission {
  final String label;
  final bool completed;
  final IconData icon;
  const _Mission({required this.label, required this.completed, required this.icon});
}

class _BadgeSpec {
  final String emoji;
  final String label;
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
      barrierColor: Colors.black.withOpacity(0.65),
      barrierDismissible: true,
      barrierLabel: '닫기',
      transitionDuration: const Duration(milliseconds: 360),
      pageBuilder: (ctx, anim, secAnim) {
        return _DiaryDialog(
          config: _kConfigs[_season]!,
          books: _diaries[_season]!,
          initialBookIndex: index,
          onPhotoChanged: () => setState(() {}),
        );
      },
      transitionBuilder: (ctx, anim, secAnim, child) {
        final curve = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
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

  @override
  Widget build(BuildContext context) {
    final config = _kConfigs[_season]!;
    final books = _diaries[_season]!;
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
            _Header(season: _season, onChange: (s) => setState(() => _season = s)),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                children: [
                  // v3 — _SeasonBanner 제거 (Bookshelf chapter header 와 중복).
                  _Bookshelf(
                      config: config, books: books, onBookTap: _openDiary),
                  const SizedBox(height: 20),
                  _DiaryStats(books: books, config: config),
                  const SizedBox(height: 16),
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
  // 1일 1권 — 각 책 date 가 시즌 내에서 유일.
  // 사진 있는 책 vs 사진 없는 책 — sampleIllustration 으로 시뮬레이션.
  static Map<_Season, List<_DiaryBook>> _buildMockDiaries() {
    return {
      _Season.spring: [
        _DiaryBook(
          id: 'd_2026_04_14',
          date: DateTime(2026, 4, 14, 14, 30),
          weather: const _Weather(icon: '☀️', label: '맑음 22°C', stampColor: _Vintage.stampRed),
          headline: '벚꽃 흩날리는 첫 봄나들이',
          attractionIds: const ['cherry_blossom_path', 'carousel'],
          missions: const [
            _Mission(label: '회전목마 50m 진입', completed: true, icon: Icons.celebration_rounded),
            _Mission(label: '벚꽃길 산책 완주', completed: true, icon: Icons.directions_walk_rounded),
            _Mission(label: '오후 야외 어트랙션 3회', completed: false, icon: Icons.sunny),
          ],
          badges: const [
            _BadgeSpec(emoji: '🌸', label: '봄의 시작'),
            _BadgeSpec(emoji: '📷', label: '첫 방문 기록자'),
          ],
          story:
              '벚꽃이 만개한 4월의 오후, 친구들과 손을 잡고 걸었던 그 길. 바람이 불 때마다 머리 위로 꽃잎이 쏟아져 내렸어요. '
              '카메라를 꺼낼 새도 없이 그 순간이 너무 빠르게 지나가서, 결국엔 눈에 담는 것으로 만족했답니다. '
              '점심엔 회전목마 옆 카페에서 봄 한정 음료를 마셨고, 해가 기울 무렵에야 천천히 정문을 나왔습니다.',
          sampleIllustration: const _SampleIllustration(
            gradient: [Color(0xFFFCE4EC), Color(0xFFF8BBD0), Color(0xFFE91E63)],
            emoji: '🌸',
          ),
        ),
        _DiaryBook(
          id: 'd_2026_04_21',
          date: DateTime(2026, 4, 21, 11, 15),
          weather: const _Weather(icon: '⛅', label: '구름 많음 18°C', stampColor: _Vintage.stampInk),
          headline: '어른의 회전목마, 다시 동심',
          attractionIds: const ['carousel'],
          missions: const [
            _Mission(label: '회전목마 탑승', completed: true, icon: Icons.attractions_rounded),
            _Mission(label: '캐릭터 타운 전체 산책', completed: true, icon: Icons.map_rounded),
          ],
          badges: const [
            _BadgeSpec(emoji: '🎠', label: '동심 회복'),
          ],
          story:
              '어릴 적 엄마 손을 잡고 처음 탔던 회전목마. 어른이 되어 다시 올라타니 그 시절의 설렘이 그대로 떠올랐어요. '
              '음악도, 조명도, 거울에 비친 풍경도 모두 그대로였답니다.',
          // sampleIllustration 없음 → 빈티지 스탬프 표시
        ),
        _DiaryBook(
          id: 'd_2026_05_05',
          date: DateTime(2026, 5, 5, 12, 0),
          weather: const _Weather(icon: '☀️', label: '맑음 24°C', stampColor: _Vintage.stampRed),
          headline: '어린이날, 가족 총출동',
          attractionIds: const ['mini_viking', 'carousel', 'bumper_car'],
          missions: const [
            _Mission(label: '가족 단체 사진 촬영', completed: true, icon: Icons.groups_rounded),
            _Mission(label: '미니바이킹 첫 탑승', completed: true, icon: Icons.sailing_rounded),
            _Mission(label: '범퍼카 5회 이상', completed: false, icon: Icons.directions_car_rounded),
          ],
          badges: const [
            _BadgeSpec(emoji: '👨‍👩‍👧‍👦', label: '패밀리 데이'),
            _BadgeSpec(emoji: '🎈', label: '어린이날 마스터'),
          ],
          story:
              '온 가족이 다 모인 어린이날. 조카들이 처음 타본 미니바이킹에서 환하게 웃던 그 표정, 평생 기억에 남을 것 같아요. '
              '점심엔 다 같이 모여 사진을 찍었는데 아빠가 셀카봉을 처음 써보셨답니다.',
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
          weather: const _Weather(icon: '☀️', label: '맑음 31°C', stampColor: _Vintage.stampRed),
          headline: '한여름 야간개장의 매력',
          attractionIds: const ['galaxy_888', 'carousel'],
          missions: const [
            _Mission(label: '야간 어트랙션 3종', completed: true, icon: Icons.nightlight_round),
            _Mission(label: '21시 이후 분수쇼 관람', completed: true, icon: Icons.celebration_rounded),
          ],
          badges: const [
            _BadgeSpec(emoji: '🌃', label: '야경 헌터'),
          ],
          story:
              '해가 진 후의 서울랜드는 완전 다른 분위기예요. 낮엔 봐도 그냥 지나치던 조명들이 모두 살아 움직였어요. '
              '은하열차의 야간 라이드는 그 어떤 어트랙션보다도 짜릿했답니다.',
          // 사진 없음 → 빈티지 스탬프
        ),
        _DiaryBook(
          id: 'd_2025_07_20',
          date: DateTime(2025, 7, 20, 13, 30),
          weather: const _Weather(icon: '☀️', label: '폭염 33°C', stampColor: _Vintage.stampRed),
          headline: '스카이엑스에서 본 여름 하늘',
          attractionIds: const ['sky_x'],
          missions: const [
            _Mission(label: '스카이엑스 첫 도전', completed: true, icon: Icons.paragliding_rounded),
            _Mission(label: '익스트림 라이드 2회', completed: true, icon: Icons.bolt_rounded),
          ],
          badges: const [
            _BadgeSpec(emoji: '🪂', label: '스릴 마스터'),
            _BadgeSpec(emoji: '☀️', label: '여름의 정점'),
          ],
          story:
              '70m 상공에서 떨어지던 그 순간, 시간이 멈춘 듯했어요. 떨어지는 동안 본 푸른 여름 하늘이 잊혀지지 않아요. '
              '내려와서 다시 줄을 섰더니 친구가 어이없어했답니다.',
          sampleIllustration: const _SampleIllustration(
            gradient: [Color(0xFFE3F2FD), Color(0xFF64B5F6), Color(0xFF1976D2)],
            emoji: '🪂',
          ),
        ),
        _DiaryBook(
          id: 'd_2025_08_05',
          date: DateTime(2025, 8, 5, 15, 10),
          weather: const _Weather(icon: '⛈️', label: '뇌우 28°C', stampColor: _Vintage.stampInk),
          headline: '뇌우 피해 실내 어트랙션 종일',
          attractionIds: const ['bumper_car', 'time_machine_5d'],
          missions: const [
            _Mission(label: '실내 어트랙션 3종 클리어', completed: true, icon: Icons.house_rounded),
            _Mission(label: '범퍼카 단체전', completed: true, icon: Icons.directions_car_rounded),
          ],
          badges: const [
            _BadgeSpec(emoji: '☂️', label: '비 오는 날 탐험가'),
          ],
          story:
              '오후부터 비가 쏟아져서 실내 위주로 다녔어요. 오히려 사람이 적어서 여유로웠고, '
              '범퍼카는 같은 자리에서 30분 동안 연속으로 탔답니다.',
        ),
      ],
      _Season.autumn: [
        _DiaryBook(
          id: 'd_2025_10_18',
          date: DateTime(2025, 10, 18, 14, 20),
          weather: const _Weather(icon: '☀️', label: '맑음 19°C', stampColor: _Vintage.stampRed),
          headline: '단풍 사이로 달린 은하열차',
          attractionIds: const ['galaxy_888', 'gyro_swing'],
          missions: const [
            _Mission(label: '단풍 명소 3곳 방문', completed: true, icon: Icons.park_rounded),
            _Mission(label: '은하열차 야간 라이드', completed: false, icon: Icons.train_rounded),
          ],
          badges: const [
            _BadgeSpec(emoji: '🍁', label: '단풍 헌터'),
          ],
          story:
              '단풍이 물든 풍경 사이로 질주하는 은하열차. 바람에 실려오는 가을 향기와 함께 달렸던 그 코스가 최고였어요.',
          sampleIllustration: const _SampleIllustration(
            gradient: [Color(0xFFFFF3E0), Color(0xFFFFB74D), Color(0xFFE65100)],
            emoji: '🍁',
          ),
        ),
        _DiaryBook(
          id: 'd_2025_10_25',
          date: DateTime(2025, 10, 25, 16, 10),
          weather: const _Weather(icon: '⛅', label: '구름 16°C', stampColor: _Vintage.stampInk),
          headline: '가을 야경 둘만의 데이트',
          attractionIds: const ['shot_drop', 'galaxy_888'],
          missions: const [
            _Mission(label: '저녁 야경 어트랙션', completed: true, icon: Icons.nightlight_round),
            _Mission(label: '단풍 포토스팟 통과', completed: true, icon: Icons.camera_alt_rounded),
          ],
          badges: const [
            _BadgeSpec(emoji: '💕', label: '데이트 마스터'),
          ],
          story:
              '단풍이 절정이던 날, 둘이서 천천히 걸으며 본 풍경. 시간이 멈췄으면 좋겠다 싶었어요. '
              '저녁엔 야경 명소에서 잠시 쉬며 그날의 모든 것을 마음에 담았습니다.',
        ),
      ],
      _Season.winter: [
        _DiaryBook(
          id: 'd_2024_12_24',
          date: DateTime(2024, 12, 24, 18, 30),
          weather: const _Weather(icon: '❄️', label: '눈 -2°C', stampColor: _Vintage.stampInk),
          headline: '눈 내리는 회전목마, 동화의 밤',
          attractionIds: const ['carousel', 'santa_restaurant'],
          missions: const [
            _Mission(label: '눈 오는 날 야간 방문', completed: true, icon: Icons.ac_unit_rounded),
            _Mission(label: '산타레스토랑 식사', completed: true, icon: Icons.restaurant_rounded),
            _Mission(label: '눈 인증샷 5장', completed: false, icon: Icons.camera_alt_rounded),
          ],
          badges: const [
            _BadgeSpec(emoji: '🎄', label: '크리스마스 이브'),
            _BadgeSpec(emoji: '❄️', label: '겨울 동화'),
          ],
          story:
              '함박눈이 내리던 12월 24일 저녁, 조명이 켜진 회전목마. 한 폭의 동화 같았던 그 풍경을 잊을 수 없어요. '
              '추워서 손이 곱아도 카메라 셔터를 멈출 수 없었답니다.',
          sampleIllustration: const _SampleIllustration(
            gradient: [Color(0xFFE1F5FE), Color(0xFFB3E5FC), Color(0xFF0288D1)],
            emoji: '🎄',
          ),
        ),
        _DiaryBook(
          id: 'd_2025_01_01',
          date: DateTime(2025, 1, 1, 13, 0),
          weather: const _Weather(icon: '☀️', label: '맑음 1°C', stampColor: _Vintage.stampRed),
          headline: '새해 첫 방문, 타임머신 5D',
          attractionIds: const ['time_machine_5d'],
          missions: const [
            _Mission(label: '새해 첫 어트랙션', completed: true, icon: Icons.celebration_rounded),
            _Mission(label: '5D 영상 관람', completed: true, icon: Icons.movie_rounded),
          ],
          badges: const [
            _BadgeSpec(emoji: '🎊', label: '새해 첫 도전'),
          ],
          story:
              '새해 첫날 가족과 함께 본 5D 영상. 미래의 한 장면 같았던 그 경험이 새해의 시작을 특별하게 만들어줬어요.',
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

class _PaperGrainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(42);
    final paint = Paint()..color = _Vintage.inkFaded.withOpacity(0.05);
    for (var i = 0; i < 80; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      canvas.drawCircle(Offset(x, y), rng.nextDouble() * 0.8 + 0.2, paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// ─── 헤더 (시즌 탭) ──────────────────────────────────────
class _Header extends StatelessWidget {
  final _Season season;
  final ValueChanged<_Season> onChange;
  const _Header({required this.season, required this.onChange});

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
          // v3 — 작은 RETRACE ARCHIVE eyebrow + 28px 큰 헤드라인
          Text(
            'RETRACE ARCHIVE · vol.1',
            style: _serif(
              size: 10,
              weight: FontWeight.w800,
              color: _Vintage.leather,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '기억의 책장',
            style: _serif(
              size: 28,
              weight: FontWeight.w900,
              color: _Vintage.inkDark,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '서울랜드를 찾은 날들이 한 권씩 쌓이고 있어요',
            style: _serif(
              size: 12,
              weight: FontWeight.w500,
              color: _Vintage.inkMid,
            ),
          ),
          const SizedBox(height: 16),
          // v3 시즌 탭 — 흰색 pill bar + 각 항목 좌측 작은 dot (active=red filled).
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: _Vintage.leather.withOpacity(0.2)),
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
                      return Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onChange(s),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOut,
                            decoration: BoxDecoration(
                              color: active
                                  ? _Vintage.parchment
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: active
                                        ? const Color(0xFFE60023) // red
                                        : Colors.transparent,
                                    border: active
                                        ? null
                                        : Border.all(
                                            color: _Vintage.leather
                                                .withOpacity(0.4),
                                            width: 1.5),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _kConfigs[s]!.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.clip,
                                  style: _serif(
                                    size: 13,
                                    weight: active
                                        ? FontWeight.w900
                                        : FontWeight.w600,
                                    color: active
                                        ? _Vintage.inkDark
                                        : _Vintage.inkMid,
                                    letterSpacing: 0.4,
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
        ],
      ),
    );
  }
}

class _SeasonBanner extends StatelessWidget {
  final _SeasonConfig config;
  const _SeasonBanner({required this.config});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _Vintage.parchmentLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _Vintage.leather.withOpacity(0.15)),
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
                  style: _serif(
                    size: 18,
                    weight: FontWeight.w900,
                    color: config.titleColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  config.tagline,
                  style: _serif(size: 12, color: _Vintage.inkMid),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 책장 ────────────────────────────────────────────────
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
        // v3 시즌 챕터 헤더 — CHAPTER · SPRING eyebrow + 22px 챕터명 + N권 카운트
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'CHAPTER · ${config.label.toUpperCase()}',
                      style: _serif(
                        size: 10,
                        weight: FontWeight.w900,
                        color: const Color(0xFFE60023), // red
                        letterSpacing: 1.6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      config.tagline,
                      style: _serif(
                        size: 22,
                        weight: FontWeight.w900,
                        color: _Vintage.inkDark,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'YEAR · ${DateTime.now().year}',
                      style: _serif(
                        size: 10,
                        weight: FontWeight.w800,
                        color: _Vintage.inkMid,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${books.length}\n권',
                textAlign: TextAlign.right,
                style: _serif(
                  size: 11,
                  weight: FontWeight.w800,
                  color: _Vintage.leather,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
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
                    final color = config.spines[i % config.spines.length];
                    return _BookSpine(
                      book: books[i],
                      color: color,
                      onTap: () => onBookTap(i),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 10),
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

class _BookSpine extends StatelessWidget {
  final _DiaryBook book;
  final Color color;
  final VoidCallback onTap;
  const _BookSpine(
      {required this.book, required this.color, required this.onTap});

  String get _spineDate {
    final y = book.date.year.toString();
    final m = book.date.month.toString().padLeft(2, '0');
    final d = book.date.day.toString().padLeft(2, '0');
    return '$y.$m.$d';
  }

  @override
  Widget build(BuildContext context) {
    final hasUserPhoto = _PhotoStore.photoOf(book.id) != null;
    final hasSample = book.sampleIllustration != null;
    final hasPhoto = hasUserPhoto || hasSample;
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
            // easeOutBack overshoots beyond 1.0; clamp for Opacity assertion.
            child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
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
            // Non-uniform Border + borderRadius is illegal in Flutter; use a
            // uniform subtle outline and let the gradient carry the highlight.
            border: Border.all(color: Colors.black26, width: 1),
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
              RotatedBox(
                quarterTurns: 3,
                child: Text(
                  _spineDate,
                  style: TextStyle(
                    fontFamily: _kSerif,
                    fontFamilyFallback: _kSerifFallback,
                    color: _Vintage.gold.withOpacity(0.95),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ),
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

// ─── 다이어리 다이얼로그 ──────────────────────────────────
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
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
      child: Container(
        decoration: BoxDecoration(
          color: _Vintage.parchment,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: _Vintage.leather.withOpacity(0.4), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 30,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
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
                    return AnimatedBuilder(
                      animation: _pageCtrl,
                      child: pages[i],
                      builder: (_, child) {
                        double delta = 0;
                        if (_pageCtrl.hasClients &&
                            _pageCtrl.position.hasContentDimensions) {
                          delta = (_pageCtrl.page ?? 0) - i;
                        }
                        final clamped = delta.clamp(-1.0, 1.0);
                        final m = Matrix4.identity()
                          ..setEntry(3, 2, 0.0015)
                          ..rotateY(clamped * 0.55);
                        return Transform(
                          transform: m,
                          alignment: delta < 0
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: child,
                        );
                      },
                    );
                    },
                  ),
                ),
              _PageIndicator(current: _pageIndex, total: 3),
            ],
          ),
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
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: _Vintage.leather,
        border: Border(
          bottom:
              BorderSide(color: _Vintage.gold.withOpacity(0.4), width: 1),
        ),
      ),
      child: Row(
        children: [
          _IconBtn(
              icon: Icons.chevron_left_rounded,
              onTap: onPrev,
              enabled: onPrev != null),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${config.label} CHAPTER',
                    style: _serif(
                      size: 9,
                      weight: FontWeight.w900,
                      color: _Vintage.gold.withOpacity(0.9),
                      letterSpacing: 3,
                    ),
                  ),
                  Text(
                    '$bookIndex / $totalBooks',
                    style: _serif(
                      size: 13,
                      weight: FontWeight.w900,
                      color: _Vintage.parchmentLight,
                    ),
                  ),
                ],
              ),
            ),
          ),
          _IconBtn(
              icon: Icons.chevron_right_rounded,
              onTap: onNext,
              enabled: onNext != null),
          const SizedBox(width: 4),
          _IconBtn(
              icon: Icons.close_rounded, onTap: onClose, enabled: true),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool enabled;
  const _IconBtn(
      {required this.icon, required this.onTap, required this.enabled});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.25,
      child: InkResponse(
        onTap: enabled ? onTap : null,
        radius: 20,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, color: _Vintage.parchmentLight, size: 22),
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
    final wd = const ['일', '월', '화', '수', '목', '금', '토'][d.weekday % 7];
    return '${d.year}년 ${d.month}월 ${d.day}일 · $wd요일';
  }

  @override
  Widget build(BuildContext context) {
    return _ParchmentBackground(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
        child: Column(
          children: [
            // 상단: 날씨 스탬프
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    border: Border.all(
                        color: book.weather.stampColor.withOpacity(0.75),
                        width: 2),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(book.weather.icon,
                          style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 6),
                      Text(
                        book.weather.label,
                        style: _serif(
                          size: 11,
                          weight: FontWeight.w900,
                          color: book.weather.stampColor,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Transform.rotate(
                  angle: 0.06,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _Vintage.stampRed.withOpacity(0.08),
                      border: Border.all(
                          color: _Vintage.stampRed.withOpacity(0.7), width: 1.5),
                    ),
                    child: Text(
                      'VOL. ${book.date.year}',
                      style: _serif(
                        size: 9,
                        weight: FontWeight.w900,
                        color: _Vintage.stampRed,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            // 가운데: 시즌 아이콘 + 큰 헤드라인
            Icon(config.icon, color: config.titleColor, size: 36),
            const SizedBox(height: 18),
            Text(
              book.headline,
              textAlign: TextAlign.center,
              style: _serif(
                size: 26,
                weight: FontWeight.w900,
                color: _Vintage.inkDark,
                height: 1.4,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 24),
            // 장식 구분선 (왼쪽 라인 — 가운데 다이아 — 오른쪽 라인)
            Row(
              children: [
                Expanded(
                    child: Container(
                        height: 1, color: _Vintage.leather.withOpacity(0.3))),
                const SizedBox(width: 8),
                const Icon(Icons.diamond_outlined,
                    color: _Vintage.leather, size: 12),
                const SizedBox(width: 8),
                Expanded(
                    child: Container(
                        height: 1, color: _Vintage.leather.withOpacity(0.3))),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              _formatDate(book.date),
              style: _serif(
                size: 14,
                weight: FontWeight.w700,
                color: _Vintage.inkBody,
                letterSpacing: 0.5,
              ),
            ),
            const Spacer(),
            // 하단 시리즈 표기
            Text(
              '— Daily Exploration Magazine —',
              style: _serif(
                size: 10,
                weight: FontWeight.w700,
                color: _Vintage.inkFaded,
                style: FontStyle.italic,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
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
    return _ParchmentBackground(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        children: [
          _SectionTitle(
              icon: Icons.explore_rounded,
              text: '탐험 일지',
              color: config.titleColor),
          const SizedBox(height: 14),
          // 방문 어트랙션
          _JournalGroup(
            label: '방문한 어트랙션',
            child: Column(
              children: attrs.isEmpty
                  ? [
                      Text(
                        '기록된 어트랙션이 없어요.',
                        style: _serif(size: 12, color: _Vintage.inkFaded),
                      ),
                    ]
                  : attrs
                      .map((a) => _AttractionRow(attraction: a, accent: config.titleColor))
                      .toList(),
            ),
          ),
          const SizedBox(height: 18),
          // 미션
          _JournalGroup(
            label: '오늘의 미션',
            child: Column(
              children: book.missions
                  .map((m) => _MissionRow(mission: m, accent: config.titleColor))
                  .toList(),
            ),
          ),
          const SizedBox(height: 18),
          // 뱃지
          _JournalGroup(
            label: '획득한 뱃지',
            child: book.badges.isEmpty
                ? Text(
                    '획득한 뱃지가 아직 없어요.',
                    style: _serif(size: 12, color: _Vintage.inkFaded),
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children:
                        book.badges.map((b) => _BadgeChip(spec: b)).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _SectionTitle(
      {required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Text(
          text,
          style: _serif(
            size: 18,
            weight: FontWeight.w900,
            color: color,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

class _JournalGroup extends StatelessWidget {
  final String label;
  final Widget child;
  const _JournalGroup({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: _serif(
            size: 11,
            weight: FontWeight.w900,
            color: _Vintage.inkMid,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _Vintage.parchmentLight,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _Vintage.leather.withOpacity(0.15)),
          ),
          child: child,
        ),
      ],
    );
  }
}

class _AttractionRow extends StatelessWidget {
  final Attraction attraction;
  final Color accent;
  const _AttractionRow({required this.attraction, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(attraction.icon, style: const TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  attraction.name,
                  style: _serif(
                      size: 13,
                      weight: FontWeight.w800,
                      color: _Vintage.inkDark),
                ),
                Text(
                  '${attraction.category} · ${attraction.zone}',
                  style: _serif(size: 10, color: _Vintage.inkFaded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MissionRow extends StatelessWidget {
  final _Mission mission;
  final Color accent;
  const _MissionRow({required this.mission, required this.accent});

  @override
  Widget build(BuildContext context) {
    final done = mission.completed;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 22, height: 22,
            decoration: BoxDecoration(
              color: done ? accent : _Vintage.parchment,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                  color:
                      done ? accent : _Vintage.leather.withOpacity(0.3)),
            ),
            alignment: Alignment.center,
            child: done
                ? const Icon(Icons.check_rounded,
                    size: 14, color: Colors.white)
                : Icon(mission.icon,
                    size: 12, color: _Vintage.inkFaded),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              mission.label,
              style: _serif(
                size: 12,
                weight: done ? FontWeight.w700 : FontWeight.w500,
                color: done ? _Vintage.inkDark : _Vintage.inkFaded,
                style: done ? null : FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
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
            spec.label,
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
    return _ParchmentBackground(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        children: [
          _SectionTitle(
            icon: Icons.history_edu_rounded,
            text: '추억의 장',
            color: config.titleColor,
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
              book.story,
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
                    main: '오늘의 탐험 성공',
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
                  label: '갤러리',
                  onTap: onPickGallery,
                  primary: true,
                ),
                const SizedBox(width: 10),
                _PhotoActionBtn(
                  icon: Icons.camera_alt_rounded,
                  label: '촬영',
                  onTap: onPickCamera,
                  primary: false,
                ),
              ] else ...[
                _PhotoActionBtn(
                  icon: Icons.edit_rounded,
                  label: '사진 변경',
                  onTap: onPickGallery,
                  primary: true,
                ),
                const SizedBox(width: 10),
                _PhotoActionBtn(
                  icon: Icons.delete_outline_rounded,
                  label: '삭제',
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
  const _PageIndicator({required this.current, required this.total});

  static const _kLabels = ['표지', '탐험 일지', '추억의 장'];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _Vintage.parchmentDark,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(total, (i) {
          final active = i == current;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  width: active ? 20 : 8,
                  height: 4,
                  decoration: BoxDecoration(
                    color: active
                        ? _Vintage.leather
                        : _Vintage.leather.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _kLabels[i],
                  style: _serif(
                    size: 9,
                    weight: FontWeight.w800,
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
    final withPhoto = books.where((b) {
      return _PhotoStore.photoOf(b.id) != null ||
          b.sampleIllustration != null;
    }).length;
    final firstDate = books.isEmpty ? null : books.first.date;
    final lastDate = books.isEmpty ? null : books.last.date;

    String fmt(DateTime? d) =>
        d == null ? '-' : '${d.month}.${d.day}';

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
                  label: '수집한 추억',
                  value: '${books.length}',
                  unit: '권',
                  color: config.titleColor)),
          Container(
              width: 1,
              height: 36,
              color: _Vintage.leather.withOpacity(0.15)),
          Expanded(
              child: _StatItem(
                  label: '사진 첨부',
                  value: '$withPhoto',
                  unit: '권',
                  color: config.titleColor)),
          Container(
              width: 1,
              height: 36,
              color: _Vintage.leather.withOpacity(0.15)),
          Expanded(
              child: _StatItem(
                  label: '기록 기간',
                  value: '${fmt(firstDate)}~${fmt(lastDate)}',
                  unit: '',
                  color: config.titleColor,
                  compact: true)),
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
            Text(value,
                style: _serif(
                  size: compact ? 13 : 20,
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
              '책을 펴면 3장(표지·탐험 일지·추억의 장)이 나타나요.\n사진은 옵션 — 비어 있어도 빈티지 도장이 자리를 지킵니다.',
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
