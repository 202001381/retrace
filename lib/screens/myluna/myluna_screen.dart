import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_colors.dart';
import '../../widgets/design/logo.dart';
import '../../widgets/design/stamp.dart';

import '../../models/attraction.dart';
import '../../models/demo_scenario.dart';
import '../../models/luna_recommendation.dart';
import '../../models/route_response.dart';
import '../../services/easter_egg_service.dart';
import '../../services/luna_recommendation_store.dart';
import '../../services/onboarding_service.dart';
import '../../services/route_service.dart';
import '../../widgets/companion_bottom_sheet.dart';
import 'myluna_navigate_screen.dart';

/// 마이 루나 — 개인화 동선 단일 진실 탭.
/// "다음 뭐 해?" 명제(My Park Visit 검증 패턴) + Disney Genie 반면교사 윈도우 고정.
class MyLunaScreen extends StatefulWidget {
  const MyLunaScreen({super.key});

  @override
  State<MyLunaScreen> createState() => _MyLunaScreenState();
}

class _MyLunaScreenState extends State<MyLunaScreen> {
  // ── 출발점 ───────────────────────────────────────────────
  static const LatLng _kGate = LatLng(37.4332, 127.0174);
  // 평균 도보 속도 80m/min — 명세 기준.
  // TODO: RouteService(66.67m/min)와 거리 계산식 통일 검토 필요.
  static const double _kWalkSpeedMpm = 80;

  // 무한 skip 방지 — 같은 세션에서 N회 연속 시 자동 fetch 멈춤.
  static const int _kMaxConsecutiveSkips = 3;

  // ── 상태 ─────────────────────────────────────────────────
  LunaRecommendation? _rec;
  bool _loading = false;
  String? _error;
  LatLng? _myPos;
  SurveyAnswers? _survey;
  Set<String> _discoveredEggs = const {};
  int _consecutiveSkips = 0;
  bool _skipBlocked = false; // 자동 fetch 차단 상태

  // 윈도우 만료 버튼 노출 트리거 — 1분마다 재평가.
  Timer? _windowTicker;

  // 사용자가 임의로 선택한 companion/style (CompanionBottomSheet).
  String _companion = '가족';
  String _style = '스릴·액티비티';

  // 데모 시나리오 (백엔드 연동 전 한정) — null = 기본 추천 로직.
  DemoScenario? _activeScenario;

  // 데모 picker 영구 dismiss 상태. 한 번 닫으면 다시 안 보임.
  static const String _kDemoDismissedKey = 'demo_picker_dismissed';
  bool _demoDismissed = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
    _loadDemoDismissed();
    _windowTicker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {}); // 만료 시점 UI 갱신용
    });
  }

  Future<void> _loadDemoDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _demoDismissed = prefs.getBool(_kDemoDismissedKey) ?? false);
  }

  Future<void> _dismissDemo() async {
    HapticFeedback.selectionClick();
    setState(() => _demoDismissed = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDemoDismissedKey, true);
  }

  @override
  void dispose() {
    _windowTicker?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final survey = await OnboardingService.read();
    final eggs = await EasterEggService.discoveredAll();
    await _tryGps();
    if (!mounted) return;
    setState(() {
      _survey = survey;
      _discoveredEggs = eggs;
    });
    await _fetch(reason: 'initial');
  }

  Future<void> _tryGps() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.always ||
          perm == LocationPermission.whileInUse) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.high),
        );
        if (mounted) {
          setState(() => _myPos = LatLng(pos.latitude, pos.longitude));
        }
      }
    } catch (_) {/* 정문 fallback */}
  }

  LatLng get _origin => _myPos ?? _kGate;

  /// `_rec` 갱신과 store 동기화를 한 곳에서 — 맵 탭이 자동 반영.
  void _setRec(LunaRecommendation? next) {
    setState(() => _rec = next);
    LunaRecommendationStore.instance.set(next);
  }

  // ── Fetch ────────────────────────────────────────────────
  Future<void> _fetch({required String reason}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    // 데모 시나리오 활성 → RouteService 우회.
    final scenario = _activeScenario;
    if (scenario != null) {
      final origin = _origin;
      await Future<void>.delayed(const Duration(milliseconds: 150));
      if (!mounted) return;
      _setRec(scenario.toRecommendation(
        originLat: origin.latitude,
        originLng: origin.longitude,
      ));
      setState(() => _loading = false);
      return;
    }

    try {
      final origin = _origin;
      final survey = _survey ??
          const SurveyAnswers(members: {}, favoriteType: null, purpose: null);
      final req = RouteRequest(
        uid: 'guest',
        lat: origin.latitude,
        lng: origin.longitude,
        hasGps: _myPos != null,
        onboarding: survey,
        completedIds: const {},
        discoveredEggs: _discoveredEggs,
        requestReason: reason,
      );
      final resp = await RouteService.instance.fetchRoute(req);
      if (!mounted) return;
      final spots = _resolveSpots(resp);
      _setRec(LunaRecommendation(
        spots: spots,
        totalMin: resp.totalMin,
        rationale: resp.rationale,
        lockedAt: DateTime.now(),
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '추천을 불러오지 못했어요');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _selectScenario(DemoScenario? s) {
    HapticFeedback.selectionClick();
    setState(() {
      _activeScenario = s;
      _consecutiveSkips = 0;
      _skipBlocked = false;
    });
    _setRec(null); // store 도 비움 → 맵 폴리라인 즉시 사라짐 + 새 데이터 기다림
    _fetch(reason: s == null ? 'scenario_cleared' : 'scenario_selected');
  }

  List<Attraction> _resolveSpots(RouteResponse resp) {
    final byId = {for (final a in kAttractions) a.id: a};
    return resp.route.map((s) => byId[s.id]).whereType<Attraction>().toList();
  }

  // ── 인터랙션 ──────────────────────────────────────────────
  Future<void> _onManualRefresh() async {
    HapticFeedback.selectionClick();
    _consecutiveSkips = 0;
    _skipBlocked = false;
    await _fetch(reason: 'manual_refresh');
  }

  Future<void> _onSkip() async {
    final rec = _rec;
    if (rec == null) return;
    HapticFeedback.lightImpact();

    // 모든 skip 을 카운트. 임계 도달 시 강제 빈 상태 → "조건 변경" CTA 노출.
    _consecutiveSkips += 1;
    if (_consecutiveSkips >= _kMaxConsecutiveSkips) {
      setState(() => _skipBlocked = true);
      _setRec(rec.copyWith(spots: const []));
      return;
    }

    final next = rec.skipFirst();
    _setRec(next);

    // 풀 소진 → 자동 fetch (윈도우 reset, 새 lockedAt).
    if (next.isEmpty) {
      await _fetch(reason: 'after_skip');
    }
  }

  void _openCompanionSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CompanionBottomSheet(
        initialCompanion: _companion,
        initialStyle: _style,
        onConfirm: (c, s) {
          setState(() {
            _companion = c;
            _style = s;
            _consecutiveSkips = 0;
            _skipBlocked = false;
          });
          _fetch(reason: 'profile_changed');
        },
      ),
    );
  }

  void _onNavigate(Attraction target) {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MyLunaNavigateScreen(target: target),
      ),
    );
  }

  // ── 거리·도보 ─────────────────────────────────────────────
  static double _haversineMeters(LatLng a, LatLng b) {
    const r = 6371000.0;
    final p1 = a.latitude * math.pi / 180;
    final p2 = b.latitude * math.pi / 180;
    final dp = (b.latitude - a.latitude) * math.pi / 180;
    final dl = (b.longitude - a.longitude) * math.pi / 180;
    final h = math.sin(dp / 2) * math.sin(dp / 2) +
        math.cos(p1) * math.cos(p2) * math.sin(dl / 2) * math.sin(dl / 2);
    return 2 * r * math.atan2(math.sqrt(h), math.sqrt(1 - h));
  }

  int _walkMinutesTo(Attraction a) {
    final m = _haversineMeters(_origin, a.position);
    return (m / _kWalkSpeedMpm).ceil();
  }

  int _arrivalWaitMinutes(Attraction a) {
    // TODO: XGBoost 도착 시점 혼잡도 예측 응답 사용 — 현재는 정적 waitMinutes.
    return a.waitMinutes;
  }

  String? get _surveyLabel {
    final s = _survey;
    if (s == null || s.total == 0) return null;
    final parts = <String>['${s.total}명'];
    if (s.purpose != null) parts.add(s.purpose!);
    if (s.favoriteType != null) parts.add(s.favoriteType!);
    return parts.join(' · ');
  }

  int get _missingEggCount {
    final allEggs = kAttractions.where((a) => a.hasEasterEgg).map((a) => a.id);
    return allEggs.where((id) => !_discoveredEggs.contains(id)).length;
  }

  // ── Build ────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: SafeArea(
        child: _loading && _rec == null
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _onManualRefresh,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    // 백엔드 연동 전 — 사용자가 미리 보는 샘플 코스.
                    if (!_demoDismissed) ...[
                      _DemoScenarioPicker(
                        active: _activeScenario,
                        onSelect: _selectScenario,
                        onDismiss: _dismissDemo,
                      ),
                      const SizedBox(height: 12),
                    ],
                    _MetaHeader(
                      surveyLabel: _surveyLabel,
                      missingEggs: _missingEggCount,
                      totalMin: _rec?.totalMin,
                      onChangeConditions: _openCompanionSheet,
                    ),
                    const SizedBox(height: 12),
                    if (_error != null)
                      _ErrorBlock(message: _error!, onRetry: _onManualRefresh)
                    else if (_skipBlocked)
                      _SkipBlockedEmptyState(
                          onChangeConditions: _openCompanionSheet)
                    else if (_rec == null || _rec!.isEmpty)
                      _LoadingHero(loading: _loading)
                    else ...[
                      _HeroNextCard(
                        spot: _rec!.spots.first,
                        walkMin: _walkMinutesTo(_rec!.spots.first),
                        waitMin: _arrivalWaitMinutes(_rec!.spots.first),
                        onNavigate: () => _onNavigate(_rec!.spots.first),
                        onSkip: _onSkip,
                      ),
                      const SizedBox(height: 12),
                      if (_rec!.windowExpired())
                        _RefreshInlineButton(onTap: _onManualRefresh)
                      else
                        _WindowFooter(remaining: _rec!.remainingWindow()),
                      const SizedBox(height: 18),
                      if (_rec!.spots.length > 1) ...[
                        _SectionTitle(
                          _activeScenario != null
                              ? '코스 (총 ${_rec!.spots.length}곳)'
                              : '다음 후보',
                        ),
                        const SizedBox(height: 8),
                        // 데모 시나리오 = 전체 노출, 기본 = 2개 미리보기.
                        ..._rec!.spots
                            .skip(1)
                            .take(_activeScenario != null
                                ? _rec!.spots.length
                                : 2)
                            .toList()
                            .asMap()
                            .entries
                            .map(
                              (e) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _NextItemRow(
                                  order: e.key + 2,
                                  showOrder: _activeScenario != null,
                                  spot: e.value,
                                  walkMin: _walkMinutesTo(e.value),
                                  waitMin: _arrivalWaitMinutes(e.value),
                                  onTap: () => _onNavigate(e.value),
                                ),
                              ),
                            ),
                      ],
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 위젯 컴포넌트
// ─────────────────────────────────────────────────────────────

class _MetaHeader extends StatelessWidget {
  final String? surveyLabel;
  final int missingEggs;
  final int? totalMin;
  final VoidCallback onChangeConditions;
  const _MetaHeader({
    required this.surveyLabel,
    required this.missingEggs,
    required this.totalMin,
    required this.onChangeConditions,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                child: const MoonMark(
                    size: 16, color: AppColors.blue, filled: true),
              ),
              const SizedBox(width: 8),
              const Text(
                '마이 루나',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppColors.ink900,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.blueTint,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('LIVE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.blue,
                      letterSpacing: 0.6,
                    )),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: onChangeConditions,
                icon: const Icon(Icons.tune, size: 14),
                label: const Text('조건'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  side: const BorderSide(color: AppColors.line),
                  foregroundColor: AppColors.textSecondary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(99)),
                  textStyle: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          if (surveyLabel != null) ...[
            const SizedBox(height: 6),
            Text(
              [
                surveyLabel!,
                if (missingEggs > 0) '못 찾은 에그 $missingEggs',
                if (totalMin != null) '총 $totalMin분',
              ].join(' · '),
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.ink500,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeroNextCard extends StatelessWidget {
  final Attraction spot;
  final int walkMin;
  final int waitMin;
  final VoidCallback onNavigate;
  final VoidCallback onSkip;
  const _HeroNextCard({
    required this.spot,
    required this.walkMin,
    required this.waitMin,
    required this.onNavigate,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final totalMin = walkMin + waitMin;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 검정 STOP 헤더
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              color: AppColors.ink900,
              child: Row(
                children: [
                  const Text(
                    'STOP 01 OF 04',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '다음 추천',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Stamp(
                        code: Stamp.codeFromName(spot.name),
                        tone: Stamp.toneFromHints(
                          category: spot.category,
                          thrillLevel: spot.thrillLevel,
                          hasEasterEgg: spot.hasEasterEgg,
                        ),
                        size: 56,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              spot.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: AppColors.ink900,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${spot.category} · ${spot.zone}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.ink500,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  // dashed divider
                  CustomPaint(
                    size: const Size(double.infinity, 1),
                    painter: _DashedRulePainter(color: AppColors.line),
                  ),
                  const SizedBox(height: 14),
                  // 도보 · 대기 · 총 3분할
                  Row(
                    children: [
                      _StatCell(label: '도보', value: '$walkMin분'),
                      _StatDivider(),
                      _StatCell(label: '대기', value: '$waitMin분'),
                      _StatDivider(),
                      _StatCell(
                        label: '총',
                        value: '$totalMin분',
                        accent: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  CustomPaint(
                    size: const Size(double.infinity, 1),
                    painter: _DashedRulePainter(color: AppColors.line),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: onNavigate,
                            icon: const Icon(Icons.directions_walk_rounded,
                                size: 18),
                            label: const Text('길 안내 시작'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.red,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(99)),
                              textStyle: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: onSkip,
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          width: 50,
                          height: 50,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.line),
                          ),
                          child: const Icon(Icons.skip_next_rounded,
                              size: 20, color: AppColors.ink700),
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
    );
  }
}

class _DashedRulePainter extends CustomPainter {
  final Color color;
  _DashedRulePainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const dash = 4.0, gap = 4.0;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + dash, 0), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_DashedRulePainter o) => o.color != color;
}

class _StatCell extends StatelessWidget {
  final String label;
  final String value;
  final bool accent;
  const _StatCell({
    required this.label,
    required this.value,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.ink500,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: accent ? 22 : 18,
              fontWeight: FontWeight.w900,
              color: accent ? AppColors.red : AppColors.ink900,
              letterSpacing: -0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 28,
      color: AppColors.line,
    );
  }
}

class _NextItemRow extends StatelessWidget {
  final Attraction spot;
  final int walkMin;
  final int waitMin;
  final int order;
  final bool showOrder;
  final VoidCallback onTap;
  const _NextItemRow({
    required this.spot,
    required this.walkMin,
    required this.waitMin,
    required this.order,
    required this.showOrder,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bgCard,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              if (showOrder) ...[
                SizedBox(
                  width: 22,
                  child: Text(
                    order.toString().padLeft(2, '0'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.ink400,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Stamp(
                code: Stamp.codeFromName(spot.name),
                tone: Stamp.toneFromHints(
                  category: spot.category,
                  thrillLevel: spot.thrillLevel,
                  hasEasterEgg: spot.hasEasterEgg,
                ),
                size: 38,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(spot.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              )),
                        ),
                        if (spot.hasEasterEgg)
                          const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Text('🥚',
                                style: TextStyle(fontSize: 11)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '🚶 $walkMin분 · ⏱ $waitMin분 · 총 ${walkMin + waitMin}분',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: AppColors.textSecondary,
            letterSpacing: 0.6,
          )),
    );
  }
}

class _RefreshInlineButton extends StatelessWidget {
  final VoidCallback onTap;
  const _RefreshInlineButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton.icon(
        onPressed: onTap,
        icon: const Text('💫', style: TextStyle(fontSize: 14)),
        label: const Text('새 추천 보기'),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.ink900,
          textStyle:
              const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _WindowFooter extends StatelessWidget {
  final Duration remaining;
  const _WindowFooter({required this.remaining});

  @override
  Widget build(BuildContext context) {
    final m = remaining.inMinutes;
    final s = remaining.inSeconds % 60;
    final label = m > 0 ? '$m분 ${s.toString().padLeft(2, '0')}초' : '$s초';
    return Center(
      child: Text(
        '🔒 이 추천은 $label 동안 그대로 유지돼요',
        style: const TextStyle(
          fontSize: 11,
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _LoadingHero extends StatelessWidget {
  final bool loading;
  const _LoadingHero({required this.loading});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: loading
            ? const CircularProgressIndicator()
            : const Text('추천을 불러오는 중…',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      ),
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorBlock({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(message,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              )),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('다시 시도')),
        ],
      ),
    );
  }
}

class _DemoScenarioPicker extends StatelessWidget {
  final DemoScenario? active;
  final ValueChanged<DemoScenario?> onSelect;
  final VoidCallback onDismiss;
  const _DemoScenarioPicker({
    required this.active,
    required this.onSelect,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 14),
      decoration: BoxDecoration(
        color: AppColors.bgCardWarm,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.ink900.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('🌙', style: TextStyle(fontSize: 14)),
                        const SizedBox(width: 6),
                        const Text(
                          '샘플 코스 미리 보기',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Padding(
                      padding: EdgeInsets.only(left: 20),
                      child: Text(
                        '결제하면 맞춤 코스가 시작돼요',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onDismiss,
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          if (active != null)
            Padding(
              padding: const EdgeInsets.only(left: 20, top: 4, right: 6),
              child: GestureDetector(
                onTap: () => onSelect(null),
                child: const Text(
                  '샘플 그만 보기',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.ink900,
                    fontWeight: FontWeight.w800,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 10),
          SizedBox(
            height: 70,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: DemoScenario.values.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final s = DemoScenario.values[i];
                final isActive = active == s;
                return GestureDetector(
                  onTap: () => onSelect(s),
                  child: Container(
                    width: 168,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppColors.ink900
                          : AppColors.bgCard,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isActive
                            ? AppColors.ink900
                            : AppColors.line,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Text(s.emoji,
                                style: const TextStyle(fontSize: 14)),
                            const SizedBox(width: 4),
                            Text(s.title,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: isActive
                                      ? AppColors.textOnDark
                                      : AppColors.textPrimary,
                                )),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(s.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isActive
                                  ? AppColors.textOnDark.withValues(alpha: 0.85)
                                  : AppColors.textSecondary,
                            )),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SkipBlockedEmptyState extends StatelessWidget {
  final VoidCallback onChangeConditions;
  const _SkipBlockedEmptyState({required this.onChangeConditions});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 28),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Text('🌙',
              style: TextStyle(fontSize: 36)),
          const SizedBox(height: 12),
          const Text('조건을 바꿔보시겠어요?',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              )),
          const SizedBox(height: 6),
          const Text(
            '여러 번 건너뛰셨네요. 다른 조건으로 새 추천을 받아보세요.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: onChangeConditions,
            icon: const Icon(Icons.tune, size: 16),
            label: const Text('조건 변경'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              textStyle: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}
