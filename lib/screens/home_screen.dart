import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/attraction.dart';
import '../models/route_response.dart';
import '../services/analytics_service.dart';
import '../services/easter_egg_service.dart';
import '../services/onboarding_service.dart';
import '../services/route_service.dart';
import '../services/visit_history_service.dart';
import '../widgets/companion_bottom_sheet.dart';

/// 홈 탭 — "방문 전" 전용 화면. 방문 결정 → 티켓 구매까지만 담당.
/// 핵심 3카드: 방문 가치 · 루나 프라이싱 · 마이 루나.
class HomeScreen extends StatefulWidget {
  final VoidCallback? onOpenMyLuna;
  final VoidCallback? onResetOnboarding;
  final bool openPricingOnStart;
  const HomeScreen({
    super.key,
    this.onOpenMyLuna,
    this.onResetOnboarding,
    this.openPricingOnStart = false,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // ── Mock 시나리오 (API 연동 전 하드코딩) ─────────────────
  static const int _visitScore = 78;
  static const int _discountPct = 15;

  // 날씨 / 혼잡도 mock
  static const String _weatherIcon = '☁️';
  static const String _weatherWord = '흐림';        // 인과 라인용 단어
  static const String _weatherShort = '흐림 18°C';
  static const String _weatherDetail = '오늘 흐림 · 최저 15°C / 최고 20°C';
  static const String _weatherRain = '강수확률 60% · 과천, 경기도';
  static const String _crowdWord = '한산';          // 날씨 인과의 결과로서의 혼잡도 단어
  static const String _crowdShort = '혼잡 중간';
  static const String _crowdDetail = '오전 11시 이후 방문을 추천드려요';

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
  static const int _kTotalEggCount = 22; // kAttractions 중 hasEasterEgg=true 개수.

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
    if (widget.openPricingOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _autoOpenPricingIfDue());
    }
    _loadRoute('initial');
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
    if (a.category != '어트랙션') return ('여유', const Color(0xFF4CAF50));
    if (a.waitMinutes <= 10) return ('여유', const Color(0xFF4CAF50));
    if (a.waitMinutes <= 25) return ('보통', const Color(0xFFFFC107));
    return ('혼잡', const Color(0xFFE60012));
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
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LunaPricingSheet(
        discountPct: _discountPct,
        lastVisitDaysAgo: _lastVisitDaysAgo,
        missingEggCount: _missingEggCount,
      ),
    );
    // 자동 팝업 쿨다운용 — 어떤 경로로 열렸든 dismiss 시점을 기록.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kPricingSeenAtKey, DateTime.now().millisecondsSinceEpoch);
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
        discountPct: _discountPct,
        onGetTicket: () {
          Navigator.pop(context);
          _openPricingPopup();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF7F7F7),
      child: SafeArea(
        bottom: false,
        child: NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: ListView(
            controller: _scrollCtrl,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            children: [
            // 1. 앱바
            _Header(onLogoTap: _onLogoTap),
            const SizedBox(height: 16),
            // 2. 방문 가치 카드 (날씨·혼잡도·할인·비수기 알림 통합)
            _VisitValueCard(
              score: _visitScore,
              discountPct: _discountPct,
              weatherIcon: _weatherIcon,
              weatherShort: _weatherShort,
              crowdShort: _crowdShort,
              onTap: _openVisitDetailSheet,
            ),
            const SizedBox(height: 14),
            // 3. 루나 프라이싱 카드 — 인과 한 줄 + 카운트다운
            _LunaPricingCard(
              discountPct: _discountPct,
              weatherEmoji: _weatherIcon,
              weatherWord: _weatherWord,
              crowdEmoji: '🟡',
              crowdWord: _crowdWord,
              onTap: _openPricingPopup,
            ),
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
  const _Header({this.onLogoTap});

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
                  style: TextStyle(color: Color(0xFF888888), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 2.2),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('RE-TRACE',
                        style: TextStyle(color: Color(0xFFE60012), fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFFE60012), borderRadius: BorderRadius.circular(4)),
                      child: const Text('BETA',
                          style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Spacer(),
          // 검색/알림 아이콘은 핸들러 연결 전까지 노출 보류.
        ],
      ),
    );
  }
}

// ─── 방문 가치 카드 — 단일 상태 row, 점수 숫자 비노출 ──────────
class _VisitValueCard extends StatelessWidget {
  final int score;            // 내부 헤드라인 분기용 — UI 노출 X
  final int discountPct;
  final String weatherIcon;
  final String weatherShort;
  final String crowdShort;
  final VoidCallback onTap;
  const _VisitValueCard({
    required this.score,
    required this.discountPct,
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

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
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
                          color: Color(0xFF1F1F1F),
                        )),
                    const SizedBox(height: 2),
                    Text(
                      '$weatherShort · $crowdShort · $discountPct% 할인',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF888888),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Text('자세히',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF888888),
                    fontWeight: FontWeight.w700,
                  )),
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: Color(0xFF888888)),
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
  final int discountPct;
  final VoidCallback onGetTicket;
  const _VisitDetailSheet({
    required this.weatherDetail,
    required this.weatherRain,
    required this.crowdDetail,
    required this.discountPct,
    required this.onGetTicket,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
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
              decoration: BoxDecoration(color: const Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(99)),
            ),
          ),
          const SizedBox(height: 18),
          // 날씨
          _SheetSection(
            icon: '☁️',
            title: '날씨',
            lines: [weatherDetail, weatherRain],
          ),
          const Divider(height: 28, color: Color(0xFFEEEEEE)),
          // 혼잡도
          _SheetSection(
            icon: '🟡',
            title: '혼잡도',
            lines: ['현재 혼잡도: 중간', crowdDetail],
          ),
          const Divider(height: 28, color: Color(0xFFEEEEEE)),
          // 할인
          _SheetSection(
            icon: '💰',
            title: '할인',
            lines: ['날씨 기반 오늘의 할인: $discountPct%'],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: onGetTicket,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3158),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              // 이 시트는 결제가 아닌 프라이싱 상세 시트를 띄움 → 카피 정직화.
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
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF1F1F1F))),
          ],
        ),
        const SizedBox(height: 8),
        ...lines.map((l) => Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(l, style: const TextStyle(fontSize: 13, color: Color(0xFF555555), height: 1.5)),
            )),
      ],
    );
  }
}

// ─── 루나 프라이싱 카드 — 인과(날씨→한산→할인) 한 줄 + 카운트다운 ──
class _LunaPricingCard extends StatefulWidget {
  final int discountPct;
  final String weatherEmoji;   // ex. "☁️"
  final String weatherWord;    // ex. "흐림"
  final String crowdEmoji;     // ex. "🟡"
  final String crowdWord;      // ex. "한산"
  final VoidCallback onTap;
  const _LunaPricingCard({
    required this.discountPct,
    required this.weatherEmoji,
    required this.weatherWord,
    required this.crowdEmoji,
    required this.crowdWord,
    required this.onTap,
  });

  @override
  State<_LunaPricingCard> createState() => _LunaPricingCardState();
}

class _LunaPricingCardState extends State<_LunaPricingCard> {
  Timer? _ticker;
  Duration _remaining = _untilMidnight();

  static Duration _untilMidnight() {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    return midnight.difference(now);
  }

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _remaining = _untilMidnight());
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _fmtRemaining() {
    final h = _remaining.inHours.toString().padLeft(2, '0');
    final m = (_remaining.inMinutes % 60).toString().padLeft(2, '0');
    final s = (_remaining.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1E3158),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: widget.onTap,
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
                  color: const Color(0xFFE60012),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('💰 루나 프라이싱',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    )),
              ),
              const SizedBox(height: 14),
              // 인과 라인: 날씨 → 한산 → 할인
              Row(
                children: [
                  _PricingStep(emoji: widget.weatherEmoji, label: widget.weatherWord),
                  const _PricingArrow(),
                  _PricingStep(emoji: widget.crowdEmoji, label: widget.crowdWord),
                  const _PricingArrow(),
                  _PricingStep(
                    emoji: '💸',
                    label: '${widget.discountPct}% 할인',
                    accent: true,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // 카운트다운 + CTA
              Row(
                children: [
                  const Icon(Icons.schedule_rounded,
                      size: 14, color: Color(0xFFAAB8D4)),
                  const SizedBox(width: 4),
                  Text('${_fmtRemaining()} 남음',
                      style: const TextStyle(
                        color: Color(0xFFAAB8D4),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      )),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE60012),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('루나 티켓 받기 →',
                        style: TextStyle(
                          color: Colors.white,
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

class _PricingStep extends StatelessWidget {
  final String emoji;
  final String label;
  final bool accent;
  const _PricingStep({
    required this.emoji,
    required this.label,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
              color: accent ? const Color(0xFFF4B633) : Colors.white,
              fontSize: 13,
              fontWeight: accent ? FontWeight.w900 : FontWeight.w800,
            )),
      ],
    );
  }
}

class _PricingArrow extends StatelessWidget {
  const _PricingArrow();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 6),
      child: Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFFAAB8D4)),
    );
  }
}

// ─── 루나 프라이싱 상세 시트 ───────────────────────────────
class _LunaPricingSheet extends StatefulWidget {
  final int discountPct;
  final int? lastVisitDaysAgo;
  final int missingEggCount;
  const _LunaPricingSheet({
    required this.discountPct,
    required this.lastVisitDaysAgo,
    required this.missingEggCount,
  });

  @override
  State<_LunaPricingSheet> createState() => _LunaPricingSheetState();
}

class _LunaPricingSheetState extends State<_LunaPricingSheet> {
  Timer? _ticker;
  Duration _remaining = _untilMidnight();

  static Duration _untilMidnight() {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    return midnight.difference(now);
  }

  static String _fmt(int n) =>
      n.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  String _fmtRemaining() {
    final h = _remaining.inHours.toString().padLeft(2, '0');
    final m = (_remaining.inMinutes % 60).toString().padLeft(2, '0');
    final s = (_remaining.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _remaining = _untilMidnight());
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final discountPct = widget.discountPct;
    const original = 30000;
    final discounted = original * (100 - discountPct) ~/ 100;
    final saved = original - discounted;
    // 사유 표시는 입력값에 따라 가변 — 실제 비율은 추후 PricingService 합과 동기화.
    final reasons = <(String, String, String)>[
      const ('☁️', '흐린 평일', '+8%'),
      if (widget.lastVisitDaysAgo == null)
        const ('🎉', '첫 방문 환영', '+5%')
      else
        (
          '📅',
          widget.lastVisitDaysAgo! >= 30
              ? '${(widget.lastVisitDaysAgo! / 30).floor()}개월 만의 재방문'
              : '${widget.lastVisitDaysAgo!}일 만의 재방문',
          '+5%',
        ),
      if (widget.missingEggCount > 0)
        ('🥚', '미수집 이스터에그 ${widget.missingEggCount}개', '+2%'),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: const Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(99)))),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  '오늘 루나가 $discountPct%\n드리는 이유',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1F1F1F), height: 1.3),
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 32, height: 32,
                  decoration: const BoxDecoration(color: Color(0xFFF5F5F5), shape: BoxShape.circle),
                  child: const Icon(Icons.close, size: 16, color: Color(0xFF888888)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...reasons.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(color: const Color(0xFFF7F7F7), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      Text(r.$1, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 10),
                      Expanded(child: Text(r.$2, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                      Text(r.$3, style: const TextStyle(color: Color(0xFFE60012), fontSize: 14, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
              )),
          const Divider(color: Color(0xFFEEEEEE), height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${_fmt(original)}원',
                  style: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 15, decoration: TextDecoration.lineThrough)),
              const SizedBox(width: 6),
              const Text('→', style: TextStyle(color: Color(0xFF888888))),
              const SizedBox(width: 6),
              Text('${_fmt(discounted)}원',
                  style: const TextStyle(color: Color(0xFFE60012), fontSize: 24, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 4),
          Text('오늘 ${_fmt(saved)}원 아끼는 중', style: const TextStyle(color: Color(0xFF888888), fontSize: 12)),
          const SizedBox(height: 4),
          Row(
            children: [
              const Text('⏰ 오늘 자정까지 남은 시간 ',
                  style: TextStyle(color: Color(0xFF888888), fontSize: 12)),
              Text(_fmtRemaining(),
                  style: const TextStyle(
                    color: Color(0xFFE60012),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  )),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE60012),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('루나 티켓 ${_fmt(saved)}원 아끼기',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
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
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        // 카드 전체가 탭 영역 — 마이 루나 화면으로 진입.
        onTap: onOpenMap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1E3158), width: 1.5),
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
                  style: TextStyle(color: Color(0xFF1E3158), fontSize: 16, fontWeight: FontWeight.w900)),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3158).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: const Text('AI 맞춤 동선',
                    style: TextStyle(color: Color(0xFF1E3158), fontSize: 11, fontWeight: FontWeight.w700)),
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
                          child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF1E3158)),
                        )
                      : const Icon(Icons.refresh, size: 16, color: Color(0xFF555555)),
                ),
              ),
              InkWell(
                onTap: onSettings,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFDDDDDD)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.tune, size: 14, color: Color(0xFF555555)),
                      SizedBox(width: 4),
                      Text('조건 변경',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF555555))),
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
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF888888), letterSpacing: 0.6)),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(surveyLabel!,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF555555))),
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
            style: const TextStyle(color: Color(0xFF1F1F1F), fontSize: 15, fontWeight: FontWeight.w900),
          ),
          if (totalMin != null) ...[
            const SizedBox(height: 4),
            Text('예상 소요 약 $totalMin분',
                style: const TextStyle(color: Color(0xFF888888), fontSize: 12, fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 16),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text('동선을 불러오는 중…',
                    style: TextStyle(color: Color(0xFF888888), fontSize: 13, fontWeight: FontWeight.w600)),
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
                  color: Color(0xFF1E3158),
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
      decoration: BoxDecoration(color: const Color(0xFF1E3158), borderRadius: BorderRadius.circular(99)),
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
          decoration: const BoxDecoration(color: Color(0xFF1E3158), shape: BoxShape.circle),
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
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1F1F1F)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(4)),
                          child: Text(item.type,
                              style: const TextStyle(fontSize: 10, color: Color(0xFF888888), fontWeight: FontWeight.w600)),
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
                  style: const TextStyle(fontSize: 10, color: Color(0xFF888888))),
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
      (tag: '[D-DAY]', bg: Color(0xFFE60012), name: '🎭 퍼레이드', time: '오후 2:00'),
      (tag: '[인기]', bg: Color(0xFF1E3158), name: '🎪 서커스쇼', time: '오후 4:30'),
      (tag: '[신규]', bg: Color(0xFF8E24AA), name: '✨ 불빛 쇼', time: '오후 8:00'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: const [
            Text('오늘의 이벤트',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1F1F1F))),
            Spacer(),
            Text('전체보기', style: TextStyle(fontSize: 12, color: Color(0xFF888888), fontWeight: FontWeight.w500)),
            Icon(Icons.chevron_right_rounded, size: 14, color: Color(0xFF888888)),
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
                  color: Colors.white,
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
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1F1F1F))),
                    const Spacer(),
                    Text('⏱ ${e.time}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF888888), fontWeight: FontWeight.w600)),
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
