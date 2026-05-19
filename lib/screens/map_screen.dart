import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../models/attraction.dart';
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

  // ── 컨트롤 / 상태 ──────────────────────────────────────────
  final MapController _mapController = MapController();
  StreamSubscription<Position>? _positionStream;
  LatLng? _myPosition;

  bool _gpsLoading = false;
  bool _showRoute = false;
  String _activeFilter = '전체'; // 전체 / 어트랙션 / 음식점 / 이스터에그
  String _facilityTab = '어트랙션';
  bool _operatingOnly = false;
  bool _easterEggSubFilter = false;

  Attraction? _selectedAttraction;
  Attraction? _navTarget;
  int? _navWalkMin;
  bool _navInProgress = false;

  final DraggableScrollableController _sheetController = DraggableScrollableController();
  double _sheetSize = 0.08;
  static const double _kSheetMini = 0.08;
  static const double _kSheetMid = 0.50;
  static const double _kSheetMax = 0.92;

  @override
  void initState() {
    super.initState();
    _showRoute = widget.showMyLunaInitially;
    _sheetController.addListener(_onSheetChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        _mapController.move(_seoullandCenter, 17.0);
      } catch (_) {}
    });
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
    _positionStream?.cancel();
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
      }
    } catch (_) {}
    _mapController.move(target, 17.0);
    if (mounted) setState(() => _gpsLoading = false);
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
      default:
        return const Color(0xFF6B21A8);
    }
  }

  bool _attractionPassesFilter(Attraction a) {
    switch (_activeFilter) {
      case '어트랙션':
        return a.category == '어트랙션';
      case '음식점':
        return a.category == '음식점';
      case '이스터에그':
        return a.hasEasterEgg;
      default:
        return true;
    }
  }

  List<Attraction> get _filteredAttractions {
    var list = kAttractions.where(_attractionPassesFilter).toList();
    if (_operatingOnly) list = list.where((a) => a.isOperating).toList();
    if (_easterEggSubFilter) list = list.where((a) => a.hasEasterEgg).toList();
    return list;
  }

  /// 패널 카드 리스트 — facility tab 기반, 상단 칩과 독립.
  List<Attraction> get _panelAttractions {
    Iterable<Attraction> list;
    switch (_facilityTab) {
      case '음식점·상점':
        list = kAttractions.where((a) => a.category == '음식점');
        break;
      case '공연':
      case '편의시설':
        list = const Iterable<Attraction>.empty();
        break;
      default: // 어트랙션
        list = kAttractions.where((a) => a.category == '어트랙션');
    }
    if (_operatingOnly) list = list.where((a) => a.isOperating);
    if (_easterEggSubFilter) list = list.where((a) => a.hasEasterEgg);
    return list.toList();
  }

  /// 마이 루나 동선 — 어트랙션 상위 3개.
  List<Attraction> get _routeAttractions =>
      kAttractions.where((a) => a.category == '어트랙션').take(3).toList();

  String get _routeSummaryText =>
      '🗺️ ${_routeAttractions.map((a) => a.name).join(' → ')}';

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
    final dist = _haversineMeters(_kGate, target.position);
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
        (_kGate.latitude + target.position.latitude) / 2,
        (_kGate.longitude + target.position.longitude) / 2,
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
  // 명세에 따라 단순 1-원 마커. 클러스터/순번 배지 제거.
  List<Marker> _buildMarkers() {
    final markers = _filteredAttractions.map((a) {
      return Marker(
        point: LatLng(a.lat, a.lng),
        width: 44,
        height: 44,
        child: GestureDetector(
          onTap: () => _onMarkerTap(a),
          child: Opacity(
            opacity: a.isOperating ? 1.0 : 0.4,
            child: Container(
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
            ),
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
    }
    return markers;
  }

  // ── 동선 폴리라인 ─────────────────────────────────────────
  List<Polyline> _buildRoute() {
    if (!_showRoute) return const [];
    final routeIds = ['galaxy_888', 'flume_ride', 'ferris_wheel'];
    final routeSpots = kAttractions.where((a) => routeIds.contains(a.id)).toList();
    if (routeSpots.length < 2) return const [];
    return [
      Polyline(
        points: routeSpots.map((a) => LatLng(a.lat, a.lng)).toList(),
        strokeWidth: 3.0,
        color: const Color(0xFFE60012),
        pattern: StrokePattern.dashed(segments: const [10, 5]),
      ),
    ];
  }

  Color _getMarkerColor(String category) {
    switch (category) {
      case '어트랙션': return const Color(0xFFE60012);
      case '음식점': return const Color(0xFFFF6B00);
      default: return const Color(0xFF6B21A8);
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
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.seoulland.app',
                ),
                MarkerLayer(markers: _buildMarkers()),
                if (_showRoute) PolylineLayer(polylines: _buildRoute()),
                if (_navTarget != null)
                  PolylineLayer(polylines: [
                    Polyline(
                      points: [_kGate, _navTarget!.position],
                      color: const Color(0xFFE60012),
                      strokeWidth: 4.5,
                    ),
                  ]),
              ],
            ),
          ),
          _TopBar(
            activeFilter: _activeFilter,
            routeOn: _showRoute,
            gpsLoading: _gpsLoading,
            onToggleRoute: _toggleRoute,
            onGps: _moveToGps,
            onFilter: (f) => setState(() => _activeFilter = f),
          ),
          if (_showRoute || _navTarget != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 132,
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
                              child: Row(
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
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE60012),
                                      borderRadius: BorderRadius.circular(99),
                                    ),
                                    child: const Text('동선 ON',
                                        style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
                                  ),
                                ],
                              ),
                            ),
                          // 헤더
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                            child: Row(
                              children: [
                                Text('전체 ${_panelAttractions.length}곳',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF1F1F1F))),
                                const Spacer(),
                                _PulseDot(),
                                const SizedBox(width: 4),
                                const Text('실시간 연동 중',
                                    style: TextStyle(fontSize: 11, color: Color(0xFFE60012), fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          const Divider(height: 1, color: Color(0xFFEEEEEE)),
                          // 카테고리 탭
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                            child: SizedBox(
                              height: 32,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: 4,
                                separatorBuilder: (_, __) => const SizedBox(width: 6),
                                itemBuilder: (_, i) {
                                  final tabs = ['어트랙션', '음식점·상점', '공연', '편의시설'];
                                  final t = tabs[i];
                                  final active = _facilityTab == t;
                                  return GestureDetector(
                                    onTap: () => setState(() => _facilityTab = t),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: active ? const Color(0xFF1E3158) : Colors.white,
                                        borderRadius: BorderRadius.circular(99),
                                        border: Border.all(color: active ? const Color(0xFF1E3158) : const Color(0xFFDDDDDD)),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(t,
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
                          // sub chips
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                            child: Row(
                              children: [
                                _SubChip(
                                  text: '운영중',
                                  active: _operatingOnly,
                                  activeColor: const Color(0xFF4CAF50),
                                  onTap: () => setState(() => _operatingOnly = !_operatingOnly),
                                ),
                                const SizedBox(width: 8),
                                _SubChip(
                                  text: '이스터에그 ✨',
                                  active: _easterEggSubFilter,
                                  activeColor: const Color(0xFFF4B633),
                                  onTap: () => setState(() => _easterEggSubFilter = !_easterEggSubFilter),
                                ),
                              ],
                            ),
                          ),
                          // 카드 리스트
                          if (_panelAttractions.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 40),
                              child: Center(
                                child: Text('해당하는 시설이 없습니다',
                                    style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 13, fontWeight: FontWeight.w600)),
                              ),
                            )
                          else
                            ..._panelAttractions.map((a) => Padding(
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
  final String activeFilter;
  final bool routeOn;
  final bool gpsLoading;
  final VoidCallback onToggleRoute;
  final VoidCallback onGps;
  final void Function(String) onFilter;
  const _TopBar({
    required this.activeFilter,
    required this.routeOn,
    required this.gpsLoading,
    required this.onToggleRoute,
    required this.onGps,
    required this.onFilter,
  });

  static const _filters = ['전체', '어트랙션', '음식점', '이스터에그'];

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: Material(
        color: Colors.white,
        elevation: 2,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(color: const Color(0xFFF7F7F7), borderRadius: BorderRadius.circular(12)),
                        child: const Row(
                          children: [
                            Icon(Icons.search, size: 16, color: Color(0xFF888888)),
                            SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                style: TextStyle(fontSize: 13, color: Color(0xFF1F1F1F)),
                                decoration: InputDecoration(
                                  isCollapsed: true,
                                  border: InputBorder.none,
                                  hintText: '어트랙션, 음식점',
                                  hintStyle: TextStyle(color: Color(0xFF888888), fontSize: 13),
                                ),
                              ),
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
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _filters.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final f = _filters[i];
                      final active = activeFilter == f;
                      return GestureDetector(
                        onTap: () => onFilter(f),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: active ? const Color(0xFFE60012) : Colors.white,
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(color: active ? const Color(0xFFE60012) : const Color(0xFFDDDDDD)),
                          ),
                          alignment: Alignment.center,
                          child: Text(f,
                              style: TextStyle(
                                color: active ? Colors.white : const Color(0xFF1F1F1F),
                                fontSize: 13, fontWeight: FontWeight.w800,
                              )),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
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

class _SubChip extends StatelessWidget {
  final String text;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;
  const _SubChip({required this.text, required this.active, required this.activeColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? activeColor : Colors.white,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: active ? activeColor : const Color(0xFFDDDDDD)),
        ),
        child: Text(text,
            style: TextStyle(
              color: active ? Colors.white : const Color(0xFF1F1F1F),
              fontSize: 12, fontWeight: FontWeight.w800,
            )),
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
