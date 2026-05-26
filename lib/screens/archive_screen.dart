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
    _Season.spring: ['cherry_blossom_path', 'carousel', 'bumper_car', 'flying_carpet', 'viking'],
    _Season.summer: ['flume_ride', 'sky_x', 'viking', 'bumper_car', 'flying_carpet'],
    _Season.autumn: ['galaxy_888', 'blackhole_2000', 'gyro_swing', 'shot_drop', 'viking'],
    _Season.winter: ['carousel', 'santa_restaurant', 'bumper_car', 'blackhole_2000', 'flying_carpet'],
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

                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  color: Colors.white.withOpacity(0.5),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: _Season.values.map((s) => Text(
                      '${_configs[s]!.label} ${_allProgress[s]}/5',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: _season == s ? FontWeight.w900 : FontWeight.w700,
                        color: _season == s ? const Color(0xFFE60012) : const Color(0xFF888888)
                      )
                    )).toList(),
                  ),
                ),

                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                    children: [
                      GestureDetector(
                        onTap: _goToChapterDetail,
                        child: _SeasonBanner(config: config),
                      ),
                      const SizedBox(height: 24),
                      _Bookshelf(config: config, collected: _booksCollected),
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
  final _SeasonConfig config;
  final int collected;
  const _Bookshelf({required this.config, required this.collected});

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
                return _BookSlot(filled: filled, color: config.bookColors[i], index: i + 1);
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
  const _BookSlot({required this.filled, required this.color, required this.index});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
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
