import 'package:flutter/foundation.dart';
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
import '../widgets/design/condition_pip.dart';
import '../widgets/design/logo.dart';
import '../widgets/design/stamp.dart';
import '../widgets/discount_cause_label.dart';
import '../widgets/discount_countdown.dart';
import '../widgets/notification_sheet.dart';
import '../widgets/price_display.dart';
import 'all_attractions_screen.dart';
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
      // survey 읽기 자체가 실패해도(예: macOS dev 환경의 prefs init 지연)
      // mock route 는 빈 survey 로도 동작하므로 fallback 진행.
      SurveyAnswers? survey = _survey;
      if (survey == null) {
        try {
          survey = await OnboardingService.read();
        } catch (_) {
          // prefs 미가용 → 빈 survey 로 mock 호출 (홈 카드가 영영 안 뜨는 것 방지).
        }
      }
      survey ??=
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
    } catch (e, st) {
      // mock RouteService 가 throw 하는 건 사실상 백엔드 전환 후 시나리오지만,
      // 디버깅을 위해 analytics 에는 남기고 카드는 placeholder 로.
      AnalyticsService.instance
          .logScreenView('home_route_error: ${e.runtimeType}');
      assert(() {
        debugPrint('[home _loadRoute] $e\n$st');
        return true;
      }());
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
            code: Stamp.codeFromName(a.name),
            tone: Stamp.toneFromHints(
              category: a.category,
              thrillLevel: a.thrillLevel,
              hasEasterEgg: a.hasEasterEgg,
            ),
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
    if (a.category != '어트랙션') return ('여유', AppColors.mint);
    if (a.waitMinutes <= 10) return ('여유', AppColors.mint);
    if (a.waitMinutes <= 25) return ('보통', AppColors.yellowDeep);
    return ('혼잡', AppColors.red);
  }

  void _openSearch() {
    AnalyticsService.instance.logScreenView('home_search');
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AllAttractionsScreen()),
    );
  }

  void _openNotifications() {
    AnalyticsService.instance.logScreenView('home_notifications');
    NotificationSheet.show(context);
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
      color: AppColors.bgPage,
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
              onSearchTap: _openSearch,
              onNotifyTap: _openNotifications,
              hasUnread: true, // mock — 백엔드 연동 시 unread count 기반
            ),
            const SizedBox(height: 10),
            // 2. 컨디션 strip — 날씨/혼잡/대기 (탭 시 상세)
            _ConditionStrip(
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
  final VoidCallback? onSearchTap;
  final VoidCallback? onNotifyTap;
  final bool hasUnread;
  const _Header({
    this.onLogoTap,
    this.onProfileTap,
    this.onSearchTap,
    this.onNotifyTap,
    this.hasUnread = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: onLogoTap,
            behavior: HitTestBehavior.opaque,
            child: const RetraceLogo(size: 24, showBeta: true),
          ),
          const Spacer(),
          _PillIcon(
              icon: Icons.search_rounded, onTap: onSearchTap ?? () {}),
          const SizedBox(width: 8),
          _PillIcon(
              icon: Icons.notifications_none_rounded,
              dot: hasUnread,
              onTap: onNotifyTap ?? () {}),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onProfileTap,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.ink900,
                shape: BoxShape.circle,
              ),
              child: const Text(
                'G',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PillIcon extends StatelessWidget {
  final IconData icon;
  final bool dot;
  final VoidCallback onTap;
  const _PillIcon({required this.icon, required this.onTap, this.dot = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.line),
            ),
            child: Icon(icon, size: 18, color: AppColors.ink700),
          ),
          if (dot)
            Positioned(
              top: 8,
              right: 9,
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: AppColors.red,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.bgCard, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── 컨디션 strip — 작은 컬러 pill 3개 ─────────────────────
class _ConditionStrip extends StatelessWidget {
  final String weatherIcon;
  final String weatherShort;
  final String crowdShort;
  final VoidCallback onTap;
  const _ConditionStrip({
    required this.weatherIcon,
    required this.weatherShort,
    required this.crowdShort,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          ConditionPip(icon: Icons.cloud_outlined, label: weatherShort, tint: PipTint.sky),
          ConditionPip(icon: Icons.directions_walk_rounded, label: crowdShort, tint: PipTint.sun),
          const ConditionPip(icon: Icons.access_time_rounded, label: '대기 7분', tint: PipTint.mint),
        ],
      ),
    );
  }
}

// (legacy) — 통합 컨디션은 _ConditionStrip 으로 분리됨.

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
        color: AppColors.bgCard,
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
          const Divider(height: 28, color: AppColors.line),
          // 혼잡도
          _SheetSection(
            icon: '🟡',
            title: '혼잡도',
            lines: ['현재 혼잡도: 중간', crowdDetail],
          ),
          if (pricing != null) ...[
            const Divider(height: 28, color: AppColors.line),
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
                backgroundColor: AppColors.ink900,
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

// ─── 루나 프라이싱 Hero 카드 — 레드 그라디언트 + 초승달 ─────
class _LunaPricingCard extends StatelessWidget {
  final PricingState pricing;
  final VoidCallback onTap;
  final VoidCallback onExpired;
  const _LunaPricingCard({
    required this.pricing,
    required this.onTap,
    required this.onExpired,
  });

  static String _fmt(int n) => n.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );

  static (String, String) _heroLines(DiscountReason r) {
    switch (r) {
      case DiscountReason.weather:
        return ('흐려서', '한산해요.');
      case DiscountReason.weekday:
        return ('평일이라', '한산해요.');
      case DiscountReason.lowDemand:
        return ('오늘은', '여유로워요.');
      case DiscountReason.event:
        return ('오늘은', '특가에요.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final base = pricing.basePrice;
    final discounted = pricing.finalPrice;
    final pct = pricing.discountPercent;
    final (line1, line2) = _heroLines(pricing.reason);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.red, AppColors.redDeep],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.red.withValues(alpha: 0.32),
              blurRadius: 40,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              // 배경 별
              Positioned.fill(
                child: CustomPaint(painter: _SparklePainter()),
              ),
              // 큰 크레센트 (오른쪽 위 글로우)
              Positioned(
                top: -40,
                right: -30,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      center: Alignment(-0.3, -0.3),
                      colors: [
                        Colors.white,
                        AppColors.yellow,
                        Colors.transparent,
                      ],
                      stops: [0.0, 0.55, 0.78],
                    ),
                    backgroundBlendMode: BlendMode.plus,
                  ),
                  foregroundDecoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.0),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 라벨
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppColors.yellow,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'LUNA PRICING · 오늘만',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    // 큰 헤드라인
                    Text.rich(
                      TextSpan(
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.0,
                          height: 1.15,
                        ),
                        children: [
                          TextSpan(text: '$line1\n'),
                          TextSpan(
                            text: line2,
                            style: const TextStyle(color: AppColors.yellow),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    // 가격 row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₩${_fmt(base)}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.lineThrough,
                            decorationColor: Colors.white.withValues(alpha: 0.65),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '₩${_fmt(discounted)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.0,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.yellow,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '−$pct%',
                              style: const TextStyle(
                                color: AppColors.ink900,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // 카운트다운 + CTA
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 14,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                        const SizedBox(width: 5),
                        DiscountCountdown(
                          validUntil: pricing.validUntil,
                          onExpired: onExpired,
                          defaultColor: Colors.white.withValues(alpha: 0.85),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '티켓 받기',
                                style: TextStyle(
                                  color: AppColors.ink900,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(Icons.chevron_right_rounded,
                                  size: 16, color: AppColors.ink900),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 디자인 시안의 반짝이 별 5개 — radial pattern.
class _SparklePainter extends CustomPainter {
  static const _stars = [
    [0.16, 0.10, 4.0],
    [0.78, 0.13, 3.0],
    [0.72, 0.50, 5.0],
    [0.10, 0.58, 3.0],
    [0.86, 0.67, 4.0],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFFFF5C7).withValues(alpha: 0.70);
    for (final s in _stars) {
      final cx = s[0] * size.width;
      final cy = s[1] * size.height;
      final r = s[2];
      final path = Path()
        ..moveTo(cx, cy - r * 2)
        ..lineTo(cx + r * 0.4, cy - r * 0.4)
        ..lineTo(cx + r * 2, cy)
        ..lineTo(cx + r * 0.4, cy + r * 0.4)
        ..lineTo(cx, cy + r * 2)
        ..lineTo(cx - r * 0.4, cy + r * 0.4)
        ..lineTo(cx - r * 2, cy)
        ..lineTo(cx - r * 0.4, cy - r * 0.4)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_SparklePainter o) => false;
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
        color: AppColors.bgCard,
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
                child: Text.rich(
                  TextSpan(
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppColors.ink900,
                      height: 1.25,
                      letterSpacing: -0.6,
                    ),
                    children: [
                      const TextSpan(text: '오늘 루나가 '),
                      TextSpan(
                        text: '${pricing.discountPercent}%',
                        style: const TextStyle(color: AppColors.red),
                      ),
                      const TextSpan(text: '\n드리는 이유'),
                    ],
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: AppColors.line,
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
                    color: AppColors.bgPage,
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
                            color: AppColors.red,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          )),
                    ],
                  ),
                ),
              )),
          const Divider(color: AppColors.line, height: 24),
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
            height: 54,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                onCheckout();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.red,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(99)),
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
  final String name, code, type, crowd;
  final StampTone tone;
  final int waitMin;
  final Color crowdColor;
  const _RouteItem({
    required this.name,
    required this.code,
    required this.tone,
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
      color: AppColors.bgCard,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        // 카드 전체가 탭 영역 — 마이 루나 화면으로 진입.
        onTap: onOpenMap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.line, width: 1),
            color: AppColors.bgCard,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.blueTint,
                  shape: BoxShape.circle,
                ),
                child: const MoonMark(size: 16, color: AppColors.blue, filled: true),
              ),
              const SizedBox(width: 8),
              const Text('마이 루나',
                  style: TextStyle(
                    color: AppColors.ink900,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  )),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.blueTint,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('AI',
                    style: TextStyle(
                      color: AppColors.blue,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    )),
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
                          child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.ink900),
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
                    border: Border.all(color: AppColors.line),
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
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: loading
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 1.5, color: AppColors.blue)),
                          SizedBox(width: 8),
                          Text('동선을 그리고 있어요…',
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                        ],
                      )
                    : Column(
                        children: [
                          const Text('동선을 불러오지 못했어요',
                              style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: onRefresh,
                            behavior: HitTestBehavior.opaque,
                            child: const Text('다시 시도 ↻',
                                style: TextStyle(
                                    color: AppColors.red,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ),
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
                  color: AppColors.ink900,
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
      decoration: BoxDecoration(color: AppColors.ink900, borderRadius: BorderRadius.circular(99)),
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
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 모노타입 2자리 순번 — Stamp 와 시각 무게 분리.
        SizedBox(
          width: 18,
          child: Text(
            index.toString().padLeft(2, '0'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.ink400,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Stamp(code: item.code, tone: item.tone, size: 34),
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
                            item.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink900,
                              letterSpacing: -0.2,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(4)),
                          child: Text(item.type,
                              style: const TextStyle(fontSize: 10, color: AppColors.ink500, fontWeight: FontWeight.w700)),
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
      (tag: '[D-DAY]', bg: AppColors.red, name: '🎭 퍼레이드', time: '오후 2:00'),
      (tag: '[인기]', bg: AppColors.ink900, name: '🎪 서커스쇼', time: '오후 4:30'),
      (tag: '[신규]', bg: AppColors.grape, name: '✨ 불빛 쇼', time: '오후 8:00'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: const [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Eyebrow('TODAY · EVENTS'),
                SizedBox(height: 4),
                Text(
                  '오늘의 이벤트',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.ink900,
                    letterSpacing: -0.6,
                  ),
                ),
              ],
            ),
            Spacer(),
            Text('전체보기',
                style: TextStyle(fontSize: 12, color: AppColors.ink500, fontWeight: FontWeight.w700)),
            Icon(Icons.chevron_right_rounded, size: 14, color: AppColors.ink500),
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
                  color: AppColors.bgCard,
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
