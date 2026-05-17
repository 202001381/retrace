import 'package:flutter/material.dart';

import '../models/attraction.dart';
import '../services/easter_egg_service.dart';

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
    required this.label,
    required this.emoji,
    required this.desc,
    required this.bg,
    required this.titleColor,
    required this.borderColor,
    required this.accentColor,
    required this.icon,
    required this.bookColors,
  });
}

class _ArchiveScreenState extends State<ArchiveScreen> {
  _Season _season = _Season.spring;
  int _booksCollected = 0;
  String? _rewardPopup; // 'goods' | 'ticket' | null

  static const Map<_Season, _SeasonConfig> _configs = {
    _Season.spring: _SeasonConfig(
      label: '봄',
      emoji: '🌸',
      desc: '벚꽃 흩날리는 봄날의 기억',
      bg: Color(0xFFFDF2F8),
      titleColor: Color(0xFFE91E63),
      borderColor: Color(0xFFFBCFE8),
      accentColor: Color(0xFFFFB6C1),
      icon: Icons.local_florist_rounded,
      bookColors: [
        Color(0xFFF472B6),
        Color(0xFFEC4899),
        Color(0xFFD946EF),
        Color(0xFFDB2777),
        Color(0xFFBE185D),
      ],
    ),
    _Season.summer: _SeasonConfig(
      label: '여름',
      emoji: '🌊',
      desc: '눈부신 태양 아래 여름날',
      bg: Color(0xFFEFF6FF),
      titleColor: Color(0xFF1976D2),
      borderColor: Color(0xFFBFDBFE),
      accentColor: Color(0xFF87CEEB),
      icon: Icons.wb_sunny_rounded,
      bookColors: [
        Color(0xFF60A5FA),
        Color(0xFF38BDF8),
        Color(0xFF22D3EE),
        Color(0xFF2563EB),
        Color(0xFF0EA5E9),
      ],
    ),
    _Season.autumn: _SeasonConfig(
      label: '가을',
      emoji: '🍁',
      desc: '단풍 물든 가을의 낭만',
      bg: Color(0xFFFFF7ED),
      titleColor: Color(0xFFEA580C),
      borderColor: Color(0xFFFED7AA),
      accentColor: Color(0xFFDEB887),
      icon: Icons.eco_rounded,
      bookColors: [
        Color(0xFFFB923C),
        Color(0xFFFBBF24),
        Color(0xFFEAB308),
        Color(0xFFEA580C),
        Color(0xFFD97706),
      ],
    ),
    _Season.winter: _SeasonConfig(
      label: '겨울',
      emoji: '❄️',
      desc: '눈 내리는 겨울밤의 동화',
      bg: Color(0xFFF1F5F9),
      titleColor: Color(0xFF475569),
      borderColor: Color(0xFFCBD5E1),
      accentColor: Color(0xFFE0FFFF),
      icon: Icons.ac_unit_rounded,
      bookColors: [
        Color(0xFF94A3B8),
        Color(0xFF9CA3AF),
        Color(0xFFA1A1AA),
        Color(0xFF64748B),
        Color(0xFF6B7280),
      ],
    ),
  };

  @override
  void initState() {
    super.initState();
    _refreshFromEggs();
  }

  /// EasterEggService 에서 현재 챕터의 발견 카운트를 가져와 동기화.
  Future<void> _refreshFromEggs() async {
    final discovered = await EasterEggService.discoveredAll();
    final chapterKey = _chapterKey(_season);
    final targets = kChapterTargets[chapterKey] ?? const [];
    // 챕터 타깃 중 hasEasterEgg=true 인 것만 카운트
    final eggTargets = targets.where((id) {
      final att = kAttractions.where((a) => a.id == id);
      return att.isNotEmpty && att.first.hasEasterEgg;
    }).toList();
    final discoveredInChapter = eggTargets.where(discovered.contains).length;
    if (!mounted) return;
    setState(() {
      _booksCollected = discoveredInChapter.clamp(0, 5);
    });
  }

  String _chapterKey(_Season s) {
    switch (s) {
      case _Season.spring: return 'spring';
      case _Season.summer: return 'summer';
      case _Season.autumn: return 'autumn';
      case _Season.winter: return 'winter';
    }
  }

  void _addBook() {
    // 시뮬레이션: 현재 챕터의 미발견 이스터에그 어트랙션을 하나 더 발견 처리.
    final chapterKey = _chapterKey(_season);
    final targets = kChapterTargets[chapterKey] ?? const [];
    () async {
      final discovered = await EasterEggService.discoveredAll();
      for (final id in targets) {
        final att = kAttractions.where((a) => a.id == id);
        if (att.isEmpty || !att.first.hasEasterEgg) continue;
        if (!discovered.contains(id)) {
          await EasterEggService.markDiscovered(id);
          await _refreshFromEggs();
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
          return;
        }
      }
    }();
  }

  void _changeSeason(_Season s) {
    setState(() {
      _season = s;
      _rewardPopup = null;
    });
    _refreshFromEggs();
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
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                    children: [
                      _SeasonBanner(config: config),
                      const SizedBox(height: 24),
                      _Bookshelf(config: config, collected: _booksCollected),
                      const SizedBox(height: 28),
                      _SimulationCard(collected: _booksCollected, onAdd: _addBook),
                      const SizedBox(height: 28),
                      _RewardsGuide(config: config, collected: _booksCollected),
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

class _Header extends StatelessWidget {
  final _Season season;
  final Map<_Season, _SeasonConfig> configs;
  final ValueChanged<_Season> onChange;
  const _Header({required this.season, required this.configs, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white.withValues(alpha: 0.85),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.library_books_rounded, color: Color(0xFF1A2B4A), size: 24),
              SizedBox(width: 6),
              Text('Retrace Archive',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1A2B4A))),
              Spacer(),
              Text('📚', style: TextStyle(fontSize: 22)),
            ],
          ),
          const SizedBox(height: 4),
          const Text('계절별 기억의 조각을 모아 책장을 채워보세요.',
              style: TextStyle(fontSize: 13, color: Color(0xFF888888), fontWeight: FontWeight.w500)),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              children: _Season.values
                  .map((s) => Expanded(
                        child: GestureDetector(
                          onTap: () => onChange(s),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: season == s ? const Color(0xFF1A2B4A) : Colors.transparent,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            alignment: Alignment.center,
                            child: Text(configs[s]!.label,
                                style: TextStyle(
                                  color: season == s ? Colors.white : const Color(0xFF888888),
                                  fontSize: 12, fontWeight: FontWeight.w900,
                                )),
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

class _SeasonBanner extends StatelessWidget {
  final _SeasonConfig config;
  const _SeasonBanner({required this.config});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: config.borderColor),
      ),
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
              Text('${config.label} 챕터',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: config.titleColor)),
              const SizedBox(height: 2),
              Text(config.desc,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF888888), fontWeight: FontWeight.w800)),
            ],
          ),
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
              const Text('기억의 책장',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF1A2B4A))),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(99),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
                ),
                child: Text('$collected / 5 권',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFFE60012))),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF8B5A2B),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            border: const Border(bottom: BorderSide(color: Color(0xFF5C3A21), width: 10)),
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
                );
              }),
            ),
          ),
        ),
        Container(
          height: 14,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: const BoxDecoration(
            color: Color(0xFF6E4225),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(8)),
          ),
        ),
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
      width: 48,
      height: 132,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // empty slot
          Positioned(
            bottom: 0,
            child: Container(
              width: 42, height: 116,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF5C3A21).withValues(alpha: 0.4), style: BorderStyle.solid, width: 2),
                borderRadius: BorderRadius.circular(2),
                color: Colors.transparent,
              ),
            ),
          ),
          // book
          if (filled)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 42, height: 116,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
                border: const Border(left: BorderSide(color: Colors.white24, width: 2)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 4, offset: const Offset(2, 2))],
              ),
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  Container(width: 24, height: 3, color: Colors.white.withValues(alpha: 0.5)),
                  const SizedBox(height: 8),
                  RotatedBox(
                    quarterTurns: 1,
                    child: Text('CHAPTER $index',
                        style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SimulationCard extends StatelessWidget {
  final int collected;
  final VoidCallback onAdd;
  const _SimulationCard({required this.collected, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final done = collected >= 5;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEEE)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          const Text('이스터에그를 발견할 때마다 챕터가 기록됩니다.',
              style: TextStyle(fontSize: 11, color: Color(0xFF888888), fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: done ? null : onAdd,
              icon: Icon(done ? Icons.check_circle_rounded : Icons.add, size: 16),
              label: Text(done ? '모든 챕터 수집 완료 🎉' : '(시뮬레이션) 책 한 권 획득하기',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
              style: ElevatedButton.styleFrom(
                backgroundColor: done ? const Color(0xFFE5E7EB) : const Color(0xFF1A2B4A),
                disabledBackgroundColor: const Color(0xFFE5E7EB),
                foregroundColor: done ? const Color(0xFF9CA3AF) : Colors.white,
                disabledForegroundColor: const Color(0xFF9CA3AF),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: done ? 0 : 2,
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
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🎁 챕터 달성 보상',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF1A2B4A))),
          const SizedBox(height: 14),
          _RewardRow(
            label: '책 3권 수집 시',
            reward: '서울랜드 한정 굿즈',
            unlocked: collected >= 3,
            accent: config.accentColor,
          ),
          const SizedBox(height: 10),
          _RewardRow(
            label: '책 5권 수집 시',
            reward: '무료 입장권 (1매)',
            unlocked: collected >= 5,
            accent: config.accentColor,
          ),
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
      decoration: BoxDecoration(
        color: unlocked ? accent.withValues(alpha: 0.08) : const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: unlocked ? accent.withValues(alpha: 0.3) : const Color(0xFFEEEEEE), width: 2),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: unlocked ? Colors.white.withValues(alpha: 0.7) : Colors.white, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Icon(unlocked ? Icons.lock_open : Icons.lock, color: unlocked ? accent : const Color(0xFFBBBBBB), size: 16),
          ),
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
          if (unlocked)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(99)),
              child: const Text('획득!', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
            ),
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
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: isGoods ? Colors.white : const Color(0xFF1A2B4A),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: isGoods ? const Color(0xFFF0B429) : const Color(0xFFE8001C), width: 4),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    color: isGoods ? const Color(0xFFF0B429).withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: isGoods ? null : Border.all(color: const Color(0xFFF0B429)),
                  ),
                  child: Icon(
                    isGoods ? Icons.card_giftcard : Icons.confirmation_number,
                    color: const Color(0xFFF0B429), size: 36,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  isGoods ? '3챕터 달성 축하!' : '모든 챕터 완성! 🎉',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: isGoods ? const Color(0xFF1A2B4A) : Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  isGoods
                      ? '세 번째 기억의 조각을 모으셨네요.\n기념으로 한정판 레트로 굿즈를 드립니다!'
                      : '해당 계절의 모든 기억을 수집하셨습니다.\n서울랜드 무료 입장권 1매를 선물합니다!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: isGoods ? const Color(0xFF888888) : Colors.white70, height: 1.5),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: onClose,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isGoods ? const Color(0xFF1A2B4A) : const Color(0xFFE8001C),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(isGoods ? '리워드 보관함에 넣기' : '입장권 받기',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
