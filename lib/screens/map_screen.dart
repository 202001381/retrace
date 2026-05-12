import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../models/spot_model.dart';
import '../widgets/ai_scan_modal.dart';
import '../widgets/spot_detail_sheet.dart';
import '../screens/route_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  StreamSubscription<Position>? _positionStream;
  LatLng? _currentPosition;
  bool _gpsEnabled = false;
  bool _isLocating = false;
  bool _showRoute = false;

  // 필터
  SpotCategory? _activeCategory;   // null = 전체
  String _activeFilter = '전체';
  bool _showEasterEgg = false;

  // 선택된 스팟
  Spot? _selectedSpot;

  // 동선 추천 상태 (홈에서 설정한 값 사용)
  String _companionType = '가족';
  List<String> _preferences = ['스릴·액티비티'];
  List<Spot> _recommendedRoute = [];

  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  static const LatLng _seoulLandCenter = LatLng(37.4279, 127.0247);

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this, duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _buildRecommendedRoute();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _buildRecommendedRoute() {
    _recommendedRoute = SeoulLandSpots.recommendedRoute(
      companionType: _companionType,
      preferences: _preferences,
      maxSpots: 8,
    );
  }

  // GPS 위치 추적 시작/중지
  Future<void> _toggleGps() async {
    if (_gpsEnabled) {
      await _positionStream?.cancel();
      setState(() { _gpsEnabled = false; _currentPosition = null; });
      return;
    }

    setState(() => _isLocating = true);

    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }

    if (perm == LocationPermission.deniedForever || perm == LocationPermission.denied) {
      setState(() => _isLocating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📍 위치 권한이 필요합니다. 설정에서 허용해주세요.'),
            backgroundColor: Color(0xFFE60012),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    // 웹 환경에서는 실제 GPS 대신 서울랜드 내 시뮬레이션 위치 사용
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      ).timeout(const Duration(seconds: 5));

      setState(() {
        _currentPosition = LatLng(pos.latitude, pos.longitude);
        _gpsEnabled = true;
        _isLocating = false;
      });
      _mapController.move(_currentPosition!, 17.5);

      // 실시간 스트림
      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        ),
      ).listen((p) {
        if (mounted) {
          setState(() => _currentPosition = LatLng(p.latitude, p.longitude));
        }
      });

    } catch (_) {
      // 웹/에뮬레이터: 서울랜드 중심 시뮬레이션
      setState(() {
        _currentPosition = const LatLng(37.4279, 127.0247);
        _gpsEnabled = true;
        _isLocating = false;
      });
      _mapController.move(_currentPosition!, 17.5);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📍 GPS 시뮬레이션 모드: 서울랜드 중심으로 위치 설정'),
            backgroundColor: Color(0xFF1E3158),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // 스팟 탭 핸들러
  void _onSpotTap(Spot spot) {
    setState(() => _selectedSpot = spot);

    if (spot.hasEasterEgg) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AiScanModal(
          spotName: spot.name,
          icon: spot.icon,
          description: spot.description,
          onCollect: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('📖 연대기(Chronicle)에 수집되었습니다!'),
                backgroundColor: Color(0xFF1E3158),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => SpotDetailSheet(spot: spot),
      );
    }
  }

  // 필터링된 스팟 목록
  List<Spot> get _filteredSpots {
    var spots = SeoulLandSpots.all;
    if (_showEasterEgg) {
      spots = spots.where((s) => s.hasEasterEgg).toList();
    } else if (_activeCategory != null) {
      spots = spots.where((s) => s.category == _activeCategory).toList();
    }
    return spots;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            // ── 지도 ──────────────────────────────────────────
            _buildMap(),

            // ── 상단 검색바 + 필터 ───────────────────────────
            Positioned(top: 0, left: 0, right: 0, child: _buildTopBar()),

            // ── 우측 컨트롤 버튼 ────────────────────────────
            Positioned(right: 12, bottom: 230, child: _buildMapControls()),

            // ── 하단 시설 안내 시트 ─────────────────────────
            Positioned(bottom: 0, left: 0, right: 0, child: _buildBottomSheet()),
          ],
        ),
      ),
    );
  }

  // ─── 지도 위젯 ─────────────────────────────────────────────
  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _seoulLandCenter,
        initialZoom: 17.0,
        minZoom: 15.0,
        maxZoom: 19.0,
        onTap: (_, __) => setState(() => _selectedSpot = null),
      ),
      children: [
        // OSM 타일 레이어
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.seoulland.app',
          maxZoom: 19,
        ),

        // 추천 동선 경로선
        if (_showRoute && _recommendedRoute.length > 1)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _recommendedRoute.map((s) => s.position).toList(),
                color: const Color(0xFFE60012).withValues(alpha: 0.8),
                strokeWidth: 3.5,
                pattern: StrokePattern.dashed(segments: [12, 6]),
              ),
            ],
          ),

        // 스팟 마커 레이어
        MarkerLayer(
          markers: _filteredSpots.map((spot) => _buildMarker(spot)).toList(),
        ),

        // 추천 동선 순서 번호
        if (_showRoute)
          MarkerLayer(
            markers: _recommendedRoute.asMap().entries.map((e) =>
              _buildRouteNumberMarker(e.key + 1, e.value.position)
            ).toList(),
          ),

        // GPS 현재 위치 마커
        if (_currentPosition != null)
          MarkerLayer(
            markers: [_buildGpsMarker(_currentPosition!)],
          ),
      ],
    );
  }

  // ─── 마커 빌더 ─────────────────────────────────────────────
  Marker _buildMarker(Spot spot) {
    final isSelected = _selectedSpot?.id == spot.id;
    final isInRoute = _showRoute && _recommendedRoute.any((s) => s.id == spot.id);

    return Marker(
      point: spot.position,
      width: isSelected ? 90 : 72,
      height: isSelected ? 62 : 52,
      child: GestureDetector(
        onTap: () => _onSpotTap(spot),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 라벨
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: isSelected
                      ? _categoryColor(spot.category)
                      : isInRoute
                          ? const Color(0xFFE60012).withValues(alpha: 0.9)
                          : Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected || isInRoute
                        ? Colors.transparent
                        : _categoryColor(spot.category).withValues(alpha: 0.4),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 6, offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  spot.name,
                  style: TextStyle(
                    fontSize: isSelected ? 10 : 9,
                    fontWeight: FontWeight.w700,
                    color: isSelected || isInRoute
                        ? Colors.white
                        : const Color(0xFF1F1F1F),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 2),
              // 아이콘 핀
              Container(
                width: isSelected ? 36 : 30,
                height: isSelected ? 36 : 30,
                decoration: BoxDecoration(
                  color: spot.hasEasterEgg
                      ? const Color(0xFFFFB300)
                      : _categoryColor(spot.category),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: isSelected ? 2.5 : 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _categoryColor(spot.category).withValues(alpha: 0.4),
                      blurRadius: isSelected ? 10 : 6,
                      spreadRadius: isSelected ? 2 : 0,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    spot.icon,
                    style: TextStyle(fontSize: isSelected ? 18 : 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 동선 순서 번호 마커
  Marker _buildRouteNumberMarker(int num, LatLng pos) {
    return Marker(
      point: pos,
      width: 22,
      height: 22,
      alignment: const Alignment(1.8, -1.8),
      child: Container(
        width: 20, height: 20,
        decoration: BoxDecoration(
          color: const Color(0xFFE60012),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4)],
        ),
        child: Center(
          child: Text(
            '$num',
            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
          ),
        ),
      ),
    );
  }

  // GPS 마커 (파란 점 + 펄스)
  Marker _buildGpsMarker(LatLng pos) {
    return Marker(
      point: pos,
      width: 60, height: 60,
      child: AnimatedBuilder(
        animation: _pulseAnim,
        builder: (_, __) => Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 40 * _pulseAnim.value,
                height: 40 * _pulseAnim.value,
                decoration: BoxDecoration(
                  color: const Color(0xFF2196F3).withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
              ),
              Container(
                width: 16, height: 16,
                decoration: BoxDecoration(
                  color: const Color(0xFF2196F3),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF2196F3).withValues(alpha: 0.5), blurRadius: 8),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _categoryColor(SpotCategory cat) {
    switch (cat) {
      case SpotCategory.attraction: return const Color(0xFFE60012);
      case SpotCategory.food:       return const Color(0xFFFF6D00);
      case SpotCategory.photo:      return const Color(0xFF8E24AA);
    }
  }

  // ─── 상단 검색바 + 필터 ────────────────────────────────────
  Widget _buildTopBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8)],
      ),
      child: Column(
        children: [
          // 검색바
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        SizedBox(width: 12),
                        Icon(Icons.search_rounded, color: Color(0xFF9E9E9E), size: 18),
                        SizedBox(width: 8),
                        Text('어트랙션, 음식점, 포토스팟',
                            style: TextStyle(color: Color(0xFF9E9E9E), fontSize: 13)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // 동선 보기 토글
                GestureDetector(
                  onTap: () {
                    setState(() => _showRoute = !_showRoute);
                    if (_showRoute) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('🗺️ ${_companionType} 맞춤 동선 ${_recommendedRoute.length}곳 표시 중'),
                          backgroundColor: const Color(0xFFE60012),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: _showRoute ? const Color(0xFFE60012) : const Color(0xFF1E3158),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _showRoute ? Icons.route_rounded : Icons.assistant_direction_rounded,
                          color: Colors.white, size: 16,
                        ),
                        Text(
                          _showRoute ? '동선ON' : '동선',
                          style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // GPS 버튼
                GestureDetector(
                  onTap: _toggleGps,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: _gpsEnabled
                          ? const Color(0xFF2196F3)
                          : _isLocating
                              ? const Color(0xFFFFB300)
                              : const Color(0xFF555555),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _isLocating
                            ? const SizedBox(
                                width: 16, height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white,
                                ),
                              )
                            : Icon(
                                _gpsEnabled ? Icons.gps_fixed_rounded : Icons.gps_not_fixed_rounded,
                                color: Colors.white, size: 16,
                              ),
                        Text(
                          _gpsEnabled ? 'GPS ON' : 'GPS',
                          style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 카테고리 필터 칩
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _filterChip('전체', null, Icons.apps_rounded),
                const SizedBox(width: 6),
                _filterChip('어트랙션', SpotCategory.attraction, Icons.local_activity_rounded),
                const SizedBox(width: 6),
                _filterChip('음식점', SpotCategory.food, Icons.restaurant_rounded),
                const SizedBox(width: 6),
                _filterChip('포토스팟', SpotCategory.photo, Icons.photo_camera_rounded),
                const SizedBox(width: 6),
                _easterEggChip(),
                const SizedBox(width: 12),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _filterChip(String label, SpotCategory? cat, IconData icon) {
    final isActive = _activeCategory == cat && !_showEasterEgg;
    final color = cat == null
        ? const Color(0xFF1F1F1F)
        : _categoryColor(cat);

    return GestureDetector(
      onTap: () {
        setState(() {
          _activeCategory = cat;
          _showEasterEgg = false;
          _activeFilter = label;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? color : const Color(0xFFE0E0E0)),
          boxShadow: isActive ? [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 6)] : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isActive ? Colors.white : color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.white : const Color(0xFF555555),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _easterEggChip() {
    return GestureDetector(
      onTap: () => setState(() {
        _showEasterEgg = !_showEasterEgg;
        if (_showEasterEgg) _activeCategory = null;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _showEasterEgg ? const Color(0xFFFFB300) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _showEasterEgg ? const Color(0xFFFFB300) : const Color(0xFFE0E0E0),
          ),
          boxShadow: _showEasterEgg
              ? [BoxShadow(color: const Color(0xFFFFB300).withValues(alpha: 0.4), blurRadius: 6)]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🥚', style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 5),
            Text(
              '이스터에그 숨겨진 곳',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _showEasterEgg ? Colors.white : const Color(0xFF555555),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── 우측 컨트롤 버튼 ──────────────────────────────────────
  Widget _buildMapControls() {
    return Column(
      children: [
        // 내 위치로 이동
        _mapBtn(
          icon: Icons.my_location_rounded,
          color: const Color(0xFF2196F3),
          onTap: () {
            if (_currentPosition != null) {
              _mapController.move(_currentPosition!, 17.5);
            } else {
              _toggleGps();
            }
          },
        ),
        const SizedBox(height: 8),
        // 서울랜드 중심으로
        _mapBtn(
          icon: Icons.home_rounded,
          color: const Color(0xFFE60012),
          onTap: () => _mapController.move(_seoulLandCenter, 17.0),
        ),
        const SizedBox(height: 8),
        // 동선 추천 화면
        _mapBtn(
          icon: Icons.directions_rounded,
          color: const Color(0xFF1E3158),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RouteScreen(
                companionType: _companionType,
                preferences: _preferences,
                recommendedRoute: _recommendedRoute,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _mapBtn({required IconData icon, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42, height: 42,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  // ─── 하단 시설 안내 바텀시트 ───────────────────────────────
  Widget _buildBottomSheet() {
    final counts = {
      SpotCategory.attraction: SeoulLandSpots.byCategory(SpotCategory.attraction).length,
      SpotCategory.food:       SeoulLandSpots.byCategory(SpotCategory.food).length,
      SpotCategory.photo:      SeoulLandSpots.byCategory(SpotCategory.photo).length,
    };

    final displaySpots = _filteredSpots.take(6).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 16, offset: const Offset(0, -4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 드래그 핸들
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 6),
            width: 40, height: 4,
            decoration: BoxDecoration(color: const Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(2)),
          ),

          // 헤더
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text('시설안내', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1F1F1F))),
                const SizedBox(width: 10),
                // 스팟 수 배지들
                _countBadge('🎢 ${counts[SpotCategory.attraction]}', const Color(0xFFE60012)),
                const SizedBox(width: 5),
                _countBadge('🍽️ ${counts[SpotCategory.food]}', const Color(0xFFFF6D00)),
                const SizedBox(width: 5),
                _countBadge('📸 ${counts[SpotCategory.photo]}', const Color(0xFF8E24AA)),
                const Spacer(),
                // 혼잡도 실시간
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3F3),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFFFCDD2)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, size: 7, color: Color(0xFFE60012)),
                      SizedBox(width: 4),
                      Text('실시간 연동 중', style: TextStyle(fontSize: 10, color: Color(0xFFE60012), fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // 스팟 가로 스크롤 카드
          SizedBox(
            height: 88,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: displaySpots.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) => _SpotMiniCard(
                spot: displaySpots[i],
                isSelected: _selectedSpot?.id == displaySpots[i].id,
                onTap: () {
                  _mapController.move(displaySpots[i].position, 18.0);
                  _onSpotTap(displaySpots[i]);
                },
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _countBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700)),
    );
  }
}

// ─── 미니 스팟 카드 ────────────────────────────────────────
class _SpotMiniCard extends StatelessWidget {
  final Spot spot;
  final bool isSelected;
  final VoidCallback onTap;

  const _SpotMiniCard({required this.spot, required this.isSelected, required this.onTap});

  Color get _catColor {
    switch (spot.category) {
      case SpotCategory.attraction: return const Color(0xFFE60012);
      case SpotCategory.food:       return const Color(0xFFFF6D00);
      case SpotCategory.photo:      return const Color(0xFF8E24AA);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 110,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected ? _catColor.withValues(alpha: 0.08) : const Color(0xFFF8F8F8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? _catColor : Colors.transparent,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(spot.icon, style: const TextStyle(fontSize: 20)),
                if (spot.hasEasterEgg) const Text(' ✨', style: TextStyle(fontSize: 10)),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              spot.name,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1F1F1F)),
              maxLines: 1, overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            if (spot.waitTime != null)
              Row(children: [
                Container(width: 6, height: 6,
                  decoration: BoxDecoration(
                    color: spot.waitTime == '없음' ? const Color(0xFF4CAF50) : const Color(0xFFFFB300),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text('대기 ${spot.waitTime}', style: const TextStyle(fontSize: 10, color: Color(0xFF888888))),
              ])
            else if (spot.priceRange != null)
              Text(spot.priceRange!, style: TextStyle(fontSize: 10, color: _catColor, fontWeight: FontWeight.w600))
            else if (spot.photoTip != null)
              const Text('📸 포토스팟', style: TextStyle(fontSize: 10, color: Color(0xFF8E24AA), fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
