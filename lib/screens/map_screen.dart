import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../models/spot_model.dart';
import '../widgets/spot_detail_sheet.dart';

class MapScreen extends StatefulWidget {
  final bool showMyLunaInitially;
  const MapScreen({super.key, this.showMyLunaInitially = false});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  // ── 지도 상수 ──────────────────────────────────────────────
  static const LatLng _kCenter = LatLng(37.4278, 126.9798);   // 서울랜드 중심
  static const LatLng _kGate = LatLng(37.4270, 126.9785);     // 정문 (GPS fallback / 경로 출발지)
  static const double _kInitialZoom = 17.0;
  static const double _kMinZoom = 15.0;
  static const double _kMaxZoom = 19.0;

  // ── 컨트롤 / 상태 ──────────────────────────────────────────
  final MapController _mapController = MapController();
  StreamSubscription<Position>? _positionStream;
  LatLng? _myPosition;
  double _currentZoom = _kInitialZoom;

  bool _gpsLoading = false;
  bool _showRoute = false;
  String _activeFilter = '전체';     // 전체 / 어트랙션 / 음식점 / 포토존 / 이스터에그
  bool _operatingOnly = false;
  bool _easterEggSubFilter = false;

  // 선택된 스팟 + "여기로 이동하기" 상태
  Spot? _selectedSpot;
  Spot? _navTarget;
  int? _navWalkMin;
  bool _navInProgress = false;

  // mock 발견된 이스터에그 ID (실제로는 shared_preferences 에서 로드)
  static const Set<String> _discoveredEggs = {'a01'};

  @override
  void initState() {
    super.initState();
    _showRoute = widget.showMyLunaInitially;
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
    _positionStream?.cancel();
    super.dispose();
  }

  // ── GPS ───────────────────────────────────────────────────
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
    } catch (_) {
      // macOS desktop / 권한 거부 등 → 정문 fallback
    }
    _mapController.move(target, math.max(_currentZoom, _kInitialZoom));
    if (mounted) setState(() => _gpsLoading = false);
  }

  // ── 동선 토글 ─────────────────────────────────────────────
  void _toggleRoute() {
    setState(() => _showRoute = !_showRoute);
  }

  // ── 카테고리 필터 ─────────────────────────────────────────
  Color _categoryColor(SpotCategory c) {
    switch (c) {
      case SpotCategory.attraction:
        return const Color(0xFFE60012);
      case SpotCategory.food:
        return const Color(0xFFFF6D00);
      case SpotCategory.photo:
        return const Color(0xFF8E24AA);
    }
  }

  String _categoryLabel(SpotCategory c) {
    switch (c) {
      case SpotCategory.attraction:
        return '어트랙션';
      case SpotCategory.food:
        return '음식점';
      case SpotCategory.photo:
        return '포토존';
    }
  }

  bool _spotPassesFilter(Spot s) {
    switch (_activeFilter) {
      case '어트랙션':
        return s.category == SpotCategory.attraction;
      case '음식점':
        return s.category == SpotCategory.food;
      case '포토존':
        return s.category == SpotCategory.photo;
      case '이스터에그':
        return s.hasEasterEgg;
      default:
        return true;
    }
  }

  List<Spot> get _filteredSpots {
    var list = SeoulLandSpots.all.where(_spotPassesFilter).toList();
    if (_operatingOnly) list = list.where((s) => s.isOperating).toList();
    if (_easterEggSubFilter) list = list.where((s) => s.hasEasterEgg).toList();
    return list;
  }

  /// 마이 루나 동선 — 어트랙션 카테고리 상위 3개.
  List<Spot> get _routeSpots =>
      SeoulLandSpots.byCategory(SpotCategory.attraction).take(3).toList();

  // ── 카드 / 마커 인터랙션 ─────────────────────────────────
  void _openSpotDetail(Spot s) {
    setState(() => _selectedSpot = s);
    _mapController.move(s.position, math.max(_currentZoom, 17.5));
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SpotDetailSheet(
        spot: s,
        onNavigate: () => _startNavigation(s),
        isNavigating: _navInProgress && _navTarget?.id == s.id,
        walkMinutes: _navTarget?.id == s.id ? _navWalkMin : null,
      ),
    ).then((_) {
      if (mounted) setState(() => _selectedSpot = null);
    });
  }

  // ── "여기로 이동하기" — 도보 경로 polyline + 시간 ─────
  void _startNavigation(Spot target) {
    final dist = _haversineMeters(_kGate, target.position);
    final walkMin = (dist / 66.67).ceil(); // 도보 4km/h = 66.67 m/min
    setState(() {
      _navTarget = target;
      _navWalkMin = walkMin;
      _navInProgress = true;
    });
    Navigator.of(context).maybePop();
    // 시트 닫은 뒤 polyline 보이도록 카메라 약간 줌아웃
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

  // ── 마커 빌딩 — 줌 따라 클러스터링 ─────────────────────
  List<Marker> _buildMarkers() {
    final spots = _filteredSpots;
    final clustered = _currentZoom < 17.0;
    if (!clustered) {
      return [
        for (final s in spots) _individualMarker(s),
        if (_myPosition != null) _gpsMarker(_myPosition!),
      ];
    }
    // 그리드 클러스터링: 셀 크기를 줌 따라 조정
    final cell = 0.0005 * math.pow(2, 17 - _currentZoom).toDouble();
    final buckets = <String, List<Spot>>{};
    for (final s in spots) {
      final key =
          '${(s.position.latitude / cell).floor()},${(s.position.longitude / cell).floor()}';
      buckets.putIfAbsent(key, () => []).add(s);
    }
    final markers = <Marker>[];
    for (final group in buckets.values) {
      if (group.length == 1) {
        markers.add(_individualMarker(group.first));
      } else {
        markers.add(_clusterMarker(group));
      }
    }
    if (_myPosition != null) markers.add(_gpsMarker(_myPosition!));
    return markers;
  }

  Marker _individualMarker(Spot s) {
    final isRoute = _showRoute && _routeSpots.contains(s);
    final order = isRoute ? _routeSpots.indexOf(s) + 1 : 0;
    final color = _categoryColor(s.category);

    // 이스터에그 필터일 때 발견/미발견 시각 차이
    double opacity = 1.0;
    if (_activeFilter == '이스터에그' && !_discoveredEggs.contains(s.id)) {
      opacity = 0.4;
    }
    if (_operatingOnly && !s.isOperating) opacity = 0.4;
    if (!_operatingOnly && !s.isOperating) opacity = 0.4;

    return Marker(
      point: s.position,
      width: 44,
      height: 44,
      alignment: Alignment.topCenter,
      child: Opacity(
        opacity: opacity,
        child: GestureDetector(
          onTap: () => _openSpotDetail(s),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: s.hasEasterEgg ? const Color(0xFFF4B633) : Colors.white,
                    width: s.hasEasterEgg ? 3 : 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(s.icon, style: const TextStyle(fontSize: 18)),
              ),
              if (s.hasEasterEgg)
                const Positioned(top: -4, right: -4, child: Text('🥚', style: TextStyle(fontSize: 14))),
              if (isRoute)
                Positioned(
                  top: -6, left: -6,
                  child: Container(
                    width: 20, height: 20,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE60012),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Text('$order',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Marker _clusterMarker(List<Spot> group) {
    // 클러스터의 평균 좌표
    double lat = 0, lng = 0;
    for (final s in group) {
      lat += s.position.latitude;
      lng += s.position.longitude;
    }
    lat /= group.length;
    lng /= group.length;

    // 대표 색상 — 가장 많은 카테고리
    final counts = <SpotCategory, int>{};
    for (final s in group) {
      counts[s.category] = (counts[s.category] ?? 0) + 1;
    }
    final dominant = counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    final color = _categoryColor(dominant);

    return Marker(
      point: LatLng(lat, lng),
      width: 48, height: 48,
      child: GestureDetector(
        onTap: () => _mapController.move(LatLng(lat, lng), 17.5),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          alignment: Alignment.center,
          child: Text(
            '${group.length}',
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
          ),
        ),
      ),
    );
  }

  Marker _gpsMarker(LatLng p) {
    return Marker(
      point: p,
      width: 24,
      height: 24,
      child: Center(
        child: Container(
          width: 18, height: 18,
          decoration: BoxDecoration(
            color: const Color(0xFF4A90E2).withValues(alpha: 0.25),
            shape: BoxShape.circle,
          ),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final routeSpots = _routeSpots;
    return ColoredBox(
      color: const Color(0xFFF7F7F7),
      child: Stack(
        children: [
          // ── 지도 ──────────────────────────────────────────
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _kCenter,
                initialZoom: _kInitialZoom,
                minZoom: _kMinZoom,
                maxZoom: _kMaxZoom,
                onPositionChanged: (camera, _) {
                  if ((_currentZoom - camera.zoom).abs() > 0.05) {
                    setState(() => _currentZoom = camera.zoom);
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.seoulland.seoul_land_app',
                ),
                // 마이 루나 동선 polyline
                if (_showRoute && routeSpots.length > 1)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: routeSpots.map((s) => s.position).toList(),
                        color: const Color(0xFFE60012),
                        strokeWidth: 3.5,
                        pattern: StrokePattern.dashed(segments: const [8, 5]),
                      ),
                    ],
                  ),
                // "여기로 이동하기" polyline (정문 → 타깃)
                if (_navTarget != null)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: [_kGate, _navTarget!.position],
                        color: const Color(0xFFE60012),
                        strokeWidth: 4.5,
                      ),
                    ],
                  ),
                MarkerLayer(markers: _buildMarkers()),
              ],
            ),
          ),

          // ── 상단 검색 + 동선/GPS 버튼 + 필터 칩 ─────────
          _TopBar(
            activeFilter: _activeFilter,
            routeOn: _showRoute,
            gpsLoading: _gpsLoading,
            onToggleRoute: _toggleRoute,
            onGps: _moveToGps,
            onFilter: (f) => setState(() {
              _activeFilter = f;
              if (f == '이스터에그') _easterEggSubFilter = false; // 이미 상단에서 처리
            }),
          ),

          // ── 상태 배지 ────────────────────────────────────
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

          // ── 하단 시설안내 시트 (DraggableScrollableSheet) ─
          DraggableScrollableSheet(
            initialChildSize: 0.5,
            minChildSize: 0.30,
            maxChildSize: 0.9,
            snap: true,
            snapSizes: const [0.30, 0.50, 0.9],
            builder: (context, scrollController) {
              return _FacilitySheet(
                scrollController: scrollController,
                spots: _filteredSpots,
                activeFilter: _activeFilter,
                operatingOnly: _operatingOnly,
                easterEgg: _easterEggSubFilter,
                catColor: _categoryColor,
                catLabel: _categoryLabel,
                onOperatingOnly: () => setState(() => _operatingOnly = !_operatingOnly),
                onEasterEgg: () => setState(() {
                  _easterEggSubFilter = !_easterEggSubFilter;
                  if (_easterEggSubFilter) _activeFilter = '이스터에그';
                }),
                onCardTap: _openSpotDetail,
                discoveredEggs: _discoveredEggs,
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─── 상단 바: 검색 + 동선 + GPS + 카테고리 칩 ────────────────
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

  static const _filters = ['전체', '어트랙션', '음식점', '포토존', '이스터에그'];

  Color _catColor(String f) {
    switch (f) {
      case '어트랙션':
        return const Color(0xFFE60012);
      case '음식점':
        return const Color(0xFFFF6D00);
      case '포토존':
        return const Color(0xFF8E24AA);
      case '이스터에그':
        return const Color(0xFFF4B633);
      default:
        return const Color(0xFFE60012);
    }
  }

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
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F7F7),
                          borderRadius: BorderRadius.circular(12),
                        ),
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
                                  hintText: '어트랙션, 음식점, 포토스팟',
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
                          child: Text(
                            f,
                            style: TextStyle(
                              color: active ? Colors.white : const Color(0xFF1F1F1F),
                              fontSize: 13, fontWeight: FontWeight.w800,
                            ),
                          ),
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
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
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
            GestureDetector(
              onTap: onClose,
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── 시설안내 DraggableScrollableSheet ───────────────────────
class _FacilitySheet extends StatelessWidget {
  final ScrollController scrollController;
  final List<Spot> spots;
  final String activeFilter;
  final bool operatingOnly;
  final bool easterEgg;
  final Color Function(SpotCategory) catColor;
  final String Function(SpotCategory) catLabel;
  final VoidCallback onOperatingOnly;
  final VoidCallback onEasterEgg;
  final void Function(Spot) onCardTap;
  final Set<String> discoveredEggs;

  const _FacilitySheet({
    required this.scrollController,
    required this.spots,
    required this.activeFilter,
    required this.operatingOnly,
    required this.easterEgg,
    required this.catColor,
    required this.catLabel,
    required this.onOperatingOnly,
    required this.onEasterEgg,
    required this.onCardTap,
    required this.discoveredEggs,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, -4))],
      ),
      child: Column(
        children: [
          // 드래그 핸들 — DraggableScrollableSheet 의 드래그 영역이 됨
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Container(
              width: 40, height: 5,
              decoration: BoxDecoration(color: const Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(99)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
            child: Row(
              children: [
                Text('${activeFilter == '전체' ? '전체' : activeFilter} ${spots.length}곳',
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
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
            child: Row(
              children: [
                _SubChip(
                  text: '운영중',
                  active: operatingOnly,
                  activeColor: const Color(0xFF4CAF50),
                  onTap: onOperatingOnly,
                ),
                const SizedBox(width: 8),
                _SubChip(
                  text: '이스터에그 ✨',
                  active: easterEgg,
                  activeColor: const Color(0xFFF4B633),
                  onTap: onEasterEgg,
                ),
              ],
            ),
          ),
          Expanded(
            child: spots.isEmpty
                ? const Center(
                    child: Text('해당하는 시설이 없습니다',
                        style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 13, fontWeight: FontWeight.w600)),
                  )
                : ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    itemCount: spots.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final s = spots[i];
                      final undiscoveredEgg = activeFilter == '이스터에그' && !discoveredEggs.contains(s.id);
                      final operatingDim = !s.isOperating;
                      return Opacity(
                        opacity: (undiscoveredEgg || operatingDim) ? 0.4 : 1.0,
                        child: GestureDetector(
                          onTap: () => onCardTap(s),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: s.hasEasterEgg ? const Color(0xFFF4B633) : const Color(0xFFEEEEEE),
                              ),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44, height: 44,
                                  decoration: BoxDecoration(
                                    color: catColor(s.category).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(s.icon, style: const TextStyle(fontSize: 22)),
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
                                            child: Text(s.name,
                                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1F1F1F)),
                                                overflow: TextOverflow.ellipsis),
                                          ),
                                          if (s.hasEasterEgg) const Padding(
                                              padding: EdgeInsets.only(left: 4),
                                              child: Text('🥚', style: TextStyle(fontSize: 12))),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${catLabel(s.category)} · ${s.zone}${s.waitTime != null ? ' · 대기 ${s.waitTime}' : ''}',
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
                    },
                  ),
          ),
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
