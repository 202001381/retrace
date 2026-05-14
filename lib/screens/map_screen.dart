import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../models/spot_model.dart';
import '../widgets/spot_detail_sheet.dart';

class MapScreen extends StatefulWidget {
  final bool showMyLunaInitially;
  const MapScreen({super.key, this.showMyLunaInitially = false});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const LatLng _center = LatLng(37.4279, 127.0247);

  final MapController _mapController = MapController();
  StreamSubscription<Position>? _positionStream;
  LatLng? _myPosition;
  bool _gpsActive = false;
  bool _showRoute = false;
  bool _showDropdown = false;

  // 카테고리 필터: 전체 / 어트랙션 / 음식점 / 포토존 / 이스터에그
  String _activeFilter = '전체';

  Spot? _selectedSpot;
  String _facilityTab = '어트랙션';
  bool _operatingOnly = true;

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

  Future<void> _toggleGps() async {
    if (_gpsActive) {
      await _positionStream?.cancel();
      setState(() {
        _gpsActive = false;
        _myPosition = null;
      });
      return;
    }
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        return;
      }
      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5),
      ).listen((p) {
        setState(() => _myPosition = LatLng(p.latitude, p.longitude));
      });
      setState(() => _gpsActive = true);
    } catch (_) {}
  }

  Color _catColor(SpotCategory c) {
    switch (c) {
      case SpotCategory.attraction:
        return const Color(0xFFE60012);
      case SpotCategory.food:
        return const Color(0xFFFF6D00);
      case SpotCategory.photo:
        return const Color(0xFF8E24AA);
    }
  }

  String _catLabel(SpotCategory c) {
    switch (c) {
      case SpotCategory.attraction:
        return '어트랙션';
      case SpotCategory.food:
        return '음식점';
      case SpotCategory.photo:
        return '포토존';
    }
  }

  List<Spot> get _filteredMapSpots {
    final all = SeoulLandSpots.all;
    if (_activeFilter == '전체') return all;
    if (_activeFilter == '이스터에그') return all.where((s) => s.hasEasterEgg).toList();
    if (_activeFilter == '어트랙션') return all.where((s) => s.category == SpotCategory.attraction).toList();
    if (_activeFilter == '음식점') return all.where((s) => s.category == SpotCategory.food).toList();
    if (_activeFilter == '포토존') return all.where((s) => s.category == SpotCategory.photo).toList();
    return all;
  }

  List<Spot> get _bottomSpots {
    final cat = _facilityTab == '어트랙션'
        ? SpotCategory.attraction
        : _facilityTab == '음식점·상점'
            ? SpotCategory.food
            : null;
    var list = SeoulLandSpots.all;
    if (cat != null) list = list.where((s) => s.category == cat).toList();
    if (_operatingOnly) list = list.where((s) => s.isOperating).toList();
    return list.take(12).toList();
  }

  Map<SpotCategory, int> get _categoryCounts {
    return {
      for (final c in SpotCategory.values)
        c: SeoulLandSpots.all.where((s) => s.category == c).length,
    };
  }

  // 상위 3개 어트랙션 (홈 마이루나와 동일 컨셉) — 동선 폴리라인용
  List<Spot> get _routeSpots {
    return SeoulLandSpots.byCategory(SpotCategory.attraction).take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    final counts = _categoryCounts;

    // 같은 패턴: MainScreen 의 Scaffold 안에 IndexedStack 으로 들어가므로
    // 여기서는 Scaffold 를 또 만들지 않는다. ColoredBox 로 배경만 깔고 Stack.
    return ColoredBox(
      color: const Color(0xFFF7F7F7),
      child: Stack(
        children: [
          // ── 지도 ──────────────────────────────────────────
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: const MapOptions(
                initialCenter: _center,
                initialZoom: 17,
                minZoom: 14,
                maxZoom: 19,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.seoulland.seoul_land_app',
                ),
                if (_showRoute && _routeSpots.length > 1)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _routeSpots.map((s) => s.position).toList(),
                        color: const Color(0xFFE60012),
                        strokeWidth: 3.5,
                        pattern: StrokePattern.dashed(segments: const [8, 5]),
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    for (final s in _filteredMapSpots) _spotMarker(s, _routeSpots),
                    if (_gpsActive && _myPosition != null)
                      Marker(
                        point: _myPosition!,
                        width: 24,
                        height: 24,
                        child: _GpsDot(),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // ── 상단 검색 + 필터 ─────────────────────────────
          _TopBar(
            showDropdown: _showDropdown,
            gpsActive: _gpsActive,
            showRoute: _showRoute,
            activeFilter: _activeFilter,
            onToggleDropdown: () => setState(() => _showDropdown = !_showDropdown),
            onToggleGps: () {
              setState(() => _showDropdown = false);
              _toggleGps();
            },
            onToggleRoute: () => setState(() {
              _showRoute = !_showRoute;
              _showDropdown = false;
            }),
            onFilter: (f) => setState(() => _activeFilter = f),
          ),

          // ── 상태 배지 ────────────────────────────────────
          if (_gpsActive || _showRoute)
            Positioned(
              top: MediaQuery.of(context).padding.top + 120,
              left: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_gpsActive) _StatusBadge(color: const Color(0xFF4CAF50), text: 'GPS 활성', pulse: true),
                  if (_gpsActive && _showRoute) const SizedBox(height: 8),
                  if (_showRoute) _StatusBadge(color: const Color(0xFFE60012), text: '마이 루나 동선', pulse: false),
                ],
              ),
            ),

          // ── 우측 FAB (recenter) ──────────────────────────
          Positioned(
            right: 16,
            bottom: 350,
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(),
              elevation: 4,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => _mapController.move(_center, 17),
                child: const SizedBox(
                  width: 48,
                  height: 48,
                  child: Icon(Icons.navigation_outlined, color: Color(0xFF1F1F1F)),
                ),
              ),
            ),
          ),

          // ── 하단 시트 ────────────────────────────────────
          _BottomSheet(
            counts: counts,
            facilityTab: _facilityTab,
            operatingOnly: _operatingOnly,
            spots: _bottomSpots,
            catColor: _catColor,
            catLabel: _catLabel,
            onTab: (t) => setState(() => _facilityTab = t),
            onOperatingOnly: () => setState(() => _operatingOnly = !_operatingOnly),
            onEasterEgg: () => setState(() => _activeFilter = '이스터에그'),
            onSpotTap: (s) => _openSpotDetail(s),
          ),
        ],
      ),
    );
  }

  Marker _spotMarker(Spot s, List<Spot> routeSpots) {
    final isRoute = _showRoute && routeSpots.contains(s);
    final order = isRoute ? routeSpots.indexOf(s) + 1 : 0;
    final color = _catColor(s.category);
    return Marker(
      point: s.position,
      width: 44,
      height: 44,
      alignment: Alignment.topCenter,
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
                border: Border.all(color: s.hasEasterEgg ? const Color(0xFFF4B633) : Colors.white, width: s.hasEasterEgg ? 3 : 2),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 2))],
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
                  child: Text('$order', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _openSpotDetail(Spot s) {
    setState(() => _selectedSpot = s);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SpotDetailSheet(spot: s),
    ).then((_) => setState(() => _selectedSpot = null));
  }
}

// ─── 상단 검색 + 필터 바 ────────────────────────────────────
class _TopBar extends StatelessWidget {
  final bool showDropdown;
  final bool gpsActive;
  final bool showRoute;
  final String activeFilter;
  final VoidCallback onToggleDropdown;
  final VoidCallback onToggleGps;
  final VoidCallback onToggleRoute;
  final void Function(String) onFilter;

  const _TopBar({
    required this.showDropdown,
    required this.gpsActive,
    required this.showRoute,
    required this.activeFilter,
    required this.onToggleDropdown,
    required this.onToggleGps,
    required this.onToggleRoute,
    required this.onFilter,
  });

  static const _filters = [
    ('전체', null),
    ('어트랙션', '🎢'),
    ('음식점', '🍽️'),
    ('포토존', '📸'),
    ('이스터에그', '🥚'),
  ];

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
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        GestureDetector(
                          onTap: onToggleDropdown,
                          child: Container(
                            height: 40,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E3158),
                              borderRadius: BorderRadius.circular(10),
                              border: showDropdown ? Border.all(color: const Color(0xFFE60012), width: 2) : null,
                            ),
                            alignment: Alignment.center,
                            child: const Row(
                              children: [
                                Icon(Icons.explore_outlined, size: 16, color: Colors.white),
                                SizedBox(width: 4),
                                Text('동선·GPS', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
                              ],
                            ),
                          ),
                        ),
                        if (showDropdown)
                          Positioned(
                            top: 48, right: 0,
                            child: _Dropdown(
                              gpsActive: gpsActive,
                              showRoute: showRoute,
                              onToggleGps: onToggleGps,
                              onToggleRoute: onToggleRoute,
                            ),
                          ),
                      ],
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
                      final active = activeFilter == f.$1;
                      return GestureDetector(
                        onTap: () => onFilter(f.$1),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: active ? _catColor(f.$1) : Colors.white,
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(color: active ? _catColor(f.$1) : const Color(0xFFDDDDDD)),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            f.$2 == null ? f.$1 : '${f.$1} ${f.$2}',
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

class _Dropdown extends StatelessWidget {
  final bool gpsActive, showRoute;
  final VoidCallback onToggleGps, onToggleRoute;
  const _Dropdown({required this.gpsActive, required this.showRoute, required this.onToggleGps, required this.onToggleRoute});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 200,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFEEEEEE))),
        child: Column(
          children: [
            _DropdownRow(
              icon: Icons.navigation_outlined,
              iconColor: const Color(0xFF1E3158),
              label: 'GPS 켜기',
              active: gpsActive,
              activeColor: const Color(0xFF4CAF50),
              onTap: onToggleGps,
            ),
            const Divider(height: 1, color: Color(0xFFEEEEEE)),
            _DropdownRow(
              icon: null,
              dashedLabel: true,
              label: '동선 보기',
              active: showRoute,
              activeColor: const Color(0xFFE60012),
              onTap: onToggleRoute,
            ),
          ],
        ),
      ),
    );
  }
}

class _DropdownRow extends StatelessWidget {
  final IconData? icon;
  final Color iconColor;
  final bool dashedLabel;
  final String label;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;
  const _DropdownRow({
    this.icon,
    this.iconColor = const Color(0xFF1E3158),
    this.dashedLabel = false,
    required this.label,
    required this.active,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            if (icon != null) Icon(icon, color: iconColor, size: 18),
            if (dashedLabel)
              const Text('— —', style: TextStyle(color: Color(0xFFE60012), fontWeight: FontWeight.w900, fontSize: 13)),
            const SizedBox(width: 8),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF1F1F1F)))),
            Container(
              width: 36, height: 22,
              decoration: BoxDecoration(color: active ? activeColor : const Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(99)),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                alignment: active ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.all(2),
                  width: 18, height: 18,
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final Color color;
  final String text;
  final bool pulse;
  const _StatusBadge({required this.color, required this.text, required this.pulse});

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
        ],
      ),
    );
  }
}

class _GpsDot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
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
    );
  }
}

// ─── 하단 시설 안내 시트 ────────────────────────────────────
class _BottomSheet extends StatelessWidget {
  final Map<SpotCategory, int> counts;
  final String facilityTab;
  final bool operatingOnly;
  final List<Spot> spots;
  final Color Function(SpotCategory) catColor;
  final String Function(SpotCategory) catLabel;
  final void Function(String) onTab;
  final VoidCallback onOperatingOnly;
  final VoidCallback onEasterEgg;
  final void Function(Spot) onSpotTap;

  const _BottomSheet({
    required this.counts,
    required this.facilityTab,
    required this.operatingOnly,
    required this.spots,
    required this.catColor,
    required this.catLabel,
    required this.onTab,
    required this.onOperatingOnly,
    required this.onEasterEgg,
    required this.onSpotTap,
  });

  static const _tabs = ['어트랙션', '음식점·상점', '공연', '편의시설'];

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0, right: 0, bottom: 0,
      child: Container(
        height: 320,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, -4))],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Container(
                width: 40, height: 5,
                decoration: BoxDecoration(color: const Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(99)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Text('시설안내', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF1F1F1F))),
                      Spacer(),
                      _PulseDot(),
                      SizedBox(width: 4),
                      Text('실시간 연동 중',
                          style: TextStyle(fontSize: 11, color: Color(0xFFE60012), fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    children: [
                      _CountPill(text: '🎢 ${counts[SpotCategory.attraction] ?? 0}', color: const Color(0xFFE60012)),
                      _CountPill(text: '🍽️ ${counts[SpotCategory.food] ?? 0}', color: const Color(0xFFFF6D00)),
                      _CountPill(text: '📸 ${counts[SpotCategory.photo] ?? 0}', color: const Color(0xFF8E24AA)),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFEEEEEE)),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: SizedBox(
                height: 30,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _tabs.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (_, i) {
                    final t = _tabs[i];
                    final active = facilityTab == t;
                    return GestureDetector(
                      onTap: () => onTab(t),
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: onOperatingOnly,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: operatingOnly ? const Color(0xFF4CAF50) : Colors.white,
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: operatingOnly ? const Color(0xFF4CAF50) : const Color(0xFFDDDDDD)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6, height: 6,
                            decoration: BoxDecoration(
                              color: operatingOnly ? Colors.white : const Color(0xFFDDDDDD),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text('운영중',
                              style: TextStyle(
                                color: operatingOnly ? Colors.white : const Color(0xFF1F1F1F),
                                fontSize: 11, fontWeight: FontWeight.w800,
                              )),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: onEasterEgg,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4B633).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: const Color(0xFFF4B633)),
                      ),
                      child: const Text('이스터에그 ✨',
                          style: TextStyle(color: Color(0xFFF4B633), fontSize: 11, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: spots.isEmpty
                  ? const Center(child: Text('해당하는 시설이 없습니다', style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 13, fontWeight: FontWeight.w600)))
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: spots.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (_, i) => _SpotCard(spot: spots[i], catColor: catColor, onTap: () => onSpotTap(spots[i])),
                    ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot();
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

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

class _CountPill extends StatelessWidget {
  final String text;
  final Color color;
  const _CountPill({required this.text, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(99)),
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800)),
    );
  }
}

class _SpotCard extends StatelessWidget {
  final Spot spot;
  final Color Function(SpotCategory) catColor;
  final VoidCallback onTap;
  const _SpotCard({required this.spot, required this.catColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final wait = spot.waitTime;
    final waitColor = wait == null || wait == '0분'
        ? const Color(0xFF4CAF50)
        : wait.startsWith('5분') || wait.startsWith('10분')
            ? const Color(0xFFFFB300)
            : const Color(0xFFE60012);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 84,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: spot.hasEasterEgg ? const Color(0xFFF4B633) : const Color(0xFFEEEEEE)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(spot.icon, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 4),
            SizedBox(
              height: 26,
              child: Text(
                spot.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF1F1F1F), height: 1.1),
              ),
            ),
            const SizedBox(height: 4),
            if (wait != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(width: 6, height: 6, decoration: BoxDecoration(color: waitColor, shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  Text(wait, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF888888))),
                ],
              ),
            if (spot.hasEasterEgg)
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Text('🥚 이스터에그', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Color(0xFFF4B633))),
              ),
          ],
        ),
      ),
    );
  }
}
