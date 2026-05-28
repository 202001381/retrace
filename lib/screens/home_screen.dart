import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme/app_colors.dart';
import '../models/attraction.dart';
import '../models/pricing_state.dart';
import '../models/route_response.dart';
import '../services/analytics_service.dart';
import '../services/easter_egg_service.dart';
import '../services/luna_pricing_service.dart';
import '../services/onboarding_service.dart';
import '../services/route_service.dart';
import '../services/visit_history_service.dart';
import '../widgets/companion_bottom_sheet.dart';
import '../widgets/discount_cause_label.dart';
import '../widgets/discount_countdown.dart';
import '../widgets/price_display.dart';
import 'checkout_screen.dart';

/// 홈 탭 — "방문 전" 전용 화면. 방문 결정 → 티켓 구매까지만 담당.
/// 핵심 3카드: 방문 가치 · 루나 프라이싱 · 마이 루나.
class HomeScreen extends StatefulWidget {
  final VoidCallback? onOpenMyLuna;
  final VoidCallback? onOpenMyPage;
  final VoidCallback? onResetOnboarding;
  final bool openPricingOnStart;
  const HomeScreen({
    super.key,
    this.onOpenMyLuna,
    this.onOpenMyPage,
    this.onResetOnboarding,
    this.openPricingOnStart = false,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // ── Mock 시나리오 (API 연동 전 하드코딩) ─────────────────
  static const int _visitScore = 78;

  // 날씨 / 혼잡도 mock
  static const String _weatherIcon = '☁️';
  static const String _weatherShort = '흐림 18°C';
  static const String _weatherDetail = '오늘 흐림 · 최저 15°C / 최고 20°C';
  static const String _weatherRain = '강수확률 60% · 과천, 경기도';
  static const String _crowdShort = '혼잡 중간';
  static const String _crowdDetail = '오전 11시 이후 방문을 추천드려요';

  // 루나 프라이싱 — LunaPricingService 응답 1회 캐싱 + 만료 플래그.
  PricingState? _pricing;
  bool _pricingExpired = false;

  String _companion = '가족';
  String _style = '스릴·액티비티';

  // 7회 연속 탭 → 온보딩 초기화 (숨겨진 디버그 제스처).
  int _logoTapCount = 0;
  DateTime? _lastLogoTap;

  // 마이 루나 동선 (RouteService 응답)
  RouteResponse? _route;
  bool _routeLoading = false;
  SurveyAnswers? _survey;

  // 루나 프라이싱 입력값 (영속화 stub — 실제 함수 도입 전까지는 표시용).
  int? _lastVisitDaysAgo;
  int _missingEggCount = 0;
  static const int _kTotalEggCount = 18; // kAttractions 중 hasEasterEgg=true 개수.

  // 루나 프라이싱 자동 팝업 쿨다운 24h.
  static const String _kPricingSeenAtKey = 'pricing_popup_last_seen_at';
  static const int _kPricingCooldownMs = 24 * 60 * 60 * 1000;

  // 스크롤 깊이 측정 — 임계 도달 시 1회씩만 기록.
  final ScrollController _scrollCtrl = ScrollController();
  final Set<int> _loggedDepthPcts = {};
  static const List<int> _kDepthThresholds = [25, 50, 75, 100];

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logScreenView('home');
    _loadSurvey();
    _loadPricingInputs();
    _loadPricing();
    if (widget.openPricingOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _autoOpenPricingIfDue());
    }
    _loadRoute('initial');
  }

  Future<void> _loadPricing() async {
    final p = await LunaPricingService.instance.current();
    if (!mounted) return;
    setState(() {
      _pricing = p;
      _pricingExpired = p.isExpired();
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification n) {
    if (n is! ScrollUpdateNotification) return false;
    final pos = n.metrics;
    if (pos.maxScrollExtent <= 0) return false;
    final depth = (pos.pixels / pos.maxScrollExtent).clamp(0.0, 1.0);
    for (final t in _kDepthThresholds) {
      if (depth * 100 >= t && !_loggedDepthPcts.contains(t)) {
        _loggedDepthPcts.add(t);
        AnalyticsService.instance.logScrollDepth('home', t / 100);
      }
    }
    return false;
  }

  Future<void> _loadSurvey() async {
    final s = await OnboardingService.read();
    if (!mounted) return;
    setState(() => _survey = s);
  }

  Future<void> _loadPricingInputs() async {
    final days = await VisitHistoryService.lastVisitDaysAgo();
    final discovered = await EasterEggService.discoveredAll();
    if (!mounted) return;
    setState(() {
      _lastVisitDaysAgo = days;
      _missingEggCount = (_kTotalEggCount - discovered.length).clamp(0, _kTotalEggCount);
    });
  }

  Future<void> _autoOpenPricingIfDue() async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt(_kPricingSeenAtKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - last < _kPricingCooldownMs) return;
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) _openPricingPopup();
  }

  Future<void> _loadRoute(String reason) async {
    if (_routeLoading) return;
    setState(() => _routeLoading = true);
    try {
      final survey = _survey ??
          (await OnboardingService.read()) ??
          const SurveyAnswers(members: {}, favoriteType: null, purpose: null);
      // 홈 화면은 GPS 없이 정문 기준
      const gateLat = 37.4332, gateLng = 127.0174;
      final req = RouteRequest(
        uid: 'guest',
        lat: gateLat,
        lng: gateLng,
        hasGps: false,
        onboarding: survey,
        completedIds: const {},
        discoveredEggs: const {},
        requestReason: reason,
      );
      final resp = await RouteService.instance.fetchRoute(req);
      if (!mounted) return;
      setState(() => _route = resp);
    } catch (_) {
      // 캐시 유지
    } finally {
      if (mounted) setState(() => _routeLoading = false);
    }
  }

  /// 온보딩 답변을 1줄 라벨로. 예: "👨‍👩‍👧 4명 · 데이트 · 가족·어린이 위주".
  static String? _surveyLabelOf(SurveyAnswers? s) {
    if (s == null || s.total == 0) return null;
    String emoji = '👥';
    var max = 0;
    for (final c in MemberCategory.values) {
      final n = s.count(c);
      if (n > max) {
        max = n;
        emoji = c.emoji;
      }
    }
    final parts = <String>['$emoji ${s.total}명'];
    if (s.purpose != null) parts.add(s.purpose!);
    if (s.favoriteType != null) parts.add(s.favoriteType!);
    return parts.join(' · ');
  }

  List<_RouteItem> get _routeItems {
    final resp = _route;
    if (resp == null) return const [];
    final byId = {for (final a in kAttractions) a.id: a};
    return resp.route
        .map((s) => byId[s.id])
        .whereType<Attraction>()
        .take(3)
        .map((a) {
          final crowd = _crowdLabel(a);
          return _RouteItem(
            name: a.name,
            emoji: a.icon,
            type: _typeLabel(a),
            waitMin: a.waitMinutes,
            crowd: crowd.$1,
            crowdColor: crowd.$2,
          );
        })
        .toList();
  }

  static String _typeLabel(Attraction a) {
    switch (a.category) {
      case '음식점':
        return '음식';
      case '카페':
        return '카페';
      case '포토스팟':
        return '포토';
      default:
        if (a.thrillLevel >= 4) return '스릴';
        if (a.thrillLevel >= 3) return '액티비티';
        return '여유';
    }
  }

  static (String, Color) _crowdLabel(Attraction a) {
    if (a.category != '어트랙션') return ('여유', AppColors.success);
    if (a.waitMinutes <= 10) return ('여유', AppColors.success);
    if (a.waitMinutes <= 25) return ('보통', AppColors.warning);
    return ('혼잡', AppColors.sunsetCoral);
  }

  void _onLogoTap() {
    final now = DateTime.now();
    if (_lastLogoTap == null || now.difference(_lastLogoTap!) > const Duration(seconds: 2)) {
      _logoTapCount = 1;
    } else {
      _logoTapCount += 1;
    }
    _lastLogoTap = now;
    if (_logoTapCount >= 7) {
      _logoTapCount = 0;
      widget.onResetOnboarding?.call();
    }
  }

  void _openSettingsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CompanionBottomSheet(
        initialCompanion: _companion,
        initialStyle: _style,
        onConfirm: (c, s) => setState(() {
          _companion = c;
          _style = s;
        }),
      ),
    );
  }

  Future<void> _openPricingPopup() async {
    final p = _pricing;
    if (p == null || _pricingExpired) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LunaPricingSheet(
        pricing: p,
        lastVisitDaysAgo: _lastVisitDaysAgo,
        missingEggCount: _missingEggCount,
        onCheckout: () => _goToCheckout(p),
        onExpired: () {
          if (mounted) setState(() => _pricingExpired = true);
        },
      ),
    );
    // 자동 팝업 쿨다운용 — 어떤 경로로 열렸든 dismiss 시점을 기록.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kPricingSeenAtKey, DateTime.now().millisecondsSinceEpoch);
  }

  void _goToCheckout(PricingState pricing) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CheckoutScreen(pricing: pricing)),
    );
  }

  void _openVisitDetailSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _VisitDetailSheet(
        weatherDetail: _weatherDetail,
        weatherRain: _weatherRain,
        crowdDetail: _crowdDetail,
        pricing: _pricing,
        onMoreDiscount: () {
          Navigator.pop(context);
          _openPricingPopup();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.cream,
      child: SafeArea(
        bottom: false,
        child: NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: ListView(
            controller: _scrollCtrl,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            children: [
            // 1. 앱바
            _Header(
              onLogoTap: _onLogoTap,
              onProfileTap: widget.onOpenMyPage,
            ),
            const SizedBox(height: 16),
            // 2. 방문 가치 카드 (날씨·혼잡도·할인·비수기 알림 통합)
            _VisitValueCard(
              score: _visitScore,
              pricing: _pricing,
              weatherIcon: _weatherIcon,
              weatherShort: _weatherShort,
              crowdShort: _crowdShort,
              onTap: _openVisitDetailSheet,
            ),
            const SizedBox(height: 14),
            // 3. 루나 프라이싱 카드 — 인과 + 가격 + 카운트다운
            if (_pricing != null && !_pricingExpired)
              _LunaPricingCard(
                pricing: _pricing!,
                onTap: _openPricingPopup,
                onExpired: () => setState(() => _pricingExpired = true),
              ),
            if (_pricing != null && !_pricingExpired)
              const SizedBox(height: 14),
            // 4. 마이 루나 카드
            _MyLunaCard(
              companion: _companion,
              style: _style,
              surveyLabel: _surveyLabelOf(_survey),
              items: _routeItems,
              rationale: _route?.rationale,
              totalMin: _route?.totalMin,
              loading: _routeLoading,
              onSettings: _openSettingsSheet,
              onOpenMap: widget.onOpenMyLuna,
              onRefresh: () => _loadRoute('manual_refresh'),
            ),
            const SizedBox(height: 20),
            // 5. 오늘의 이벤트
            const _TodayEventsSection(),
          ],
          ),
        ),
      ),
    );
  }
}

// ─── 앱바 ──────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final VoidCallback? onLogoTap;
  final VoidCallback? onProfileTap;
  const _Header({this.onLogoTap, this.onProfileTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: onLogoTap,
            behavior: HitTestBehavior.opaque,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '서울랜드',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 2.2),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('RE-TRACE',
                        style: TextStyle(color: AppColors.sunsetCoral, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.sunsetCoral, borderRadius: BorderRadius.circular(4)),
                      child: const Text('BETA',
                          style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Spacer(),
          // 마이페이지 진입점 — 44x44 tap target (Apple HIG).
          SizedBox(
            width: 44,
            height: 44,
            child: IconButton(
              onPressed: onProfileTap,
              padding: EdgeInsets.zero,
              icon: const Icon(
                Icons.account_circle_outlined,
                size: 28,
                color: AppColors.textPrimary,
              ),
              tooltip: '마이페이지',
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 방문 가치 카드 — 단일 상태 row, 점수 숫자 비노출 ──────────
class _VisitValueCard extends StatelessWidget {
  final int score;              // 내부 헤드라인 분기용 — UI 노출 X
  final PricingState? pricing;  // 할인율은 PricingState 가 진실
  final String weatherIcon;
  final String weatherShort;
  final String crowdShort;
  final VoidCallback onTap;
  const _VisitValueCard({
    required this.score,
    required this.pricing,
    required this.weatherIcon,
    required this.weatherShort,
    required this.crowdShort,
    required this.onTap,
  });

  String get _headline {
    if (score >= 85) return '지금 가시면 대기 거의 없어요';
    if (score >= 80) return '오늘 방문 강추!';
    if (score >= 50) return '방문하기 좋은 날';
    return '오늘은 한산해요';
  }

  String get _subline {
    final base = '$weatherShort · $crowdShort';
    if (pricing == null) return base;
    return '$base · ${pricing!.discountPercent}% 할인';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cardWhite,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          child: Row(
            children: [
              Text(weatherIcon, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_headline,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        )),
                    const SizedBox(height: 2),
                    Text(
                      _subline,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Text('자세히',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  )),
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── 방문 가치 상세 바텀 시트 ───────────────────────────────
class _VisitDetailSheet extends StatelessWidget {
  final String weatherDetail;
  final String weatherRain;
  final String crowdDetail;
  final PricingState? pricing;
  final VoidCallback onMoreDiscount;
  const _VisitDetailSheet({
    required this.weatherDetail,
    required this.weatherRain,
    required this.crowdDetail,
    required this.pricing,
    required this.onMoreDiscount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 5,
              decoration: BoxDecoration(color: AppColors.textSecondary, borderRadius: BorderRadius.circular(99)),
            ),
          ),
          const SizedBox(height: 18),
          // 날씨
          _SheetSection(
            icon: '☁️',
            title: '날씨',
            lines: [weatherDetail, weatherRain],
          ),
          const Divider(height: 28, color: AppColors.border),
          // 혼잡도
          _SheetSection(
            icon: '🟡',
            title: '혼잡도',
            lines: ['현재 혼잡도: 중간', crowdDetail],
          ),
          if (pricing != null) ...[
            const Divider(height: 28, color: AppColors.border),
            // 할인 — PricingState 의 인과 라벨 + 가격 컴포넌트로 일관 표시.
            Row(
              children: [
                const Text('💰', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                const Text('할인',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    )),
              ],
            ),
            const SizedBox(height: 10),
            DiscountCauseLabel(state: pricing!),
            const SizedBox(height: 8),
            PriceDisplay(state: pricing!),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: onMoreDiscount,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.lunaNavy,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('💰 오늘 할인 자세히 보기',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetSection extends StatelessWidget {
  final String icon;
  final String title;
  final List<String> lines;
  const _SheetSection({required this.icon, required this.title, required this.lines});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(title,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
          ],
        ),
        const SizedBox(height: 8),
        ...lines.map((l) => Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(l, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5)),
            )),
      ],
    );
  }
}

// ─── 루나 프라이싱 카드 — 인과 라벨 + 가격 + 카운트다운 ────────
class _LunaPricingCard extends StatelessWidget {
  final PricingState pricing;
  final VoidCallback onTap;
  final VoidCallback onExpired;
  const _LunaPricingCard({
    required this.pricing,
    required this.onTap,
    required this.onExpired,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.lunaNavy,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.moonlightGold,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('💰 루나 프라이싱',
                    style: TextStyle(
                      color: AppColors.textOnDark,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    )),
              ),
              const SizedBox(height: 14),
              // 인과 라벨 ("🌥 흐려서 한산 → 15% 할인")
              DiscountCauseLabel(state: pricing, dark: true),
              const SizedBox(height: 10),
              // 정가·할인가 표시 (PriceDisplay compact — 네이비 배경에 pricing 강조).
              PriceDisplay(
                state: pricing,
                accentColor: AppColors.moonlightGold,
              ),
              const SizedBox(height: 14),
              // 카운트다운 + CTA
              Row(
                children: [
                  DiscountCountdown(
                    validUntil: pricing.validUntil,
                    onExpired: onExpired,
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppColors.sunsetCoral,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('루나 티켓 받기 →',
                        style: TextStyle(
                          color: AppColors.cardWhite,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        )),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── 루나 프라이싱 상세 시트 ───────────────────────────────
class _LunaPricingSheet extends StatelessWidget {
  final PricingState pricing;
  final int? lastVisitDaysAgo;
  final int missingEggCount;
  final VoidCallback onCheckout;
  final VoidCallback onExpired;
  const _LunaPricingSheet({
    required this.pricing,
    required this.lastVisitDaysAgo,
    required this.missingEggCount,
    required this.onCheckout,
    required this.onExpired,
  });

  static String _fmt(int n) => n.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );

  @override
  Widget build(BuildContext context) {
    final saved = pricing.discountAmount;
    // 사유 표시는 PricingState.reason 이 결정 + 보조 입력(재방문·미수집 에그) 가산.
    final reasons = <(String, String, String)>[
      (pricing.reasonEmoji, pricing.reasonLabel, '+${pricing.discountPercent - _bonusPct()}%'),
      if (lastVisitDaysAgo == null)
        const ('🎉', '첫 방문 환영', '+5%')
      else
        (
          '📅',
          lastVisitDaysAgo! >= 30
              ? '${(lastVisitDaysAgo! / 30).floor()}개월 만의 재방문'
              : '${lastVisitDaysAgo!}일 만의 재방문',
          '+5%',
        ),
      if (missingEggCount > 0)
        ('🥚', '미수집 이스터에그 $missingEggCount개', '+2%'),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.textSecondary,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  '오늘 루나가 ${pricing.discountPercent}%\n드리는 이유',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    height: 1.3,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: AppColors.border,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 16, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...reasons.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.cream,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Text(r.$1, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(r.$2,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            )),
                      ),
                      Text(r.$3,
                          style: const TextStyle(
                            color: AppColors.sunsetCoral,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          )),
                    ],
                  ),
                ),
              )),
          const Divider(color: AppColors.border, height: 24),
          // 정가·할인가 hero 표시.
          PriceDisplay(state: pricing, size: PriceDisplaySize.hero),
          const SizedBox(height: 6),
          Text('오늘 ${_fmt(saved)}원 아끼는 중',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 8),
          DiscountCountdown(
            validUntil: pricing.validUntil,
            onExpired: onExpired,
            defaultColor: AppColors.textSecondary,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                onCheckout();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.sunsetCoral,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('루나 티켓 ${_fmt(saved)}원 아끼기',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }

  /// 보조 사유(재방문 5% + 미수집 에그 2%) 합산해 메인 인과의 잔여 비율 계산.
  int _bonusPct() {
    int b = 5; // 재방문/첫방문 카피 모두 +5%
    if (missingEggCount > 0) b += 2;
    return b;
  }
}

// ─── 마이 루나 카드 ────────────────────────────────────────
class _RouteItem {
  final String name, emoji, type, crowd;
  final int waitMin;
  final Color crowdColor;
  const _RouteItem({
    required this.name,
    required this.emoji,
    required this.type,
    required this.waitMin,
    required this.crowd,
    required this.crowdColor,
  });
}

class _MyLunaCard extends StatelessWidget {
  final String companion;
  final String style;
  final String? surveyLabel;
  final List<_RouteItem> items;
  final String? rationale;
  final int? totalMin;
  final bool loading;
  final VoidCallback onSettings;
  final VoidCallback? onOpenMap;
  final VoidCallback onRefresh;
  const _MyLunaCard({
    required this.companion,
    required this.style,
    required this.surveyLabel,
    required this.items,
    required this.rationale,
    required this.totalMin,
    required this.loading,
    required this.onSettings,
    required this.onOpenMap,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cardWhite,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        // 카드 전체가 탭 영역 — 마이 루나 화면으로 진입.
        onTap: onOpenMap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.lunaNavy, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
          Row(
            children: [
              const Text('🌙', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 6),
              const Text('마이 루나',
                  style: TextStyle(color: AppColors.lunaNavy, fontSize: 16, fontWeight: FontWeight.w900)),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.lunaNavy.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: const Text('AI 맞춤 동선',
                    style: TextStyle(color: AppColors.lunaNavy, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
              const Spacer(),
              InkWell(
                onTap: loading ? null : onRefresh,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: loading
                      ? const SizedBox(
                          width: 14, height: 14,
                          child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.lunaNavy),
                        )
                      : const Icon(Icons.refresh, size: 16, color: AppColors.textSecondary),
                ),
              ),
              InkWell(
                onTap: onSettings,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.tune, size: 14, color: AppColors.textSecondary),
                      SizedBox(width: 4),
                      Text('조건 변경',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (surveyLabel != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Text('온보딩 답변',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.textSecondary, letterSpacing: 0.6)),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(surveyLabel!,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            children: [
              _Pill(text: companion),
              _Pill(text: style),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            rationale ?? '오늘의 추천 동선을 준비하고 있어요 🌙',
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w900),
          ),
          if (totalMin != null) ...[
            const SizedBox(height: 4),
            Text('예상 소요 약 $totalMin분',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 16),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text('동선을 불러오는 중…',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            )
          else
            ...items.asMap().entries.map((e) => Padding(
                  padding: EdgeInsets.only(bottom: e.key == items.length - 1 ? 0 : 12),
                  child: _RouteRow(index: e.key + 1, item: e.value),
                )),
          const SizedBox(height: 14),
          // 인라인 텍스트 링크 — CTA 버튼 대체 (카드 전체 탭과 중복 제거).
          const Align(
            alignment: Alignment.centerRight,
            child: Text('전체 동선 보기 →',
                style: TextStyle(
                  color: AppColors.lunaNavy,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                )),
          ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  const _Pill({required this.text});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(color: AppColors.lunaNavy, borderRadius: BorderRadius.circular(99)),
      child: Text(text,
          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

class _RouteRow extends StatelessWidget {
  final int index;
  final _RouteItem item;
  const _RouteRow({required this.index, required this.item});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24, height: 24,
          decoration: const BoxDecoration(color: AppColors.lunaNavy, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text('$index',
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            '${item.emoji} ${item.name}',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4)),
                          child: Text(item.type,
                              style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 6, height: 6, decoration: BoxDecoration(color: item.crowdColor, shape: BoxShape.circle)),
                      const SizedBox(width: 4),
                      Text(item.crowd,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: item.crowdColor)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text('⏱ 예상 대기 ${item.waitMin}분',
                  style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── 오늘의 이벤트 ─────────────────────────────────────────
class _TodayEventsSection extends StatelessWidget {
  const _TodayEventsSection();
  @override
  Widget build(BuildContext context) {
    const events = [
      (tag: '[D-DAY]', bg: AppColors.sunsetCoral, name: '🎭 퍼레이드', time: '오후 2:00'),
      (tag: '[인기]', bg: AppColors.lunaNavy, name: '🎪 서커스쇼', time: '오후 4:30'),
      (tag: '[신규]', bg: AppColors.discoveryPurple, name: '✨ 불빛 쇼', time: '오후 8:00'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: const [
            Text('오늘의 이벤트',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
            Spacer(),
            Text('전체보기', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
            Icon(Icons.chevron_right_rounded, size: 14, color: AppColors.textSecondary),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 104,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: events.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final e = events[i];
              return Container(
                width: 150,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.cardWhite,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: e.bg, borderRadius: BorderRadius.circular(4)),
                      child: Text(e.tag,
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(height: 8),
                    Text(e.name,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                    const Spacer(),
                    Text('⏱ ${e.time}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
