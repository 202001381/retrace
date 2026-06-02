import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../l10n/generated/app_localizations.dart';
import '../services/onboarding_service.dart';
import '../widgets/design/condition_pip.dart';
import '../widgets/design/logo.dart';

const _kAccent = Color(0xFFE60012);
const _kSelectedBg = Color(0xFFFFF5F5);
const _kBorderIdle = Color(0xFFE0E0E0);
const _kText = Color(0xFF1F1F1F);
const _kMuted = Color(0xFF888888);
/// Welcome / 결과 화면 등 dark-bg 의 *대표 단색* — 단독 색 필요 시.
/// v3 에서 컬러 통일을 위해 navy → red-deep 으로 변경.
const _kDarkBg = Color(0xFFB8001C);
const _kCardBg = Color(0xFFF7F7F7);

/// Seoul Land 레드 그라디언트 — Welcome / IntroDarkCenter / Result 공통.
const _kRedGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    Color(0xFFE60023), // brand red
    Color(0xFFB8001C), // red-deep
    Color(0xFF7A0014), // deep maroon
  ],
  stops: [0.0, 0.55, 1.0],
);

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

// 데모용 — 오늘 할인 여부 / 할인율 (실제로는 백엔드 루나 프라이싱 응답).
const bool _kHasDiscountToday = true;
const int _kDiscountPct = 15;

class OnboardingScreen extends StatefulWidget {
  final void Function(OnboardingExit exit) onDone;
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
    widget.onDone(OnboardingExit.home);
  }

  Future<void> _finish(OnboardingExit exit) async {
    await OnboardingService.save(
      SurveyAnswers(
        members: Map.from(_members),
        favoriteType: _favoriteType,
        purpose: _purpose,
      ),
      resultLabel: _resultLabel(),
      totalMembers: _total,
    );
    if (!mounted) return;
    widget.onDone(exit);
  }

  // ── 구성원 요약 로직 ───────────────────────────────────────
  int _count(MemberCategory c) => _members[c] ?? 0;

  /// 우선순위: 가족 > 스릴 > 데이트 > 맞춤.
  String _resultLabel() {
    if (_count(MemberCategory.infant) > 0) return '가족 코스';
    if (_count(MemberCategory.teen) > 0 || _favoriteType == FavoriteType.thrill) {
      return '스릴 코스';
    }
    final adultsOnly = _count(MemberCategory.infant) == 0 &&
        _count(MemberCategory.child) == 0 &&
        _count(MemberCategory.teen) == 0 &&
        _count(MemberCategory.seniorMale) == 0 &&
        _count(MemberCategory.seniorFemale) == 0;
    if (adultsOnly && _purpose == VisitPurpose.date) return '데이트 코스';
    return '맞춤 코스';
  }

  /// 결과 화면 서브 텍스트.
  String _summaryText() {
    final label = _resultLabel();
    final total = _total;
    switch (label) {
      case '가족 코스':
        final infant = _count(MemberCategory.infant);
        if (infant > 0) return '유아 $infant명과 함께하는 가족 코스로 짰어요 🎠';
        return '$total인 가족 코스로 짰어요 🎠';
      case '스릴 코스':
        return '스릴을 즐기는 $total인 코스로 짰어요 🎢';
      case '데이트 코스':
        return '둘만의 데이트 코스로 짰어요 💑';
      default:
        return '$total인 맞춤 코스로 짰어요 ✨';
    }
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
              title: AppL10n.of(context)!.onboarding_my_luna_what,
              cards: [
                (icon: '🗺️', title: AppL10n.of(context)!.onboarding_for_you, desc: AppL10n.of(context)!.onboarding_personalized_desc),
                (icon: '🔄', title: AppL10n.of(context)!.onboarding_anytime_new_course, desc: AppL10n.of(context)!.onboarding_personalized_desc),
              ],
              ctaLabel: AppL10n.of(context)!.common_next,
              onBack: _back,
              onSkip: _skipFromIntro,
              onNext: () => _goTo(2),
            ),
            _IntroExplainPage(
              icon: '💰',
              title: AppL10n.of(context)!.onboarding_luna_pricing_what,
              cards: [
                (icon: '⏰', title: AppL10n.of(context)!.onboarding_realtime_discount, desc: AppL10n.of(context)!.onboarding_pricing_desc),
                (icon: '🔔', title: AppL10n.of(context)!.onboarding_proactive_notif, desc: AppL10n.of(context)!.onboarding_notif_desc),
              ],
              ctaLabel: AppL10n.of(context)!.common_next,
              onBack: _back,
              onSkip: _skipFromIntro,
              onNext: () => _goTo(3),
            ),
            _IntroDarkCenterPage(
              icon: '✨',
              title: AppL10n.of(context)!.onboarding_make_my_luna,
              subtitle: AppL10n.of(context)!.onboarding_just_3,
              ctaLabel: AppL10n.of(context)!.onboarding_start,
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
              title: AppL10n.of(context)!.onboarding_q_favorite,
              options: [
                (emoji: '🎢', title: AppL10n.of(context)!.fav_thrill, desc: AppL10n.of(context)!.onboarding_thrill_fast, value: FavoriteType.thrill),
                (emoji: '🎠', title: AppL10n.of(context)!.fav_family, desc: AppL10n.of(context)!.onboarding_family_together, value: FavoriteType.family),
                (emoji: '✨', title: AppL10n.of(context)!.fav_either, desc: AppL10n.of(context)!.onboarding_either_ok, value: FavoriteType.both),
              ],
              selected: _favoriteType,
              onSelect: (v) => setState(() => _favoriteType = v),
              onBack: _back,
              onNext: _favoriteType != null ? () => _goTo(6) : null,
            ),
            _SingleChoiceSurveyPage(
              progress: 3,
              title: AppL10n.of(context)!.onboarding_q_purpose,
              options: [
                (emoji: '🎡', title: AppL10n.of(context)!.purpose_rides, desc: null, value: VisitPurpose.rides),
                (emoji: '🌿', title: AppL10n.of(context)!.purpose_picnic, desc: null, value: VisitPurpose.picnic),
                (emoji: '👶', title: AppL10n.of(context)!.purpose_kids_outing, desc: null, value: VisitPurpose.kidsOuting),
                (emoji: '💑', title: AppL10n.of(context)!.purpose_date, desc: null, value: VisitPurpose.date),
              ],
              selected: _purpose,
              onSelect: (v) => setState(() => _purpose = v),
              onBack: _back,
              onNext: _purpose != null ? () => _goTo(7) : null,
            ),
            _ResultPage(
              summaryText: _summaryText(),
              hasDiscount: _kHasDiscountToday,
              discountPct: _kDiscountPct,
              onSeeRoute: () => _finish(OnboardingExit.mapTab),
              onGetTicket: () => _finish(OnboardingExit.pricingPopup),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 인트로 1: Welcome — v3 그라디언트 hero ─────────────────
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
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: _kRedGradient),
      child: Stack(
        children: [
          // 오른쪽 위 yellow→amber glow (mock crescent)
          Positioned(
            top: -50,
            right: -40,
            child: Container(
              width: 230,
              height: 230,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: Alignment(-0.2, -0.2),
                  colors: [
                    Color(0xFFFFF5C7),
                    Color(0xFFFFCC2A),
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.45, 0.85],
                ),
              ),
            ),
          ),
          // 산재된 작은 별
          const Positioned.fill(child: _StarField()),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _OnboardingTopBar(showBack: false, onBack: null, onSkip: onSkip, darkMode: true),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Eyebrow('WELCOME', color: Colors.white, size: 11),
                      const SizedBox(height: 16),
                      Text(
                        AppL10n.of(context)!.onboarding_welcome_title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 44,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.4,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        AppL10n.of(context)!.onboarding_intro_title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          height: 1.55,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(flex: 2),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                  child: Row(
                    children: [
                      Expanded(
                        child: _BranchButton(
                          label: AppL10n.of(context)!.onboarding_start,
                          bg: Colors.white,
                          fg: AppColors.ink900,
                          onTap: onFirstTime,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _BranchButton(
                          label: AppL10n.of(context)!.onboarding_browse,
                          bg: Colors.white.withValues(alpha: 0.16),
                          fg: Colors.white,
                          border: Colors.white.withValues(alpha: 0.4),
                          onTap: onReturning,
                        ),
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

/// Welcome 화면 산재 별 — SVG 4꼭짓점 별 8개.
class _StarField extends StatelessWidget {
  const _StarField();
  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _StarFieldPainter());
  }
}

class _StarFieldPainter extends CustomPainter {
  static const _stars = [
    [0.20, 0.32, 6.0],
    [0.84, 0.40, 4.0],
    [0.92, 0.58, 5.0],
    [0.08, 0.62, 4.0],
    [0.78, 0.74, 6.0],
    [0.32, 0.82, 4.0],
    [0.16, 0.88, 5.0],
    [0.60, 0.46, 3.0],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.85);
    for (final s in _stars) {
      final cx = s[0] * size.width;
      final cy = s[1] * size.height;
      final r = s[2];
      final path = Path()
        ..moveTo(cx, cy - r * 2)
        ..lineTo(cx + r * 0.35, cy - r * 0.35)
        ..lineTo(cx + r * 2, cy)
        ..lineTo(cx + r * 0.35, cy + r * 0.35)
        ..lineTo(cx, cy + r * 2)
        ..lineTo(cx - r * 0.35, cy + r * 0.35)
        ..lineTo(cx - r * 2, cy)
        ..lineTo(cx - r * 0.35, cy - r * 0.35)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_StarFieldPainter o) => false;
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
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: _kRedGradient),
      child: Stack(
        children: [
          // 오른쪽 위 노란 글로우 (Welcome 페이지와 연속성).
          Positioned(
            top: -60,
            right: -50,
            child: Container(
              width: 220,
              height: 220,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: Alignment(-0.2, -0.2),
                  colors: [
                    Color(0xFFFFF5C7),
                    Color(0xFFFFCC2A),
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.45, 0.85],
                ),
              ),
            ),
          ),
          SafeArea(
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
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      height: 1.35,
                      letterSpacing: -0.8,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(flex: 2),
                if (showSkip) const _DotIndicator(current: 3, total: 4),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
                  child: _PrimaryCta(
                    label: ctaLabel,
                    onTap: onNext,
                    color: Colors.white,
                    fg: _kDarkBg,
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

// ─── 결과 화면 ─────────────────────────────────────────────
class _ResultPage extends StatelessWidget {
  final String summaryText;
  final bool hasDiscount;
  final int discountPct;
  final VoidCallback onSeeRoute;
  final VoidCallback onGetTicket;
  const _ResultPage({
    required this.summaryText,
    required this.hasDiscount,
    required this.discountPct,
    required this.onSeeRoute,
    required this.onGetTicket,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: _kRedGradient),
      child: Stack(
        children: [
          // 우상단 노란 글로우 — Welcome 페이지와 연속성.
          Positioned(
            top: -60,
            right: -50,
            child: Container(
              width: 220,
              height: 220,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: Alignment(-0.2, -0.2),
                  colors: [
                    Color(0xFFFFF5C7),
                    Color(0xFFFFCC2A),
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.45, 0.85],
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Column(
              children: [
                const Spacer(),
                // ── 상단: 마이 루나 완성 메시지 ──
                const Text('🌙', style: TextStyle(fontSize: 56)),
                const SizedBox(height: 20),
                Text(
                  AppL10n.of(context)!.onboarding_ready,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    summaryText,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                // ── 중간: 루나 프라이싱 카드 (조건부) ──
                if (hasDiscount)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _PricingCard(discountPct: discountPct),
                  ),
                const Spacer(flex: 2),
                // ── 하단: CTA 버튼 ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: onSeeRoute,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: _kDarkBg,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(99)),
                          ),
                          child: const Text(
                            '🗺️  오늘의 동선 보러가기',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                      if (hasDiscount) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: onGetTicket,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.18),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(99)),
                            ),
                            child: const Text(
                              '💰  할인 티켓 먼저 받기',
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      ],
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

class _PricingCard extends StatelessWidget {
  final int discountPct;
  const _PricingCard({required this.discountPct});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('💰 루나 프라이싱',
                    style: TextStyle(color: _kAccent, fontSize: 14, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                const Text('오늘 한산한 날이에요',
                    style: TextStyle(color: _kText, fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text('지금 입장하면 정가 대비 $discountPct% 할인',
                    style: const TextStyle(color: _kMuted, fontSize: 14)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text('$discountPct%',
              style: const TextStyle(color: _kAccent, fontSize: 32, fontWeight: FontWeight.w900)),
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
        const SizedBox(height: 22),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Eyebrow('STEP 01 · WHO', color: AppColors.red),
              const SizedBox(height: 8),
              Text(
                AppL10n.of(context)!.onboarding_q_party,
                style: const TextStyle(
                  color: AppColors.ink900,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  height: 1.25,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 6),
              Text(AppL10n.of(context)!.onboarding_party_count_msg,
                  style: const TextStyle(color: AppColors.ink500, fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        const SizedBox(height: 18),
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
                  Text(AppL10n.of(context)!.onboarding_party_total,
                      style: const TextStyle(color: _kMuted, fontSize: 13, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Text('$total',
                      style: TextStyle(
                        color: total > 0 ? _kAccent : _kMuted,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      )),
                ],
              ),
              const SizedBox(height: 12),
              _PrimaryCta(
                label: AppL10n.of(context)!.common_next,
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
        const SizedBox(height: 22),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Eyebrow(
                progress == 2 ? 'STEP 02 · MOOD' : 'STEP 03 · PURPOSE',
                color: AppColors.red,
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.ink900,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    height: 1.25,
                    letterSpacing: -0.8,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(AppL10n.of(context)!.onboarding_pick_accurate,
                  style: const TextStyle(color: AppColors.ink500, fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        const SizedBox(height: 18),
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
          child: _PrimaryCta(label: AppL10n.of(context)!.common_next, onTap: onNext, color: _kAccent, fg: Colors.white),
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
              child: Text(AppL10n.of(context)!.onboarding_skip,
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

/// v3 progress bar — N개 segment, 채워진 건 빨강·미완은 옅은 라인.
class _SurveyProgress extends StatelessWidget {
  final int current;
  final int total;
  const _SurveyProgress({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Row(
        children: List.generate(total, (i) {
          final on = i < current;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i == total - 1 ? 0 : 6),
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: on ? AppColors.red : AppColors.ink200,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
          );
        }),
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
