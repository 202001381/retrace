import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../models/attraction.dart';
import '../models/place_filter.dart';
import '../models/route_response.dart';
import '../services/easter_egg_service.dart';
import '../services/luna_recommendation_store.dart';
import '../services/onboarding_service.dart';
import '../services/route_service.dart';
import '../widgets/attraction_detail_sheet.dart';

class MapScreen extends StatefulWidget {
  final bool showMyLunaInitially;
  const MapScreen({super.key, this.showMyLunaInitially = false});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  // ── 지도 상수 ──────────────────────────────────────────────
  // 서울랜드 실제 위치 — 경기 과천시 광명로 181 (막계동)
  // rect 127.018,37.432,127.030,37.438 의 중심 부근으로 보정.
  // 서울랜드 실제 좌표 — Naver/Google Maps 확인 (37.434327, 127.020105 근처).
  static const LatLng _seoullandCenter = LatLng(37.4343, 127.0201);
  static const LatLng _kGate = LatLng(37.4332, 127.0174); // 정문 (대공원역 진입)

  // GPS 잡혀있으면 현재 위치, 아니면 정문을 출발점으로 사용.
  LatLng get _currentOrigin => _myPosition ?? _kGate;

  // ── 컨트롤 / 상태 ──────────────────────────────────────────
  final MapController _mapController = MapController();
  StreamSubscription<Position>? _positionStream;
  LatLng? _myPosition;

  bool _gpsLoading = false;
  bool _showRoute = false;

  // 장소 리스트 화면의 단일 필터 — 카테고리(단일 선택) + 운영중/내 이스터에그(토글).
  PlaceFilterState _filter = PlaceFilterState.empty;
  // 사용자가 수집한 이스터에그 어트랙션 id (영속화) — "내 이스터에그" 토글의 모집단.
  Set<String> _discoveredEggs = const {};

  // 상단 검색바 — 이름 부분 일치, 대소문자 무시.
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  Attraction? _selectedAttraction;
  Attraction? _navTarget;
  int? _navWalkMin;
  bool _navInProgress = false;

  // 동선 추천 상태
  RouteResponse? _currentRoute;
  bool _routeLoading = false;
  SurveyAnswers? _onboardingAnswers;
  LatLng? _lastRouteOrigin; // 100m 이상 이동 시 재요청용

  final DraggableScrollableController _sheetController = DraggableScrollableController();
  double _sheetSize = 0.08;
  static const double _kSheetMini = 0.08;
  static const double _kSheetMid = 0.50;
  static const double _kSheetMax = 0.92;

  @override
  void initState() {
    super.initState();
    // 마이 루나에 활성 추천이 있으면 진입 시 자동 ON.
    _showRoute = widget.showMyLunaInitially ||
        (LunaRecommendationStore.instance.current?.spots.isNotEmpty ?? false);
    _sheetController.addListener(_onSheetChanged);
    LunaRecommendationStore.instance.notifier.addListener(_onLunaStoreChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        _mapController.move(_seoullandCenter, 17.0);
      } catch (_) {}
    });
    _loadRoute('initial');
    _loadDiscoveredEggs();
  }

  void _onLunaStoreChanged() {
    if (!mounted) return;
    final hasRoute =
        LunaRecommendationStore.instance.current?.spots.isNotEmpty ?? false;
    setState(() {
      // MyLuna 가 새 추천을 push 했고 사용자가 동선을 꺼둔 상태라면 자동 ON.
      // (사용자가 명시적으로 끈 상태도 덮어쓰긴 하지만, 데모 의도 우선.)
      if (hasRoute) _showRoute = true;
    });
  }

  Future<void> _loadDiscoveredEggs() async {
    final ids = await EasterEggService.discoveredAll();
    if (!mounted) return;
    setState(() => _discoveredEggs = ids);
  }

  Future<void> _loadRoute(String reason) async {
    if (_routeLoading) return;
    setState(() => _routeLoading = true);
    try {
      _onboardingAnswers ??= await OnboardingService.read();
      final origin = _myPosition ?? _kGate;
      final survey = _onboardingAnswers ??
          const SurveyAnswers(members: {}, favoriteType: null, purpose: null);
      final req = RouteRequest(
        uid: 'guest',
        lat: origin.latitude,
        lng: origin.longitude,
        hasGps: _myPosition != null,
        onboarding: survey,
        completedIds: const {},
        discoveredEggs: const {},
        requestReason: reason,
      );
      final resp = await RouteService.instance.fetchRoute(req);
      if (!mounted) return;
      setState(() {
        _currentRoute = resp;
        _lastRouteOrigin = origin;
      });
    } catch (_) {
      // 실패 시 마지막 캐시 유지 (이미 _currentRoute 에 들어있음)
    } finally {
      if (mounted) setState(() => _routeLoading = false);
    }
  }

  void _onSheetChanged() {
    if (!_sheetController.isAttached) return;
    final s = _sheetController.size;
    if ((s - _sheetSize).abs() > 0.005) {
      setState(() => _sheetSize = s);
    }
  }

  void _shrinkSheet() {
    if (_sheetController.isAttached && _sheetController.size > _kSheetMini + 0.05) {
      _sheetController.animateTo(_kSheetMini,
          duration: const Duration(milliseconds: 240), curve: Curves.easeOutCubic);
    }
  }

  void _expandSheet([double size = _kSheetMid]) {
    if (_sheetController.isAttached) {
      _sheetController.animateTo(size,
          duration: const Duration(milliseconds: 240), curve: Curves.easeOutCubic);
    }
  }

  @override
  void didUpdateWidget(covariant MapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showMyLunaInitially && !oldWidget.showMyLunaInitially) {
      setState(() => _showRoute = true);
    }
  }

  @override
  void dispose() {
    _sheetController.removeListener(_onSheetChanged);
    _sheetController.dispose();
    LunaRecommendationStore.instance.notifier
        .removeListener(_onLunaStoreChanged);
    _positionStream?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── GPS ──────────────────────────────────────────────────
  Future<void> _moveToGps() async {
    setState(() => _gpsLoading = true);
    await Future.delayed(const Duration(milliseconds: 500));
    LatLng target = _kGate;
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.always || perm == LocationPermission.whileInUse) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
        );
        target = LatLng(pos.latitude, pos.longitude);
        setState(() => _myPosition = target);
        _startPositionStream();
      }
    } catch (_) {}
    _mapController.move(target, 17.0);
    if (mounted) setState(() => _gpsLoading = false);

    // 100m 이상 이동했으면 동선 재요청
    if (_lastRouteOrigin == null ||
        _haversineMeters(_lastRouteOrigin!, target) >= 100) {
      _loadRoute('gps_moved');
    }
  }

  /// 권한 확보 후 1회만 구독 시작. 5m 이상 이동 시 콜백.
  void _startPositionStream() {
    if (_positionStream != null) return;
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((pos) {
      if (!mounted) return;
      final next = LatLng(pos.latitude, pos.longitude);
      setState(() => _myPosition = next);
      // 100m 이상 이동했으면 동선 재요청 — 폭주 방지.
      if (_lastRouteOrigin == null ||
          _haversineMeters(_lastRouteOrigin!, next) >= 100) {
        _loadRoute('gps_moved');
      }
      // 내비 중이면 도보 분 갱신.
      if (_navTarget != null) {
        final dist = _haversineMeters(next, _navTarget!.position);
        setState(() => _navWalkMin = (dist / 66.67).ceil());
      }
    }, onError: (_) {});
  }

  // ── 동선 / 필터 ──────────────────────────────────────────
  void _toggleRoute() {
    setState(() => _showRoute = !_showRoute);
    if (_showRoute) _shrinkSheet();
  }

  Color _categoryColor(String c) {
    switch (c) {
      case '어트랙션':
        return const Color(0xFFE60012);
      case '음식점':
        return const Color(0xFFFF6B00);
      case '카페':
        return const Color(0xFF6F4E37);
      case '포토스팟':
        return const Color(0xFF6B21A8);
      default:
        return const Color(0xFF888888);
    }
  }

  bool _matchesSearch(Attraction a) {
    if (_searchQuery.isEmpty) return true;
    return a.name.toLowerCase().contains(_searchQuery.toLowerCase());
  }

  /// 마커·시트 카드 양쪽에서 사용하는 단일 표시 리스트.
  List<Attraction> get _visibleAttractions {
    return _filter
        .apply(kAttractions, _discoveredEggs)
        .where(_matchesSearch)
        .toList();
  }

  /// 마이 루나 동선 — store 가 우선, 비어있으면 자체 fetch 결과로 fallback.
  /// store 는 MyLunaScreen 이 관리(데모 시나리오 선택 시 즉시 반영).
  List<Attraction> get _routeAttractions {
    final stored = LunaRecommendationStore.instance.current;
    if (stored != null && stored.spots.isNotEmpty) {
      return stored.spots;
    }
    final resp = _currentRoute;
    if (resp == null) return const [];
    final byId = {for (final a in kAttractions) a.id: a};
    return resp.route
        .map((s) => byId[s.id])
        .whereType<Attraction>()
        .toList();
  }

  /// 동선 메타(총 분·rationale) 도 store 우선.
  ({int? totalMin, String? rationale}) get _routeMeta {
    final stored = LunaRecommendationStore.instance.current;
    if (stored != null && stored.spots.isNotEmpty) {
      return (totalMin: stored.totalMin, rationale: stored.rationale);
    }
    final r = _currentRoute;
    if (r == null) return (totalMin: null, rationale: null);
    return (totalMin: r.totalMin, rationale: r.rationale);
  }

  String get _routeSummaryText {
    final names = _routeAttractions.map((a) => a.name).join(' → ');
    if (names.isEmpty) return '🗺️ 동선 준비 중…';
    return '🗺️ $names';
  }

  /// 시트 카드 리스트가 빈 경우의 분기 — "내 이스터에그" 0건이 최우선.
  Widget _buildEmptyState() {
    if (_filter.onlyMyEasterEggs && _discoveredEggs.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        child: Column(
          children: [
            Text('아직 수집한 이스터에그가 없어요',
                style: TextStyle(
                  color: Color(0xFF1F1F1F),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                )),
            SizedBox(height: 6),
            Text('지도에서 ✨ 표시된 곳을 방문해보세요',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF888888),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                )),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      child: Column(
        children: [
          const Text('조건에 맞는 장소가 없어요',
              style: TextStyle(
                color: Color(0xFF1F1F1F),
                fontSize: 14,
                fontWeight: FontWeight.w800,
              )),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () =>
                setState(() => _filter = PlaceFilterState.empty),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1E3158),
              side: const BorderSide(color: Color(0xFFDDDDDD)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text('필터 초기화',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                )),
          ),
        ],
      ),
    );
  }

  // ── 인터랙션 ─────────────────────────────────────────────
  void _openDetail(Attraction a) {
    setState(() => _selectedAttraction = a);
    _shrinkSheet();
    _mapController.move(a.position, 17.5);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AttractionDetailSheet(
        attraction: a,
        onNavigate: () => _startNavigation(a),
        isNavigating: _navInProgress && _navTarget?.id == a.id,
        walkMinutes: _navTarget?.id == a.id ? _navWalkMin : null,
      ),
    ).then((_) {
      if (mounted) setState(() => _selectedAttraction = null);
    });
  }

  void _startNavigation(Attraction target) {
    final origin = _currentOrigin;
    final dist = _haversineMeters(origin, target.position);
    final walkMin = (dist / 66.67).ceil(); // 4 km/h ≈ 66.67 m/min
    setState(() {
      _navTarget = target;
      _navWalkMin = walkMin;
      _navInProgress = true;
    });
    Navigator.of(context).maybePop();
    Future.delayed(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      final mid = LatLng(
        (origin.latitude + target.position.latitude) / 2,
        (origin.longitude + target.position.longitude) / 2,
      );
      _mapController.move(mid, 17);
    });
  }

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

  // ── 마커 ─────────────────────────────────────────────────
  // 기본은 단순 1-원 마커. 동선 ON 일 때 해당 스팟엔 순번 배지 합성.
  List<Marker> _buildMarkers() {
    final routeOrder = <String, int>{};
    if (_showRoute) {
      final spots = _routeAttractions;
      for (var i = 0; i < spots.length; i++) {
        routeOrder[spots[i].id] = i + 1;
      }
    }

    final markers = _visibleAttractions.map((a) {
      final order = routeOrder[a.id];
      final hasBadge = order != null;
      final dot = Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: _getMarkerColor(a.category),
          shape: BoxShape.circle,
          border: Border.all(
            color: a.hasEasterEgg ? const Color(0xFFF4B633) : Colors.white,
            width: a.hasEasterEgg ? 3 : 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(child: Text(a.icon, style: const TextStyle(fontSize: 20))),
      );

      return Marker(
        point: LatLng(a.lat, a.lng),
        width: hasBadge ? 52 : 44,
        height: hasBadge ? 52 : 44,
        child: GestureDetector(
          onTap: () => _onMarkerTap(a),
          child: Opacity(
            opacity: a.isOperating ? 1.0 : 0.4,
            child: hasBadge
                ? Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      dot,
                      Positioned(
                        top: -2,
                        right: -2,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E3158),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '$order',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : dot,
          ),
        ),
      );
    }).toList();

    if (_myPosition != null) {
      markers.add(Marker(
        point: _myPosition!,
        width: 24, height: 24,
        child: Center(
          child: Container(
            width: 18, height: 18,
            decoration: BoxDecoration(color: const Color(0xFF4A90E2).withValues(alpha: 0.25), shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Container(
              width: 12, height: 12,
              decoration: BoxDecoration(
                color: const Color(0xFF4A90E2),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
        ),
      ));
    } else if (_showRoute || _navTarget != null) {
      // GPS 가 없으면 동선/내비 출발점인 정문을 보여준다.
      markers.add(Marker(
        point: _kGate,
        width: 32, height: 32,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF1E3158), width: 2),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4, offset: const Offset(0, 1)),
            ],
          ),
          alignment: Alignment.center,
          child: const Text('🚪', style: TextStyle(fontSize: 16)),
        ),
      ));
    }
    return markers;
  }

  // ── 동선 폴리라인 ─────────────────────────────────────────
  List<Polyline> _buildRoute() {
    if (!_showRoute) return const [];
    final spots = _routeAttractions;
    if (spots.isEmpty) return const [];
    // 출발점(현재 GPS or 정문)에서 첫 스팟까지 잇는 선을 포함.
    final points = <LatLng>[
      _currentOrigin,
      ...spots.map((a) => LatLng(a.lat, a.lng)),
    ];
    return [
      Polyline(
        points: points,
        strokeWidth: 3.0,
        color: const Color(0xFFE60012),
        pattern: StrokePattern.dashed(segments: const [10, 5]),
      ),
    ];
  }

  Color _getMarkerColor(String category) {
    switch (category) {
      case '어트랙션': return const Color(0xFFE60012);
      case '음식점':   return const Color(0xFFFF6B00);
      case '카페':     return const Color(0xFF6F4E37);
      case '포토스팟': return const Color(0xFF6B21A8);
      default:         return const Color(0xFF888888);
    }
  }

  void _onMarkerTap(Attraction a) => _openDetail(a);

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF7F7F7),
      child: Stack(
        children: [
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _seoullandCenter,
                initialZoom: 17.0,
                minZoom: 15.0,
                maxZoom: 19.0,
                onTap: (tapPosition, point) {
                  // 지도 탭 시 패널 미니로
                  _sheetController.animateTo(
                    0.08,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  );
                },
              ),
              children: [
                TileLayer(
                  // VWorld (한국 국토교통부) 정밀 지도 타일. 한국 내부 사설 시설
                  // 윤곽까지 잡아주므로 OSM 의 회색 영역 문제 해소.
                  // 키는 --dart-define=VWORLD_KEY=... 로 주입. 빌드시 미지정이면
                  // 기존 키로 폴백 (정식 출시 전 키 회전 + 도메인 제한 필요).
                  urlTemplate:
                      'https://api.vworld.kr/req/wmts/1.0.0/{apiKey}/Base/{z}/{y}/{x}.png',
                  additionalOptions: const {
                    'apiKey': String.fromEnvironment(
                      'VWORLD_KEY',
                      defaultValue: '9783E3A8-A564-37C0-A9DC-42D67CAA8112',
                    ),
                  },
                  userAgentPackageName: 'com.seoulland.app',
                ),
                MarkerLayer(markers: _buildMarkers()),
                if (_showRoute) PolylineLayer(polylines: _buildRoute()),
                if (_navTarget != null)
                  PolylineLayer(polylines: [
                    Polyline(
                      points: [_currentOrigin, _navTarget!.position],
                      color: const Color(0xFFE60012),
                      strokeWidth: 4.5,
                    ),
                  ]),
              ],
            ),
          ),
          _TopBar(
            routeOn: _showRoute,
            gpsLoading: _gpsLoading,
            searchController: _searchCtrl,
            onSearchChanged: (q) => setState(() => _searchQuery = q),
            onToggleRoute: _toggleRoute,
            onGps: _moveToGps,
          ),
          if (_showRoute || _navTarget != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 80,
              left: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_showRoute)
                    _StatusBadge(color: const Color(0xFFE60012), text: '마이 루나 동선'),
                  if (_showRoute && _navTarget != null) const SizedBox(height: 8),
                  if (_navTarget != null)
                    _StatusBadge(
                      color: const Color(0xFFE60012),
                      text: '➜ ${_navTarget!.name} (도보 ${_navWalkMin ?? 0}분)',
                      onClose: () => setState(() {
                        _navTarget = null;
                        _navWalkMin = null;
                        _navInProgress = false;
                      }),
                    ),
                ],
              ),
            ),
          // ── 하단 시트 ──────────────────────────────────────
          DraggableScrollableSheet(
            controller: _sheetController,
            initialChildSize: _kSheetMini,
            minChildSize: _kSheetMini,
            maxChildSize: _kSheetMax,
            snap: true,
            snapSizes: const [_kSheetMini, _kSheetMid, _kSheetMax],
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black12)],
                ),
                child: Column(
                  children: [
                    // 핸들 (탭하면 mid 로 확장)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _sheetSize < 0.20 ? _expandSheet() : _shrinkSheet(),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Center(
                          child: Container(
                            width: 40, height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        physics: const ClampingScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(
                          0, 0, 0,
                          16 + MediaQuery.of(context).padding.bottom,
                        ),
                        children: [
                          // 동선 요약 (ON 일 때만)
                          if (_showRoute)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _routeSummaryText,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF1E2B4A),
                                          ),
                                        ),
                                      ),
                                      if (_routeLoading)
                                        const Padding(
                                          padding: EdgeInsets.only(right: 6),
                                          child: SizedBox(
                                            width: 12, height: 12,
                                            child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF1E2B4A)),
                                          ),
                                        ),
                                      GestureDetector(
                                        onTap: () => _loadRoute('manual_refresh'),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFE60012),
                                            borderRadius: BorderRadius.circular(99),
                                          ),
                                          child: const Text('다시 추천',
                                              style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (_routeMeta.totalMin != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      '총 ${_routeMeta.totalMin}분 · ${_routeMeta.rationale ?? ''}',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF888888)),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          // 헤더 — 필터 활성 시 "전체" 단어 제거, 결과 N곳.
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                            child: Row(
                              children: [
                                Text(
                                  _filter.isAnyActive
                                      ? '결과 ${_visibleAttractions.length}곳'
                                      : '전체 ${_visibleAttractions.length}곳',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF1F1F1F),
                                  ),
                                ),
                                const Spacer(),
                                _PulseDot(),
                                const SizedBox(width: 4),
                                const Text('실시간 연동 중',
                                    style: TextStyle(fontSize: 11, color: Color(0xFFE60012), fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          const Divider(height: 1, color: Color(0xFFEEEEEE)),
                          // 카테고리 칩 — 둥근 pill, 단일 선택. "전체" 포함 5개.
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                            child: SizedBox(
                              height: 32,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: PlaceCategory.values.length + 1,
                                separatorBuilder: (_, __) => const SizedBox(width: 6),
                                itemBuilder: (_, i) {
                                  final isAll = i == 0;
                                  final cat = isAll ? null : PlaceCategory.values[i - 1];
                                  final label = isAll ? '전체' : cat!.label;
                                  final active = _filter.category == cat;
                                  return GestureDetector(
                                    onTap: () => setState(() {
                                      _filter = isAll
                                          ? _filter.copyWith(clearCategory: true)
                                          : _filter.copyWith(category: cat);
                                    }),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: active ? const Color(0xFF1E3158) : Colors.white,
                                        borderRadius: BorderRadius.circular(99),
                                        border: Border.all(color: active ? const Color(0xFF1E3158) : const Color(0xFFDDDDDD)),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(label,
                                          style: TextStyle(
                                            color: active ? Colors.white : const Color(0xFF1F1F1F),
                                            fontSize: 12, fontWeight: FontWeight.w800,
                                          )),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          // 상태 필터 — 카테고리 칩과 다른 인터랙션 문법(스위치)으로 분리.
                          const SizedBox(height: 12),
                          const Divider(height: 1, color: Color(0xFFEEEEEE)),
                          _FilterToggleRow(
                            label: '운영중만 보기',
                            value: _filter.onlyOperating,
                            onChanged: (v) => setState(
                                () => _filter = _filter.copyWith(onlyOperating: v)),
                          ),
                          const Divider(height: 1, color: Color(0xFFF1F1F1), indent: 20, endIndent: 20),
                          _FilterToggleRow(
                            label: '✨ 내 이스터에그',
                            value: _filter.onlyMyEasterEggs,
                            onChanged: (v) => setState(
                                () => _filter = _filter.copyWith(onlyMyEasterEggs: v)),
                          ),
                          const Divider(height: 1, color: Color(0xFFEEEEEE)),
                          const SizedBox(height: 8),
                          // 카드 리스트 — 이중 빈 상태 분기.
                          if (_visibleAttractions.isEmpty)
                            _buildEmptyState()
                          else
                            ..._visibleAttractions.map((a) => Padding(
                                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                                  child: _AttractionCard(
                                    attraction: a,
                                    catColor: _categoryColor(a.category),
                                    dim: !a.isOperating,
                                    onTap: () => _openDetail(a),
                                  ),
                                )),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─── 상단 바 ───────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final bool routeOn;
  final bool gpsLoading;
  final TextEditingController searchController;
  final void Function(String) onSearchChanged;
  final VoidCallback onToggleRoute;
  final VoidCallback onGps;
  const _TopBar({
    required this.routeOn,
    required this.gpsLoading,
    required this.searchController,
    required this.onSearchChanged,
    required this.onToggleRoute,
    required this.onGps,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: Material(
        color: Colors.white,
        elevation: 2,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(color: const Color(0xFFF7F7F7), borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        const Icon(Icons.search, size: 16, color: Color(0xFF888888)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: searchController,
                            onChanged: onSearchChanged,
                            style: const TextStyle(fontSize: 13, color: Color(0xFF1F1F1F)),
                            decoration: const InputDecoration(
                              isCollapsed: true,
                              border: InputBorder.none,
                              hintText: '어트랙션, 음식점',
                              hintStyle: TextStyle(color: Color(0xFF888888), fontSize: 13),
                            ),
                          ),
                        ),
                        if (searchController.text.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              searchController.clear();
                              onSearchChanged('');
                            },
                            child: const Icon(Icons.close, size: 16, color: Color(0xFF888888)),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _IconLabelButton(
                  label: '🗺️ 동선',
                  active: routeOn,
                  activeColor: const Color(0xFF1E2B4A),
                  onTap: onToggleRoute,
                ),
                const SizedBox(width: 6),
                _IconLabelButton(
                  label: '📍 GPS',
                  active: false,
                  activeColor: const Color(0xFF4CAF50),
                  loading: gpsLoading,
                  onTap: onGps,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IconLabelButton extends StatelessWidget {
  final String label;
  final bool active;
  final Color activeColor;
  final bool loading;
  final VoidCallback onTap;
  const _IconLabelButton({
    required this.label,
    required this.active,
    required this.activeColor,
    this.loading = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: active ? activeColor : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? activeColor : const Color(0xFFDDDDDD)),
        ),
        alignment: Alignment.center,
        child: loading
            ? const SizedBox(
                width: 14, height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1E2B4A)),
              )
            : Text(label,
                style: TextStyle(
                  color: active ? Colors.white : const Color(0xFF1F1F1F),
                  fontSize: 13, fontWeight: FontWeight.w800,
                )),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final Color color;
  final String text;
  final VoidCallback? onClose;
  const _StatusBadge({required this.color, required this.text, this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(99),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
          if (onClose != null) ...[
            const SizedBox(width: 6),
            GestureDetector(onTap: onClose, child: const Icon(Icons.close, size: 14, color: Colors.white)),
          ],
        ],
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.4, end: 1.0).animate(_c),
      child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFE60012), shape: BoxShape.circle)),
    );
  }
}

/// 카테고리 칩(둥근 pill, 단일 선택)과 시각·인터랙션 문법을 분리하기 위한
/// 상태 필터 한 줄. 라벨 + Spacer + Switch.
class _FilterToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _FilterToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 12, 2),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(
                  color: Color(0xFF1F1F1F),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                )),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF1E3158),
          ),
        ],
      ),
    );
  }
}

class _AttractionCard extends StatelessWidget {
  final Attraction attraction;
  final Color catColor;
  final bool dim;
  final VoidCallback onTap;
  const _AttractionCard({
    required this.attraction,
    required this.catColor,
    required this.dim,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: dim ? 0.4 : 1.0,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: attraction.hasEasterEgg ? const Color(0xFFF4B633) : const Color(0xFFEEEEEE),
            ),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: catColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(attraction.icon, style: const TextStyle(fontSize: 22)),
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
                          child: Text(attraction.name,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1F1F1F)),
                              overflow: TextOverflow.ellipsis),
                        ),
                        if (attraction.hasEasterEgg)
                          const Padding(padding: EdgeInsets.only(left: 4), child: Text('🥚', style: TextStyle(fontSize: 12))),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${attraction.category} · ${attraction.zone}${attraction.category == '어트랙션' ? ' · 대기 ${attraction.waitMinutes}분' : ''}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF888888)),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFFCCCCCC), size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
