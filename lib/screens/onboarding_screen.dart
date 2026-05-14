import 'package:flutter/material.dart';

import '../services/onboarding_service.dart';

const _kAccent = Color(0xFFE60012);
const _kSelectedBg = Color(0xFFFFF5F5);
const _kBorderIdle = Color(0xFFE0E0E0);
const _kText = Color(0xFF1F1F1F);
const _kMuted = Color(0xFF888888);
const _kDarkBg = Color(0xFF1E2B4A);
const _kCardBg = Color(0xFFF7F7F7);

// 페이지 인덱스
//   0: intro 어서오세요 (네/아니요 분기)
//   1: intro 마이 루나 소개
//   2: intro 루나 프라이싱 소개
//   3: intro 설문 시작 안내
//   4: survey 1 — 구성원
//   5: survey 2 — 선호 어트랙션
//   6: survey 3 — 방문 목적
//   7: 완료
const int _kPages = 8;
const int _kFirstSurveyPage = 4;
const int _kLastSurveyPage = 6;
const int _kDonePage = 7;

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;
  const OnboardingScreen({super.key, required this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;
  // 페이지 이동 히스토리 (0→3 점프 같은 비순차 이동 후 back 처리용).
  final List<int> _history = [0];

  // 구성원 카운터
  final Map<MemberCategory, int> _members = {
    for (final c in MemberCategory.values) c: 0,
  };
  // 선호 / 목적
  String? _favoriteType;
  String? _purpose;

  int get _total => _members.values.fold(0, (a, b) => a + b);

  Future<void> _goTo(int page) async {
    if (page == _page) return;
    _history.add(page);
    setState(() => _page = page);
    await _controller.animateToPage(
      page,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _back() async {
    if (_history.length <= 1) return;
    _history.removeLast();
    final prev = _history.last;
    setState(() => _page = prev);
    await _controller.animateToPage(
      prev,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _skipFromIntro() async {
    await OnboardingService.markSkipped();
    if (!mounted) return;
    widget.onDone();
  }

  Future<void> _finish() async {
    await OnboardingService.save(SurveyAnswers(
      members: Map.from(_members),
      favoriteType: _favoriteType,
      purpose: _purpose,
    ));
    if (!mounted) return;
    widget.onDone();
  }

  void _bump(MemberCategory c, int delta) {
    setState(() {
      final next = (_members[c] ?? 0) + delta;
      _members[c] = next.clamp(0, 20);
    });
  }

  bool get _isIntroPage => _page <= 3;
  bool get _showSkip => _page <= 3;
  bool get _showBack => _page > 0 && _page != _kDonePage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: PageView(
          controller: _controller,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _IntroWelcomePage(
              onShowBack: null,
              onSkip: _skipFromIntro,
              onFirstTime: () => _goTo(1),
              onReturning: () => _goTo(3),
            ),
            _IntroExplainPage(
              icon: '🌙',
              title: '마이 루나란?',
              cards: const [
                (icon: '🗺️', title: '당신만을 위한 서울랜드 코스', desc: '혼잡도, 날씨, 동행자를 분석해 최적의 동선을 만들어드려요'),
                (icon: '🔄', title: '언제든 새로운 코스', desc: 'RE-TRACE를 찾아주실 때마다 새로운 코스를 만들어드릴게요'),
              ],
              ctaLabel: '다음',
              onBack: _back,
              onSkip: _skipFromIntro,
              onNext: () => _goTo(2),
            ),
            _IntroExplainPage(
              icon: '💰',
              title: '루나 프라이싱이란?',
              cards: const [
                (icon: '⏰', title: '실시간 할인', desc: '혼잡도와 날씨에 따라 입장권 가격이 달라져요. 한산한 날엔 최대 25% 할인!'),
                (icon: '🔔', title: '선제적 알림', desc: '방문 전날 밤, 내일 한산할 것 같으면 루나가 먼저 알려드려요'),
              ],
              ctaLabel: '다음',
              onBack: _back,
              onSkip: _skipFromIntro,
              onNext: () => _goTo(3),
            ),
            _IntroDarkCenterPage(
              icon: '✨',
              title: '마이 루나를 만들기 위해\n몇 가지 여쭤볼게요',
              subtitle: '딱 3가지만 물어볼게요 🙂',
              ctaLabel: '시작하기',
              showBack: _showBack,
              showSkip: _showSkip,
              onBack: _back,
              onSkip: _skipFromIntro,
              onNext: () => _goTo(4),
            ),
            _MembersSurveyPage(
              members: _members,
              total: _total,
              onBump: _bump,
              onBack: _back,
              onNext: _total >= 1 ? () => _goTo(5) : null,
            ),
            _SingleChoiceSurveyPage(
              progress: 2,
              title: '어떤 놀이기구를\n더 좋아하세요?',
              options: const [
                (emoji: '🎢', title: '스릴 어트랙션 위주', desc: '빠르고 짜릿한 걸 좋아해요', value: FavoriteType.thrill),
                (emoji: '🎠', title: '가족·어린이 위주', desc: '함께 탈 수 있는 걸 좋아해요', value: FavoriteType.family),
                (emoji: '✨', title: '둘 다 괜찮아요', desc: '상황에 따라 달라요', value: FavoriteType.both),
              ],
              selected: _favoriteType,
              onSelect: (v) => setState(() => _favoriteType = v),
              onBack: _back,
              onNext: _favoriteType != null ? () => _goTo(6) : null,
            ),
            _SingleChoiceSurveyPage(
              progress: 3,
              title: '오늘 방문 목적은\n무엇인가요?',
              options: const [
                (emoji: '🎡', title: '놀이기구 즐기기', desc: null, value: VisitPurpose.rides),
                (emoji: '🌿', title: '나들이·피크닉', desc: null, value: VisitPurpose.picnic),
                (emoji: '👶', title: '아이 데리고 나들이', desc: null, value: VisitPurpose.kidsOuting),
                (emoji: '💑', title: '데이트', desc: null, value: VisitPurpose.date),
              ],
              selected: _purpose,
              onSelect: (v) => setState(() => _purpose = v),
              onBack: _back,
              onNext: _purpose != null ? () => _goTo(7) : null,
            ),
            _DonePage(onStart: _finish),
          ],
        ),
      ),
    );
  }
}

// ─── 인트로 1: 어서오세요 ──────────────────────────────────
class _IntroWelcomePage extends StatelessWidget {
  final VoidCallback? onShowBack;
  final VoidCallback onSkip;
  final VoidCallback onFirstTime;
  final VoidCallback onReturning;
  const _IntroWelcomePage({
    required this.onShowBack,
    required this.onSkip,
    required this.onFirstTime,
    required this.onReturning,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kDarkBg,
      child: Column(
        children: [
          _OnboardingTopBar(showBack: false, onBack: null, onSkip: onSkip, darkMode: true),
          const Spacer(),
          const _RetraceLogo(darkMode: true),
          const SizedBox(height: 56),
          const Text('어서오세요 👋',
              style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, height: 1.2)),
          const SizedBox(height: 12),
          Text('서울랜드는 처음이신가요?',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 16, fontWeight: FontWeight.w600)),
          const Spacer(flex: 2),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 36),
            child: Row(
              children: [
                Expanded(
                  child: _BranchButton(
                    label: '네, 처음이에요',
                    bg: Colors.white,
                    fg: _kDarkBg,
                    onTap: onFirstTime,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _BranchButton(
                    label: '아니요, 와봤어요',
                    bg: Colors.white.withValues(alpha: 0.18),
                    fg: Colors.white,
                    border: Colors.white.withValues(alpha: 0.3),
                    onTap: onReturning,
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

class _RetraceLogo extends StatelessWidget {
  final bool darkMode;
  const _RetraceLogo({required this.darkMode});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('서울랜드',
            style: TextStyle(
              color: darkMode ? Colors.white.withValues(alpha: 0.6) : _kMuted,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.4,
            )),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('RE-TRACE',
                style: TextStyle(
                  color: _kAccent,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                )),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: _kAccent, borderRadius: BorderRadius.circular(4)),
              child: const Text('BETA',
                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
            ),
          ],
        ),
      ],
    );
  }
}

class _BranchButton extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  final Color? border;
  final VoidCallback onTap;
  const _BranchButton({
    required this.label,
    required this.bg,
    required this.fg,
    this.border,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: border == null ? BorderSide.none : BorderSide(color: border!, width: 1),
          ),
        ),
        child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
      ),
    );
  }
}

// ─── 인트로 2/3: 설명 카드 페이지 ───────────────────────────
typedef _ExplainCard = ({String icon, String title, String desc});

class _IntroExplainPage extends StatelessWidget {
  final String icon;
  final String title;
  final List<_ExplainCard> cards;
  final String ctaLabel;
  final VoidCallback onBack;
  final VoidCallback onSkip;
  final VoidCallback onNext;
  const _IntroExplainPage({
    required this.icon,
    required this.title,
    required this.cards,
    required this.ctaLabel,
    required this.onBack,
    required this.onSkip,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _OnboardingTopBar(showBack: true, onBack: onBack, onSkip: onSkip, darkMode: false),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(icon, style: const TextStyle(fontSize: 56)),
              const SizedBox(height: 16),
              Text(title,
                  style: const TextStyle(color: _kText, fontSize: 24, fontWeight: FontWeight.w900)),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: cards.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final c = cards[i];
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _kCardBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(c.icon, style: const TextStyle(fontSize: 22)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(c.title,
                              style: const TextStyle(color: _kText, fontSize: 16, fontWeight: FontWeight.w900)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(c.desc,
                        style: const TextStyle(color: Color(0xFF555555), fontSize: 13, height: 1.6)),
                  ],
                ),
              );
            },
          ),
        ),
        _DotIndicator(current: _currentFromTitle(title), total: 4),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: _PrimaryCta(label: ctaLabel, onTap: onNext, color: _kAccent, fg: Colors.white),
        ),
      ],
    );
  }

  // 인트로 페이지의 점 인덱스를 표시하기 위한 간단 매핑.
  int _currentFromTitle(String t) => t.contains('마이 루나') ? 1 : 2;
}

// ─── 인트로 4 & 완료: 다크 네이비 중앙 정렬 ────────────────
class _IntroDarkCenterPage extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;
  final String ctaLabel;
  final bool showBack;
  final bool showSkip;
  final VoidCallback onBack;
  final VoidCallback onSkip;
  final VoidCallback onNext;
  const _IntroDarkCenterPage({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.ctaLabel,
    required this.showBack,
    required this.showSkip,
    required this.onBack,
    required this.onSkip,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kDarkBg,
      child: Column(
        children: [
          _OnboardingTopBar(
            showBack: showBack,
            onBack: onBack,
            onSkip: showSkip ? onSkip : null,
            darkMode: true,
          ),
          const Spacer(),
          Text(icon, style: const TextStyle(fontSize: 64)),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, height: 1.4)),
          ),
          const SizedBox(height: 12),
          Text(subtitle,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 16, fontWeight: FontWeight.w600)),
          const Spacer(flex: 2),
          if (showSkip) const _DotIndicator(current: 3, total: 4),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
            child: _PrimaryCta(label: ctaLabel, onTap: onNext, color: Colors.white, fg: _kDarkBg),
          ),
        ],
      ),
    );
  }
}

class _DonePage extends StatelessWidget {
  final VoidCallback onStart;
  const _DonePage({required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kDarkBg,
      child: Column(
        children: [
          const SizedBox(height: 56),
          const Spacer(),
          const Text('🌙', style: TextStyle(fontSize: 80)),
          const SizedBox(height: 24),
          const Text('마이 루나가 준비됐어요!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          Text('지금 바로 오늘의 동선을 확인해보세요',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 16, fontWeight: FontWeight.w600)),
          const Spacer(flex: 2),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
            child: _PrimaryCta(label: 'RE-TRACE 시작하기', onTap: onStart, color: Colors.white, fg: _kDarkBg),
          ),
        ],
      ),
    );
  }
}

// ─── 설문 1: 구성원 카운터 ────────────────────────────────
class _MembersSurveyPage extends StatelessWidget {
  final Map<MemberCategory, int> members;
  final int total;
  final void Function(MemberCategory, int delta) onBump;
  final VoidCallback onBack;
  final VoidCallback? onNext;
  const _MembersSurveyPage({
    required this.members,
    required this.total,
    required this.onBump,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _OnboardingTopBar(showBack: true, onBack: onBack, onSkip: null, darkMode: false),
        _SurveyProgress(current: 1, total: 3),
        const SizedBox(height: 16),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('오늘 함께 오신 분들을\n알려주세요',
                  style: TextStyle(color: _kText, fontSize: 20, fontWeight: FontWeight.w900, height: 1.3)),
              SizedBox(height: 6),
              Text('해당하는 인원을 추가해주세요',
                  style: TextStyle(color: _kMuted, fontSize: 14)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: MemberCategory.values.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final c = MemberCategory.values[i];
              final n = members[c] ?? 0;
              return _MemberRow(
                category: c,
                count: n,
                onMinus: () => onBump(c, -1),
                onPlus: () => onBump(c, 1),
              );
            },
          ),
        ),
        // 하단 고정: 총 인원 + CTA
        Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Text('총 인원',
                      style: TextStyle(color: _kMuted, fontSize: 13, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Text('$total명',
                      style: TextStyle(
                        color: total > 0 ? _kAccent : _kMuted,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      )),
                ],
              ),
              const SizedBox(height: 12),
              _PrimaryCta(
                label: '다음',
                onTap: onNext,
                color: _kAccent,
                fg: Colors.white,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MemberRow extends StatelessWidget {
  final MemberCategory category;
  final int count;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  const _MemberRow({
    required this.category,
    required this.count,
    required this.onMinus,
    required this.onPlus,
  });

  @override
  Widget build(BuildContext context) {
    final highlighted = count > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: highlighted ? _kSelectedBg : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: highlighted ? _kAccent : _kBorderIdle, width: highlighted ? 2 : 1),
      ),
      child: Row(
        children: [
          Text(category.emoji, style: const TextStyle(fontSize: 26)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(category.label,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _kText)),
                const SizedBox(height: 2),
                Text(category.ageRange,
                    style: const TextStyle(fontSize: 11, color: _kMuted, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          _RoundIconButton(icon: Icons.remove, enabled: count > 0, onTap: onMinus),
          SizedBox(
            width: 36,
            child: Text(
              '$count',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: highlighted ? _kAccent : _kText,
              ),
            ),
          ),
          _RoundIconButton(icon: Icons.add, enabled: count < 20, onTap: onPlus),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _RoundIconButton({required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36, height: 36,
      child: InkResponse(
        onTap: enabled ? onTap : null,
        radius: 24,
        child: Container(
          decoration: BoxDecoration(
            color: enabled ? _kAccent : const Color(0xFFEEEEEE),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: enabled ? Colors.white : const Color(0xFFAAAAAA), size: 18),
        ),
      ),
    );
  }
}

// ─── 설문 2/3 공용 단일 선택 페이지 ──────────────────────────
typedef _ChoiceOption = ({String emoji, String title, String? desc, String value});

class _SingleChoiceSurveyPage extends StatelessWidget {
  final int progress; // 2 or 3
  final String title;
  final List<_ChoiceOption> options;
  final String? selected;
  final ValueChanged<String> onSelect;
  final VoidCallback onBack;
  final VoidCallback? onNext;

  const _SingleChoiceSurveyPage({
    required this.progress,
    required this.title,
    required this.options,
    required this.selected,
    required this.onSelect,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _OnboardingTopBar(showBack: true, onBack: onBack, onSkip: null, darkMode: false),
        _SurveyProgress(current: progress, total: 3),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SizedBox(
            width: double.infinity,
            child: Text(title,
                style: const TextStyle(color: _kText, fontSize: 20, fontWeight: FontWeight.w900, height: 1.3)),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: options.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final o = options[i];
              final isSelected = selected == o.value;
              return GestureDetector(
                onTap: () => onSelect(o.value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isSelected ? _kSelectedBg : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isSelected ? _kAccent : _kBorderIdle, width: 2),
                  ),
                  child: Row(
                    children: [
                      Text(o.emoji, style: const TextStyle(fontSize: 30)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(o.title,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: isSelected ? _kAccent : _kText,
                                )),
                            if (o.desc != null) ...[
                              const SizedBox(height: 4),
                              Text(o.desc!, style: const TextStyle(color: _kMuted, fontSize: 12)),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: _PrimaryCta(label: '다음', onTap: onNext, color: _kAccent, fg: Colors.white),
        ),
      ],
    );
  }
}

// ─── 공용 — 상단바, 진행 표시, CTA ─────────────────────────
class _OnboardingTopBar extends StatelessWidget {
  final bool showBack;
  final VoidCallback? onBack;
  final VoidCallback? onSkip;
  final bool darkMode;
  const _OnboardingTopBar({
    required this.showBack,
    required this.onBack,
    required this.onSkip,
    required this.darkMode,
  });

  @override
  Widget build(BuildContext context) {
    final color = darkMode ? Colors.white : _kText;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
      child: Row(
        children: [
          if (showBack)
            IconButton(
              onPressed: onBack,
              icon: Icon(Icons.arrow_back, color: color),
            )
          else
            const SizedBox(width: 48, height: 48),
          const Spacer(),
          if (onSkip != null)
            TextButton(
              onPressed: onSkip,
              child: Text('건너뛰기',
                  style: TextStyle(
                    color: color.withValues(alpha: 0.75),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  )),
            ),
        ],
      ),
    );
  }
}

class _SurveyProgress extends StatelessWidget {
  final int current;
  final int total;
  const _SurveyProgress({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Text('$current / $total',
              style: const TextStyle(color: _kAccent, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1)),
          const SizedBox(width: 10),
          ...List.generate(total, (i) {
            final on = i < current;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                  color: on ? _kAccent : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(color: on ? _kAccent : const Color(0xFFD0D0D0), width: 1.5),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _DotIndicator extends StatelessWidget {
  final int current;
  final int total;
  const _DotIndicator({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(total, (i) {
          final active = i == current;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: active ? 22 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: active ? _kAccent : const Color(0xFFD0D0D0),
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }),
      ),
    );
  }
}

class _PrimaryCta extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final Color color;
  final Color fg;
  const _PrimaryCta({required this.label, required this.onTap, required this.color, required this.fg});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          disabledBackgroundColor: const Color(0xFFE0E0E0),
          foregroundColor: fg,
          disabledForegroundColor: const Color(0xFF9E9E9E),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
      ),
    );
  }
}
