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
  static const shelfWood = Color(0xFFEDDFBF);     // 시안 11 cream-tan plank
  static const shelfShadow = Color(0xFFD8C594);
  static const gold = Color(0xFFC99500);
  static const stampRed = Color(0xFFE60023);      // 브랜드 레드
  static const stampInk = Color(0xFF111111);
}

/// 한글 시즌 라벨 → 영문 eyebrow 매핑 (시안 v2 — 11/11b/11c/11d).
const Map<String, String> _kSeasonEng = {
  '봄': 'SPRING',
  '여름': 'SUMMER',
  '가을': 'AUTUMN',
  '겨울': 'WINTER',
};

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
  final Color titleColor; // chapter eyebrow color (시안 v2 — 시즌별 차별)
  final Color plankColor; // 책장 plank (시안 v2 — 시즌별 차별)
  final Color dotColor;   // 시즌 탭 dot 컬러
  final IconData icon;
  final List<Color> spines;
  const _SeasonConfig({
    required this.label,
    required this.tagline,
    required this.titleColor,
    required this.plankColor,
    required this.dotColor,
    required this.icon,
    required this.spines,
  });
}

const Map<_Season, _SeasonConfig> _kConfigs = {
  _Season.spring: _SeasonConfig(
    label: '봄',
    tagline: '벚꽃 흩날리는 봄날',
    titleColor: Color(0xFFE60023), // 빨강
    plankColor: Color(0xFFFBE5E0), // 연 핑크 plank
    dotColor: Color(0xFFE60023),
    icon: Icons.local_florist_rounded,
    spines: [
      Color(0xFFE08494), // rose pink
      Color(0xFFE5A8A8), // pale pink
      Color(0xFFB8D4C5), // mint
      Color(0xFFA8B8CF), // dusty lavender
      Color(0xFFE9D6A8), // beige
    ],
  ),
  _Season.summer: _SeasonConfig(
    label: '여름',
    tagline: '바다 냄새 나는 여름',
    titleColor: Color(0xFF0084E0), // 블루
    plankColor: Color(0xFFFAF7F2), // 크림
    dotColor: Color(0xFF00A8B5),   // 청록
    icon: Icons.wb_sunny_rounded,
    spines: [
      Color(0xFF1F6F7A), // teal
      Color(0xFFE85A4F), // coral red
      Color(0xFFE89A47), // orange
      Color(0xFF3A6FB8), // blue
      Color(0xFFF2C84B), // yellow
    ],
  ),
  _Season.autumn: _SeasonConfig(
    label: '가을',
    tagline: '단풍이 깊어가는 가을',
    titleColor: Color(0xFF8A6300), // 갈색
    plankColor: Color(0xFFFAF1DE), // 따뜻한 cream
    dotColor: Color(0xFFE89A47),   // 주황
    icon: Icons.eco_rounded,
    spines: [
      Color(0xFFC95A2E), // burnt orange
      Color(0xFFA84520), // deep red-brown
      Color(0xFFD49A3D), // gold-ochre
      Color(0xFFB05828), // sienna
      Color(0xFFCB6A2A), // pumpkin
    ],
  ),
  _Season.winter: _SeasonConfig(
    label: '겨울',
    tagline: '눈 내리는 고요한 겨울',
    titleColor: Color(0xFF1F2A44), // 네이비
    plankColor: Color(0xFFF0F4F8), // 차가운 화이트
    dotColor: Color(0xFF3A6FB8),   // 블루
    icon: Icons.ac_unit_rounded,
    spines: [
      Color(0xFF2B4255), // dark navy
      Color(0xFF1A1A1A), // near-black
      Color(0xFF5B4538), // dark brown
      Color(0xFFA7C8E3), // ice blue
      Color(0xFFE5D9C6), // cream
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
            _Header(season: _season, onChange: _onTabChange),
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
                    padding:
                        const EdgeInsets.fromLTRB(20, 20, 20, 40),
                    children: [
                      _Bookshelf(
                          config: cfg,
                          books: list,
                          onBookTap: (idx) => _openDiaryForSeason(s, idx)),
                      const SizedBox(height: 20),
                      _DiaryStats(books: list, config: cfg),
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

  void _openDiaryForSeason(_Season s, int index) {
    showGeneralDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.65),
      barrierDismissible: true,
      barrierLabel: '닫기',
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
                      final cfg = _kConfigs[s]!;
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
                                // 시즌별 컬러 dot — active=채움, inactive=외곽
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: active
                                        ? cfg.dotColor
                                        : Colors.transparent,
                                    border: active
                                        ? null
                                        : Border.all(
                                            color: cfg.dotColor
                                                .withOpacity(0.5),
                                            width: 1.5),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  cfg.label,
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
                      // 시즌 영문명 (CHAPTER · SPRING / SUMMER / AUTUMN / WINTER)
                      'CHAPTER · ${_kSeasonEng[config.label] ?? config.label.toUpperCase()}',
                      style: _serif(
                        size: 10,
                        weight: FontWeight.w900,
                        color: config.titleColor, // 시즌별 컬러
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
            color: config.plankColor, // 시즌별 plank
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(14, 18, 14, 6),
          child: Column(
            children: [
              SizedBox(
                height: 160,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // 실제 책
                    for (var i = 0; i < books.length; i++)
                      _BookSpine(
                        book: books[i],
                        color: config.spines[i % config.spines.length],
                        onTap: () => onBookTap(i),
                      ),
                    // 빈 슬롯 placeholder (시안 11 — 6칸 슬롯 가정)
                    for (var i = 0; i < (6 - books.length).clamp(0, 6); i++)
                      const _EmptyBookSlot(),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Container(
                height: 10,
                decoration: BoxDecoration(
                  // plank 보다 살짝 어두운 톤 — 시즌별 자동 따라감
                  color: Color.lerp(config.plankColor, Colors.black, 0.18),
                  borderRadius:
                      const BorderRadius.vertical(bottom: Radius.circular(8)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 책장 빈 슬롯 — 시안 11 의 dashed 윤곽 placeholder.
class _EmptyBookSlot extends StatelessWidget {
  const _EmptyBookSlot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 130,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(2),
          topRight: Radius.circular(2),
        ),
      ),
      child: CustomPaint(painter: _DashedSlotPainter()),
    );
  }
}

class _DashedSlotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _Vintage.leather.withOpacity(0.28)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    const dash = 3.0, gap = 3.0;
    // top
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + dash, 0), paint);
      x += dash + gap;
    }
    // left
    double y = 0;
    while (y < size.height) {
      canvas.drawLine(Offset(0, y), Offset(0, y + dash), paint);
      y += dash + gap;
    }
    // right
    y = 0;
    while (y < size.height) {
      canvas.drawLine(
          Offset(size.width, y), Offset(size.width, y + dash), paint);
      y += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_DashedSlotPainter o) => false;
}

class _BookSpine extends StatelessWidget {
  final _DiaryBook book;
  final Color color;
  final VoidCallback onTap;
  const _BookSpine(
      {required this.book, required this.color, required this.onTap});

  String get _spineDate {
    final m = book.date.month.toString();
    final d = book.date.day.toString().padLeft(2, '0');
    return '$m.$d';
  }

  /// v3 시안 11 — 책 spine 에 헤드라인을 한 글자씩 세로 적층.
  /// 공백·구두점은 제외, 최대 5자.
  List<String> get _spineChars {
    final cleaned = book.headline.replaceAll(RegExp(r'[\s·,.!?]'), '');
    return cleaned.characters.take(5).toList();
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
              // 상·하 금장 띠
              Positioned(
                top: 10,
                child: Container(
                  width: 30,
                  height: 1,
                  color: _Vintage.gold.withOpacity(0.6),
                ),
              ),
              Positioned(
                bottom: 18,
                child: Container(
                  width: 30,
                  height: 1,
                  color: _Vintage.gold.withOpacity(0.6),
                ),
              ),
              // 세로 적층된 헤드라인 (시안 11)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final ch in _spineChars)
                      Text(
                        ch,
                        style: TextStyle(
                          fontFamily: _kSerif,
                          fontFamilyFallback: _kSerifFallback,
                          color: _Vintage.gold.withOpacity(0.92),
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          height: 1.15,
                          letterSpacing: 0,
                        ),
                      ),
                  ],
                ),
              ),
              // 하단 작은 날짜 라벨 (4.14 식)
              Positioned(
                bottom: 6,
                child: Text(
                  _spineDate,
                  style: TextStyle(
                    fontFamily: _kSerif,
                    fontFamilyFallback: _kSerifFallback,
                    color: _Vintage.gold.withOpacity(0.7),
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              if (hasPhoto)
                Positioned(
                  bottom: -2,
                  right: 4,
                  child: Container(
                    width: 5,
                    height: 5,
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
                    '${config.label.toUpperCase()} · VOL.1',
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

  String _formatKoreanDate(DateTime d) {
    final wd = const ['일', '월', '화', '수', '목', '금', '토'][d.weekday % 7];
    return '${d.month}월 ${d.day}일 · $wd요일';
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
                    '${_formatKoreanDate(book.date)} · 11:42-18:30',
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
                '"${book.story.split(RegExp(r'[.。!?]'))[0]}."',
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
    final spineColor = config.spines.first;
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
            Text(
              book.headline.length > 8
                  ? '${book.headline.characters.take(8).toString()}…'
                  : book.headline,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                height: 1.25,
                letterSpacing: -0.4,
              ),
            ),
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
            'CH · 02 · 탐험 일지',
            style: TextStyle(
              color: const Color(0xFFE60023),
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${attrs.length}곳을 거쳤어요',
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
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Text(
                '기록된 어트랙션이 없어요.',
                style: TextStyle(color: Color(0xFF9A9A9A), fontSize: 13),
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
            '오늘의 미션',
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
                      m.label,
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
              '획득한 뱃지',
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
    // v3 시안 C 오른쪽 페이지 — 흰 BG + CH·03 추억의 장 빨간 eyebrow + 사진 + 인용
    return Container(
      color: Colors.white,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        children: [
          Text(
            'CH · 03 · 추억의 장',
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
