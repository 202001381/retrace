import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/attraction.dart';

class ArchiveScreen extends StatefulWidget {
  const ArchiveScreen({super.key});
  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

enum _Season { spring, summer, autumn, winter }

class _SeasonConfig {
  final String label, emoji, desc;
  final Color bg, titleColor, borderColor, accentColor;
  final IconData icon;
  final List<Color> bookColors;
  const _SeasonConfig({
    required this.label, required this.emoji, required this.desc,
    required this.bg, required this.titleColor, required this.borderColor,
    required this.accentColor, required this.icon, required this.bookColors,
  });
}

class _ArchiveScreenState extends State<ArchiveScreen> {
  _Season _season = _Season.spring;
  int _booksCollected = 0;
  String? _rewardPopup;

  Map<_Season, int> _allProgress = {
    _Season.spring: 0, _Season.summer: 0, _Season.autumn: 0, _Season.winter: 0,
  };

  final Map<_Season, List<String>> _chapterTargets = {
    _Season.spring: ['cherry_blossom_path', 'carousel', 'bumper_car', 'mini_viking', 'viking'],
    _Season.summer: ['flume_ride', 'sky_x', 'viking', 'bumper_car', 'shot_drop'],
    _Season.autumn: ['galaxy_888', 'blackhole_2000', 'gyro_swing', 'shot_drop', 'viking'],
    _Season.winter: ['carousel', 'santa_restaurant', 'bumper_car', 'blackhole_2000', 'time_machine_5d'],
  };

  final List<Map<String, dynamic>> _timelines = [
    {'date': '2026.04.15', 'weather': '맑음 ☀️', 'companions': '친구들', 'visited': ['킹바이킹', '은하철도 888', '블랙홀 2000']},
    {'date': '2025.10.03', 'weather': '흐림 ☁️', 'companions': '가족', 'visited': ['캐릭터 회전목마', '터닝메카드 레이싱']},
  ];

  static const Map<_Season, _SeasonConfig> _configs = {
    _Season.spring: _SeasonConfig(
      label: '봄', emoji: '🌸', desc: '벚꽃 흩날리는 봄날의 기억',
      bg: Color(0xFFFDF2F8), titleColor: Color(0xFFE91E63), borderColor: Color(0xFFFBCFE8), accentColor: Color(0xFFFFB6C1), icon: Icons.local_florist_rounded,
      bookColors: [Color(0xFFF472B6), Color(0xFFEC4899), Color(0xFFD946EF), Color(0xFFDB2777), Color(0xFFBE185D)],
    ),
    _Season.summer: _SeasonConfig(
      label: '여름', emoji: '🌊', desc: '눈부신 태양 아래 여름날',
      bg: Color(0xFFEFF6FF), titleColor: Color(0xFF1976D2), borderColor: Color(0xFFBFDBFE), accentColor: Color(0xFF87CEEB), icon: Icons.wb_sunny_rounded,
      bookColors: [Color(0xFF60A5FA), Color(0xFF38BDF8), Color(0xFF22D3EE), Color(0xFF2563EB), Color(0xFF0EA5E9)],
    ),
    _Season.autumn: _SeasonConfig(
      label: '가을', emoji: '🍁', desc: '단풍 물든 가을의 낭만',
      bg: Color(0xFFFFF7ED), titleColor: Color(0xFFEA580C), borderColor: Color(0xFFFED7AA), accentColor: Color(0xFFDEB887), icon: Icons.eco_rounded,
      bookColors: [Color(0xFFFB923C), Color(0xFFFBBF24), Color(0xFFEAB308), Color(0xFFEA580C), Color(0xFFD97706)],
    ),
    _Season.winter: _SeasonConfig(
      label: '겨울', emoji: '❄️', desc: '눈 내리는 겨울밤의 동화',
      bg: Color(0xFFF1F5F9), titleColor: Color(0xFF475569), borderColor: Color(0xFFCBD5E1), accentColor: Color(0xFFE0FFFF), icon: Icons.ac_unit_rounded,
      bookColors: [Color(0xFF94A3B8), Color(0xFF9CA3AF), Color(0xFFA1A1AA), Color(0xFF64748B), Color(0xFF6B7280)],
    ),
  };

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    Map<_Season, int> tempProgress = {};

    for (var s in _Season.values) {
      int count = 0;
      for (String id in _chapterTargets[s]!) {
        if (prefs.getBool('easter_egg_$id') ?? false) {
          count++;
        }
      }
      tempProgress[s] = count;
    }

    if (!mounted) return;
    setState(() {
      _allProgress = tempProgress;
      _booksCollected = tempProgress[_season]!;
    });
  }

  Future<void> _verifyLocationAndAddBook() async {
    final prefs = await SharedPreferences.getInstance();
    final targets = _chapterTargets[_season]!;

    bool foundNewEgg = false;

    for (final id in targets) {
      bool isDiscovered = prefs.getBool('easter_egg_$id') ?? false;
      if (isDiscovered) continue;

      double distanceInMeters = 30.0;

      if (distanceInMeters <= 50.0) {
        await prefs.setBool('easter_egg_$id', true);
        foundNewEgg = true;
        break;
      }
    }

    if (foundNewEgg) {
      await _loadProgress();
      if (!mounted) return;

      if (_booksCollected == 3) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) setState(() => _rewardPopup = 'goods');
        });
      } else if (_booksCollected >= 5) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) setState(() => _rewardPopup = 'ticket');
        });
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('주변에 획득할 수 있는 이스터에그가 없어요! 어트랙션에 더 가까이 다가가 보세요 🏃‍♀️')),
        );
      }
    }
  }

  void _changeSeason(_Season s) {
    setState(() {
      _season = s;
      _booksCollected = _allProgress[s]!;
      _rewardPopup = null;
    });
  }

  void _goToChapterDetail() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChapterDetailScreen(
          seasonConfig: _configs[_season]!,
          targetIds: _chapterTargets[_season]!,
        ),
      ),
    ).then((_) {
      _loadProgress();
    });
  }

  @override
  Widget build(BuildContext context) {
    final config = _configs[_season]!;
    return ColoredBox(
      color: config.bg,
      child: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _Header(season: _season, configs: _configs, onChange: _changeSeason),

                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                    children: [
                      GestureDetector(
                        onTap: _goToChapterDetail,
                        child: _SeasonBanner(config: config),
                      ),
                      const SizedBox(height: 24),
                      _Bookshelf(season: _season, config: config, collected: _booksCollected),
                      const SizedBox(height: 28),
                      _LocationVerifyCard(collected: _booksCollected, onVerify: _verifyLocationAndAddBook),
                      const SizedBox(height: 28),
                      _RewardsGuide(config: config, collected: _booksCollected),

                      const SizedBox(height: 40),
                      const Divider(height: 1, color: Color(0xFFDDDDDD)),
                      const SizedBox(height: 32),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Text('📝 나의 방문 타임라인',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1A2B4A))),
                      ),
                      const SizedBox(height: 16),
                      if (_timelines.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(40),
                          alignment: Alignment.center,
                          child: const Text('아직 방문 기록이 없어요.\n서울랜드에서 새로운 추억을 만들어보세요!',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Color(0xFF888888), height: 1.5)),
                        )
                      else
                        ..._timelines.map((timeline) => _TimelineCard(data: timeline)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_rewardPopup != null)
            _RewardPopup(
              kind: _rewardPopup!,
              config: config,
              onClose: () => setState(() => _rewardPopup = null),
            ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------
// 🚀 기획서 반영: 챕터 상세 페이지 (상태값 흐리게 + 자물쇠)
// ----------------------------------------------------
class ChapterDetailScreen extends StatefulWidget {
  final _SeasonConfig seasonConfig;
  final List<String> targetIds;

  const ChapterDetailScreen({super.key, required this.seasonConfig, required this.targetIds});

  @override
  State<ChapterDetailScreen> createState() => _ChapterDetailScreenState();
}

class _ChapterDetailScreenState extends State<ChapterDetailScreen> {
  Map<String, bool> _discovered = {};
  bool _isCompleted = false;

  @override
  void initState() {
    super.initState();
    _loadChapterData();
  }

  Future<void> _loadChapterData() async {
    final prefs = await SharedPreferences.getInstance();
    Map<String, bool> temp = {};
    int count = 0;

    for (String id in widget.targetIds) {
      bool isFound = prefs.getBool('easter_egg_$id') ?? false;
      temp[id] = isFound;
      if (isFound) count++;
    }

    setState(() {
      _discovered = temp;
      _isCompleted = count == 5;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.seasonConfig.bg,
      appBar: AppBar(
        title: Text('${widget.seasonConfig.label} 챕터 상세', style: TextStyle(color: widget.seasonConfig.titleColor, fontWeight: FontWeight.w900)),
        backgroundColor: Colors.white,
        foregroundColor: widget.seasonConfig.titleColor,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_isCompleted)
            Container(
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(color: widget.seasonConfig.titleColor, borderRadius: BorderRadius.circular(16)),
              child: const Column(
                children: [
                  Text('🎉', style: TextStyle(fontSize: 40)),
                  SizedBox(height: 12),
                  Text('챕터 완료! 다음 시즌을 기다려요.', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                ],
              ),
            ),

          ...widget.targetIds.map((id) {
            // 💡 에러 수정 완료: dummy 대신 안전하게 필터링해서 화면 표시
            final attractionList = kAttractions.where((a) => a.id == id);
            if (attractionList.isEmpty) return const SizedBox.shrink();
            final attraction = attractionList.first;

            final isFound = _discovered[id] ?? false;

            return Opacity(
              opacity: isFound ? 1.0 : 0.4,
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: widget.seasonConfig.borderColor)
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(color: widget.seasonConfig.bg, borderRadius: BorderRadius.circular(12)),
                      alignment: Alignment.center,
                      child: Text(attraction.icon, style: const TextStyle(fontSize: 24)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(attraction.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text(attraction.zone, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                    if (!isFound)
                      const Icon(Icons.lock_rounded, color: Color(0xFFBBBBBB))
                    else
                      Icon(Icons.check_circle_rounded, color: widget.seasonConfig.titleColor)
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ----------------------------------------------------
// UI 위젯들 (팀원분 코드 원본 유지)
// ----------------------------------------------------

class _Header extends StatelessWidget {
  final _Season season;
  final Map<_Season, _SeasonConfig> configs;
  final ValueChanged<_Season> onChange;
  const _Header({required this.season, required this.configs, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white.withOpacity(0.85),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.library_books_rounded, color: Color(0xFF1A2B4A), size: 24),
              SizedBox(width: 6),
              Text('Retrace Archive', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1A2B4A))),
              Spacer(),
              Text('📚', style: TextStyle(fontSize: 22)),
            ],
          ),
          const SizedBox(height: 4),
          const Text('계절별 기억의 조각을 모아 책장을 채워보세요.', style: TextStyle(fontSize: 13, color: Color(0xFF888888), fontWeight: FontWeight.w500)),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(99), border: Border.all(color: const Color(0xFFE5E7EB))),
            child: Row(
              children: _Season.values.map((s) => Expanded(
                child: GestureDetector(
                  onTap: () => onChange(s),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: season == s ? const Color(0xFF1A2B4A) : Colors.transparent,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    alignment: Alignment.center,
                    child: Text(configs[s]!.label, style: TextStyle(color: season == s ? Colors.white : const Color(0xFF888888), fontSize: 12, fontWeight: FontWeight.w900)),
                  ),
                ),
              )).toList(),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: config.borderColor)),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(color: config.bg, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Icon(config.icon, color: config.titleColor, size: 22),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${config.label} 챕터', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: config.titleColor)),
              const SizedBox(height: 2),
              const Text('터치하여 상세 목록 보기 🔍', style: TextStyle(fontSize: 11, color: Color(0xFF888888), fontWeight: FontWeight.w800)),
            ],
          ),
          const Spacer(),
          Icon(Icons.arrow_forward_ios_rounded, size: 14, color: config.titleColor),
        ],
      ),
    );
  }
}

class _Bookshelf extends StatelessWidget {
  final _Season season;
  final _SeasonConfig config;
  final int collected;
  const _Bookshelf({required this.season, required this.config, required this.collected});

  void _onBookTap(BuildContext context, int index, bool filled) {
    if (!filled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${index + 1}번째 책은 아직 잠겨있어요 🔒'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final book = _kMockMemoryBooks[season]![index];
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BookDetailSheet(
        config: config,
        bookIndex: index + 1,
        book: book,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              const Text('기억의 책장', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF1A2B4A))),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(99), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))]),
                child: Text('$collected / 5 권', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFFE60012))),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: const BoxDecoration(
            color: Color(0xFF8B5A2B), borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
            border: Border(bottom: BorderSide(color: Color(0xFF5C3A21), width: 10)),
          ),
          child: SizedBox(
            height: 132,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(5, (i) {
                final filled = i < collected;
                return _BookSlot(
                  filled: filled,
                  color: config.bookColors[i],
                  index: i + 1,
                  onTap: () => _onBookTap(context, i, filled),
                );
              }),
            ),
          ),
        ),
        Container(height: 14, margin: const EdgeInsets.symmetric(horizontal: 8), decoration: const BoxDecoration(color: Color(0xFF6E4225), borderRadius: BorderRadius.vertical(bottom: Radius.circular(8)))),
      ],
    );
  }
}

class _BookSlot extends StatelessWidget {
  final bool filled;
  final Color color;
  final int index;
  final VoidCallback onTap;
  const _BookSlot({
    required this.filled,
    required this.color,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 48, height: 132,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Positioned(
              bottom: 0,
              child: Container(
                width: 42, height: 116,
                decoration: BoxDecoration(border: Border.all(color: const Color(0xFF5C3A21).withOpacity(0.4), style: BorderStyle.solid, width: 2), borderRadius: BorderRadius.circular(2), color: Colors.transparent),
              ),
            ),
            if (filled)
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 42, height: 116,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2), border: const Border(left: BorderSide(color: Colors.white24, width: 2)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 4, offset: const Offset(2, 2))]),
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    Container(width: 24, height: 3, color: Colors.white.withOpacity(0.5)),
                    const SizedBox(height: 8),
                    RotatedBox(quarterTurns: 1, child: Text('CHAPTER $index', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1.5))),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── 책 상세 모달 (목업 데이터) ───────────────────────────
class _MemoryBook {
  final String title;
  final String story;
  final DateTime recordedAt;
  final String attractionId;
  final String? photoEmoji; // 커버 일러스트 — 추후 실제 사진 URL 로 교체.
  const _MemoryBook({
    required this.title,
    required this.story,
    required this.recordedAt,
    required this.attractionId,
    this.photoEmoji,
  });
}

// 시즌별 5권 — 챕터 타겟 어트랙션 순서와 일치.
// 실제 백엔드 붙으면 GET /api/archive/books?season=spring 응답으로 교체.
final Map<_Season, List<_MemoryBook>> _kMockMemoryBooks = {
  _Season.spring: [
    _MemoryBook(
      title: '벚꽃 흩날리던 그 길',
      story: '벚꽃이 만개한 4월의 오후, 친구들과 손을 잡고 걸었던 그 길. 바람이 불 때마다 머리 위로 꽃잎이 쏟아져 내렸어요. 그날의 풍경은 마치 영화 속 한 장면 같았답니다.',
      recordedAt: DateTime(2026, 4, 14, 14, 30),
      attractionId: 'cherry_blossom_path',
      photoEmoji: '🌸',
    ),
    _MemoryBook(
      title: '회전목마 위의 동심',
      story: '어릴 적 엄마 손을 잡고 처음 탔던 회전목마. 어른이 되어 다시 올라타니 그 시절의 설렘이 그대로 떠올랐어요. 음악도, 조명도, 모든 것이 그대로였답니다.',
      recordedAt: DateTime(2026, 4, 15, 11, 15),
      attractionId: 'carousel',
      photoEmoji: '🎠',
    ),
    _MemoryBook(
      title: '범퍼카 대결',
      story: '서로 부딪치며 깔깔 웃었던 범퍼카. 누가 더 잘 모는지 진지하게 경쟁했지만, 결국엔 부딪치는 재미가 최고였어요.',
      recordedAt: DateTime(2026, 4, 15, 13, 0),
      attractionId: 'bumper_car',
      photoEmoji: '🚗',
    ),
    _MemoryBook(
      title: '미니바이킹의 첫 모험',
      story: '큰 바이킹은 무서워서 못 타던 동생이 미니바이킹에서 처음으로 환하게 웃었던 날. 그 순간을 잊을 수 없어요.',
      recordedAt: DateTime(2026, 4, 16, 10, 45),
      attractionId: 'mini_viking',
      photoEmoji: '⚓',
    ),
    _MemoryBook(
      title: '킹바이킹의 짜릿함',
      story: '드디어 키 제한을 넘긴 그날, 처음 도전한 킹바이킹. 떨어질 것 같은 그 짜릿함, 그리고 친구들의 비명소리가 아직도 귀에 남아있어요.',
      recordedAt: DateTime(2026, 4, 16, 15, 20),
      attractionId: 'viking',
      photoEmoji: '🏴‍☠️',
    ),
  ],
  _Season.summer: [
    _MemoryBook(
      title: '급류타기의 시원함',
      story: '한여름 무더위를 한 방에 날려준 급류타기. 물벼락에 옷이 다 젖었지만, 그 시원함은 잊을 수가 없어요.',
      recordedAt: DateTime(2025, 7, 22, 14, 0),
      attractionId: 'flume_ride',
      photoEmoji: '🌊',
    ),
    _MemoryBook(
      title: '스카이엑스에서 본 하늘',
      story: '70m 상공에서 자유낙하하던 그 순간, 시간이 멈춘 듯했어요. 떨어지는 동안 본 푸른 여름 하늘이 잊혀지지 않아요.',
      recordedAt: DateTime(2025, 7, 23, 13, 30),
      attractionId: 'sky_x',
      photoEmoji: '🪂',
    ),
    _MemoryBook(
      title: '여름밤의 바이킹',
      story: '해가 진 후 노을빛 아래 흔들리던 바이킹. 야간 라이딩의 매력을 처음 알게 된 날이에요.',
      recordedAt: DateTime(2025, 8, 5, 19, 40),
      attractionId: 'viking',
      photoEmoji: '⚓',
    ),
    _MemoryBook(
      title: '실내 범퍼카로 더위 피하기',
      story: '에어컨 빵빵한 실내 범퍼카는 한여름 피난처였어요. 한 시간 동안 5번이나 다시 줄을 섰답니다.',
      recordedAt: DateTime(2025, 8, 5, 15, 10),
      attractionId: 'bumper_car',
      photoEmoji: '🚗',
    ),
    _MemoryBook(
      title: '샷드롭의 비명',
      story: '발사되는 순간의 그 무중력감. 옆 사람이 비명을 지르고, 나도 모르게 따라 질렀어요. 내려와서 보니 다리가 후들거리더라구요.',
      recordedAt: DateTime(2025, 8, 6, 16, 0),
      attractionId: 'shot_drop',
      photoEmoji: '🚀',
    ),
  ],
  _Season.autumn: [
    _MemoryBook(
      title: '은하열차의 가을 라이드',
      story: '단풍이 물든 풍경 사이로 질주하는 은하열차. 바람에 실려오는 가을 향기와 함께 달렸던 그 코스가 최고였어요.',
      recordedAt: DateTime(2025, 10, 18, 14, 20),
      attractionId: 'galaxy_888',
      photoEmoji: '🎢',
    ),
    _MemoryBook(
      title: '블랙홀 2000의 어둠',
      story: '어둠 속에서 회전하던 그 순간, 방향감을 잃었어요. 출구로 나왔을 때의 그 안도감, 그리고 친구와 마주보며 웃었던 표정이 생생해요.',
      recordedAt: DateTime(2025, 10, 19, 13, 0),
      attractionId: 'blackhole_2000',
      photoEmoji: '🌀',
    ),
    _MemoryBook(
      title: '알포스윙 360도',
      story: '360도 회전하는 그 순간, 거꾸로 본 가을 하늘. 무섭다고 했지만 다시 타고 싶다고 했던 그 모순적인 마음.',
      recordedAt: DateTime(2025, 10, 20, 15, 30),
      attractionId: 'gyro_swing',
      photoEmoji: '🎡',
    ),
    _MemoryBook(
      title: '단풍 사이의 샷드롭',
      story: '올라가는 동안 본 단풍 풍경, 내려오는 순간의 무중력. 가을과 스릴이 만난 완벽한 조합이었어요.',
      recordedAt: DateTime(2025, 10, 25, 16, 10),
      attractionId: 'shot_drop',
      photoEmoji: '🚀',
    ),
    _MemoryBook(
      title: '가을의 마지막 바이킹',
      story: '시즌이 끝나기 전 마지막으로 탄 바이킹. 흩날리는 낙엽 사이로 흔들렸던 그 순간이 올 가을의 마침표였어요.',
      recordedAt: DateTime(2025, 11, 2, 17, 0),
      attractionId: 'viking',
      photoEmoji: '⚓',
    ),
  ],
  _Season.winter: [
    _MemoryBook(
      title: '눈 내리는 회전목마',
      story: '함박눈이 내리던 12월의 저녁, 조명이 켜진 회전목마. 한 폭의 동화 같았던 그 풍경을 잊을 수 없어요.',
      recordedAt: DateTime(2024, 12, 20, 18, 30),
      attractionId: 'carousel',
      photoEmoji: '🎠',
    ),
    _MemoryBook(
      title: '산타레스토랑의 따뜻함',
      story: '추운 날 산타레스토랑에서 먹었던 따뜻한 한 끼. 창밖에 눈이 내리고, 안에서는 캐롤이 흘러나오던 그 순간.',
      recordedAt: DateTime(2024, 12, 24, 19, 0),
      attractionId: 'santa_restaurant',
      photoEmoji: '🎅',
    ),
    _MemoryBook(
      title: '실내 범퍼카 단체전',
      story: '겨울 시즌엔 단연 실내 어트랙션이 최고예요. 친구 5명이서 단체로 부딪치며 깔깔 웃었던 그 시간.',
      recordedAt: DateTime(2025, 1, 12, 14, 30),
      attractionId: 'bumper_car',
      photoEmoji: '🚗',
    ),
    _MemoryBook(
      title: '블랙홀의 겨울밤',
      story: '바깥은 영하인데 실내 라이드는 짜릿했어요. 어둠 속 그 회전을 친구와 함께 견뎌낸 추억.',
      recordedAt: DateTime(2025, 1, 18, 16, 0),
      attractionId: 'blackhole_2000',
      photoEmoji: '🌀',
    ),
    _MemoryBook(
      title: '타임머신의 새해 첫날',
      story: '새해 첫날 가족과 함께 본 5D 영상. 미래의 한 장면 같았던 그 경험이 새해의 시작을 특별하게 만들어줬어요.',
      recordedAt: DateTime(2025, 1, 1, 13, 0),
      attractionId: 'time_machine_5d',
      photoEmoji: '🎬',
    ),
  ],
};

class _BookDetailSheet extends StatelessWidget {
  final _SeasonConfig config;
  final int bookIndex;
  final _MemoryBook book;
  const _BookDetailSheet({
    required this.config,
    required this.bookIndex,
    required this.book,
  });

  Attraction? get _attraction {
    final list = kAttractions.where((a) => a.id == book.attractionId);
    return list.isEmpty ? null : list.first;
  }

  String _formatDate(DateTime dt) {
    final wd = const ['일', '월', '화', '수', '목', '금', '토'][dt.weekday % 7];
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '${dt.year}년 ${dt.month}월 ${dt.day}일 ($wd) · $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final attr = _attraction;
    final bookColor = config.bookColors[bookIndex - 1];
    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // 드래그 핸들
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                  children: [
                    // 표지 영역 — 책 색상 그라데이션 + 이모지
                    Container(
                      height: 180,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [bookColor, bookColor.withOpacity(0.7)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: bookColor.withOpacity(0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            top: 14, left: 16,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.25),
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(
                                '${config.label} · CHAPTER $bookIndex',
                                style: const TextStyle(
                                  color: Colors.white, fontSize: 11,
                                  fontWeight: FontWeight.w900, letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          ),
                          Center(
                            child: Text(
                              book.photoEmoji ?? config.emoji,
                              style: const TextStyle(fontSize: 80),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // 타이틀
                    Text(
                      book.title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1A2B4A),
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // 기록된 시간
                    Row(
                      children: [
                        const Icon(Icons.schedule_rounded,
                            size: 14, color: Color(0xFF888888)),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(book.recordedAt),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF888888),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(height: 1, color: const Color(0xFFEEEEEE)),
                    const SizedBox(height: 20),
                    // 스토리
                    const Text(
                      '📖 그날의 이야기',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1A2B4A),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      book.story,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF333333),
                        height: 1.7,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // 관련 어트랙션
                    if (attr != null) ...[
                      const Text(
                        '📍 관련 어트랙션',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1A2B4A),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _AttractionInfoCard(attraction: attr, accent: config.titleColor),
                    ],
                    const SizedBox(height: 24),
                    // 닫기 버튼
                    SizedBox(
                      width: double.infinity, height: 48,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: config.titleColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          '책장으로 돌아가기',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AttractionInfoCard extends StatelessWidget {
  final Attraction attraction;
  final Color accent;
  const _AttractionInfoCard({required this.attraction, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(attraction.icon, style: const TextStyle(fontSize: 24)),
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
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1F1F1F),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${attraction.category} · ${attraction.zone}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF888888)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _InfoChip(
                icon: Icons.location_on_rounded,
                text: '${attraction.lat.toStringAsFixed(4)}, ${attraction.lng.toStringAsFixed(4)}',
              ),
            ],
          ),
          if (attraction.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                attraction.description,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF555555),
                  height: 1.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFF888888)),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF555555),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationVerifyCard extends StatelessWidget {
  final int collected;
  final VoidCallback onVerify;
  const _LocationVerifyCard({required this.collected, required this.onVerify});

  @override
  Widget build(BuildContext context) {
    final done = collected >= 5;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFEEEEEE)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))]),
      child: Column(
        children: [
          const Text('해당 어트랙션 50m 반경 안에서 버튼을 눌러주세요!', style: TextStyle(fontSize: 11, color: Color(0xFF888888), fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity, height: 48,
            child: ElevatedButton.icon(
              onPressed: done ? null : onVerify,
              icon: Icon(done ? Icons.check_circle_rounded : Icons.location_on_rounded, size: 18),
              label: Text(done ? '모든 챕터 수집 완료 🎉' : '현재 위치 인증하고 조각 찾기', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
              style: ElevatedButton.styleFrom(
                backgroundColor: done ? const Color(0xFFE5E7EB) : const Color(0xFFE60012),
                disabledBackgroundColor: const Color(0xFFE5E7EB),
                foregroundColor: done ? const Color(0xFF9CA3AF) : Colors.white,
                disabledForegroundColor: const Color(0xFF9CA3AF),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: done ? 0 : 4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardsGuide extends StatelessWidget {
  final _SeasonConfig config;
  final int collected;
  const _RewardsGuide({required this.config, required this.collected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.6), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🎁 챕터 달성 보상', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF1A2B4A))),
          const SizedBox(height: 14),
          _RewardRow(label: '책 3권 수집 시', reward: '서울랜드 한정 굿즈', unlocked: collected >= 3, accent: config.accentColor),
          const SizedBox(height: 10),
          _RewardRow(label: '책 5권 수집 시', reward: '무료 입장권 (1매)', unlocked: collected >= 5, accent: config.accentColor),
        ],
      ),
    );
  }
}

class _RewardRow extends StatelessWidget {
  final String label, reward;
  final bool unlocked;
  final Color accent;
  const _RewardRow({required this.label, required this.reward, required this.unlocked, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: unlocked ? accent.withOpacity(0.08) : const Color(0xFFFAFAFA), borderRadius: BorderRadius.circular(12), border: Border.all(color: unlocked ? accent.withOpacity(0.3) : const Color(0xFFEEEEEE), width: 2)),
      child: Row(
        children: [
          Container(width: 36, height: 36, decoration: BoxDecoration(color: unlocked ? Colors.white.withOpacity(0.7) : Colors.white, shape: BoxShape.circle), alignment: Alignment.center, child: Icon(unlocked ? Icons.lock_open : Icons.lock, color: unlocked ? accent : const Color(0xFFBBBBBB), size: 16)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: unlocked ? const Color(0xFF1F1F1F) : const Color(0xFF888888))),
                const SizedBox(height: 2),
                Text(reward, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: unlocked ? const Color(0xFF1F1F1F) : const Color(0xFFAAAAAA))),
              ],
            ),
          ),
          if (unlocked) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(99)), child: const Text('획득!', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900))),
        ],
      ),
    );
  }
}

class _RewardPopup extends StatelessWidget {
  final String kind;
  final _SeasonConfig config;
  final VoidCallback onClose;
  const _RewardPopup({required this.kind, required this.config, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final isGoods = kind == 'goods';
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black54,
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(24), padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(color: isGoods ? Colors.white : const Color(0xFF1A2B4A), borderRadius: BorderRadius.circular(24), border: Border.all(color: isGoods ? const Color(0xFFF0B429) : const Color(0xFFE8001C), width: 4)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 72, height: 72, decoration: BoxDecoration(color: isGoods ? const Color(0xFFF0B429).withOpacity(0.15) : Colors.white.withOpacity(0.1), shape: BoxShape.circle, border: isGoods ? null : Border.all(color: const Color(0xFFF0B429))), child: Icon(isGoods ? Icons.card_giftcard : Icons.confirmation_number, color: const Color(0xFFF0B429), size: 36)),
                const SizedBox(height: 16),
                Text(isGoods ? '3챕터 달성 축하!' : '모든 챕터 완성! 🎉', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: isGoods ? const Color(0xFF1A2B4A) : Colors.white)),
                const SizedBox(height: 8),
                Text(isGoods ? '세 번째 기억의 조각을 모으셨네요.\n기념으로 한정판 레트로 굿즈를 드립니다!' : '해당 계절의 모든 기억을 수집하셨습니다.\n서울랜드 무료 입장권 1매를 선물합니다!', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: isGoods ? const Color(0xFF888888) : Colors.white70, height: 1.5)),
                const SizedBox(height: 20),
                SizedBox(width: double.infinity, height: 48, child: ElevatedButton(onPressed: onClose, style: ElevatedButton.styleFrom(backgroundColor: isGoods ? const Color(0xFF1A2B4A) : const Color(0xFFE8001C), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text(isGoods ? '리워드 보관함에 넣기' : '입장권 받기', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900)))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _TimelineCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final List<String> visited = List<String>.from(data['visited']);
    return Container(
      margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFEEEEEE)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: const Color(0xFF1E3158), borderRadius: BorderRadius.circular(8)), child: Text(data['date'], style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800))),
              const Spacer(),
              Text('${data['weather']} · ${data['companions']}', style: const TextStyle(fontSize: 12, color: Color(0xFF888888), fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: visited.map((name) => Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: const Color(0xFFF7F7F7), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE0E0E0))), child: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF333333))))).toList(),
          ),
        ],
      ),
    );
  }
}
