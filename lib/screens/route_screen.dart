import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/spot_model.dart';
import '../widgets/spot_detail_sheet.dart';

class RouteScreen extends StatefulWidget {
  final String companionType;
  final List<String> preferences;
  final List<Spot> recommendedRoute;

  const RouteScreen({
    super.key,
    required this.companionType,
    required this.preferences,
    required this.recommendedRoute,
  });

  @override
  State<RouteScreen> createState() => _RouteScreenState();
}

class _RouteScreenState extends State<RouteScreen> with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  int _focusedIndex = 0;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  static const LatLng _center = LatLng(37.4279, 127.0247);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  int get _totalMinutes =>
      widget.recommendedRoute.fold(0, (sum, s) => sum + s.visitDurationMin);

  Color _categoryColor(SpotCategory cat) {
    switch (cat) {
      case SpotCategory.attraction: return const Color(0xFFE60012);
      case SpotCategory.food:       return const Color(0xFFFF6D00);
      case SpotCategory.photo:      return const Color(0xFF8E24AA);
    }
  }

  String _categoryLabel(SpotCategory cat) {
    switch (cat) {
      case SpotCategory.attraction: return '어트랙션';
      case SpotCategory.food:       return '음식점';
      case SpotCategory.photo:      return '포토스팟';
    }
  }

  String get _companionEmoji {
    switch (widget.companionType) {
      case '가족': return '👨‍👩‍👧‍👦';
      case '연인': return '💑';
      case '친구': return '👯';
      case '혼자': return '🧍';
      default: return '👤';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildMapSection(),
            Expanded(child: _buildRouteList()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: const BoxDecoration(
        color: Color(0xFF1E3158),
      ),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _companionEmoji,
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${widget.companionType} 맞춤 동선 추천',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.preferences.join(' · '),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 통계 행
          Row(
            children: [
              _statChip('🗺️', '${widget.recommendedRoute.length}개 스팟'),
              const SizedBox(width: 8),
              _statChip('⏱️', '약 ${_totalMinutes ~/ 60}시간 ${_totalMinutes % 60}분'),
              const SizedBox(width: 8),
              _statChip('🎯', 'AI 최적 동선'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statChip(String emoji, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapSection() {
    final focusedSpot = widget.recommendedRoute.isEmpty
        ? null
        : widget.recommendedRoute[_focusedIndex];

    return Container(
      height: 220,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE8E8E8))),
      ),
      child: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: focusedSpot?.position ?? _center,
          initialZoom: 16.5,
          minZoom: 14.0,
          maxZoom: 19.0,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.seoulland.app',
          ),
          // 경로 선
          if (widget.recommendedRoute.length > 1)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: widget.recommendedRoute.map((s) => s.position).toList(),
                  color: const Color(0xFFE60012).withValues(alpha: 0.75),
                  strokeWidth: 3.5,
                  pattern: StrokePattern.dashed(segments: const [12, 6]),
                ),
              ],
            ),
          // 스팟 마커
          MarkerLayer(
            markers: widget.recommendedRoute.asMap().entries.map((entry) {
              final idx = entry.key;
              final spot = entry.value;
              final isFocused = idx == _focusedIndex;

              return Marker(
                point: spot.position,
                width: isFocused ? 80 : 60,
                height: isFocused ? 60 : 48,
                child: GestureDetector(
                  onTap: () {
                    setState(() => _focusedIndex = idx);
                    _mapController.move(spot.position, 17.5);
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 순서 번호 + 이름
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isFocused
                              ? _categoryColor(spot.category)
                              : Colors.white.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Text(
                          '${idx + 1}. ${spot.name}',
                          style: TextStyle(
                            fontSize: isFocused ? 9 : 8,
                            fontWeight: FontWeight.w800,
                            color: isFocused ? Colors.white : const Color(0xFF1F1F1F),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        width: isFocused ? 32 : 26,
                        height: isFocused ? 32 : 26,
                        decoration: BoxDecoration(
                          color: _categoryColor(spot.category),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: isFocused
                              ? [BoxShadow(
                                  color: _categoryColor(spot.category).withValues(alpha: 0.4),
                                  blurRadius: 8, spreadRadius: 2,
                                )]
                              : null,
                        ),
                        child: Center(
                          child: Text(spot.icon, style: TextStyle(fontSize: isFocused ? 16 : 12)),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteList() {
    return FadeTransition(
      opacity: _fadeAnim,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: widget.recommendedRoute.length,
        itemBuilder: (context, index) {
          final spot = widget.recommendedRoute[index];
          final isFocused = index == _focusedIndex;
          final color = _categoryColor(spot.category);

          return GestureDetector(
            onTap: () {
              setState(() => _focusedIndex = index);
              _mapController.move(spot.position, 17.5);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isFocused ? color.withValues(alpha: 0.06) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isFocused ? color : const Color(0xFFEEEEEE),
                  width: isFocused ? 1.5 : 1,
                ),
                boxShadow: isFocused
                    ? [BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 12, offset: const Offset(0, 4))]
                    : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Row(
                children: [
                  // 순서 번호 원
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: isFocused ? color : const Color(0xFFF0F0F0),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: isFocused ? Colors.white : const Color(0xFF888888),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // 아이콘
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(spot.icon, style: const TextStyle(fontSize: 22)),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // 정보
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                spot.name,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: isFocused ? color : const Color(0xFF1F1F1F),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (spot.hasEasterEgg)
                              const Text('🥚 ', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _categoryLabel(spot.category),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: color,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.location_on_rounded, size: 11, color: Color(0xFF999999)),
                            const SizedBox(width: 2),
                            Flexible(
                              child: Text(
                                spot.zone,
                                style: const TextStyle(fontSize: 11, color: Color(0xFF999999)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, size: 12, color: Color(0xFFFFB300)),
                            const SizedBox(width: 3),
                            Text(
                              spot.rating.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF444444),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.schedule_rounded, size: 12, color: Color(0xFF9E9E9E)),
                            const SizedBox(width: 3),
                            Text(
                              '${spot.visitDurationMin}분',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF888888)),
                            ),
                            if (spot.waitTime != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                width: 7, height: 7,
                                decoration: BoxDecoration(
                                  color: spot.waitTime == '없음'
                                      ? const Color(0xFF4CAF50)
                                      : const Color(0xFFFFB300),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '대기 ${spot.waitTime}',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF888888)),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  // 상세보기 버튼
                  GestureDetector(
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => SpotDetailSheet(spot: spot),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F0F0),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: Color(0xFF666666),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
