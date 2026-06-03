import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme/app_colors.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/attraction.dart';
import '../../services/path_graph.dart';

/// "지금 출발" 모드 — 전체 화면 지도 + 큰 폰트 거리·방향.
/// 폰을 계속 보지 않아도 되는 UX: 도착 50m 진입 시 1회만 인앱 SnackBar 발화.
class MyLunaNavigateScreen extends StatefulWidget {
  final Attraction target;
  const MyLunaNavigateScreen({super.key, required this.target});

  @override
  State<MyLunaNavigateScreen> createState() => _MyLunaNavigateScreenState();
}

class _MyLunaNavigateScreenState extends State<MyLunaNavigateScreen> {
  static const double _kArrivalRadiusM = 50;
  static const LatLng _kGate = LatLng(37.4332, 127.0174);

  final MapController _mapCtrl = MapController();
  StreamSubscription<Position>? _posSub;
  LatLng? _myPos;
  bool _arrivalNotified = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _posSub?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm != LocationPermission.always &&
          perm != LocationPermission.whileInUse) {
        return; // GPS 없으면 정문 기준 정적 표시
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;
      setState(() => _myPos = LatLng(pos.latitude, pos.longitude));
      _fitCamera();
      _posSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 3,
        ),
      ).listen(_onPos);
    } catch (_) {/* 정문 fallback */}
  }

  void _onPos(Position p) {
    if (!mounted) return;
    final next = LatLng(p.latitude, p.longitude);
    setState(() => _myPos = next);
    _maybeNotifyArrival(next);
  }

  void _maybeNotifyArrival(LatLng pos) {
    if (_arrivalNotified) return;
    final m = _haversineMeters(pos, widget.target.position);
    if (m <= _kArrivalRadiusM) {
      _arrivalNotified = true;
      // 풀스크린 지도 위라도 보이도록 floating + behavior: floating 사용.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 40),
          backgroundColor: AppColors.ink900,
          duration: const Duration(seconds: 5),
          content: Text(
            AppL10n.of(context)!.nav_arrival_close(widget.target.name),
            style: const TextStyle(
              color: AppColors.bgCard,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      );
    }
  }

  // GPS 가 정문에서 1.5km 이상 떨어지면 "도착 전" → 정문 기준으로 안내.
  static const double _kRemoteThresholdM = 1500;

  void _fitCamera() {
    final from = _origin;
    final mid = LatLng(
      (from.latitude + widget.target.position.latitude) / 2,
      (from.longitude + widget.target.position.longitude) / 2,
    );
    _mapCtrl.move(mid, 17);
  }

  LatLng get _origin {
    final p = _myPos;
    if (p == null) return _kGate;
    return _haversineMeters(p, _kGate) <= _kRemoteThresholdM ? p : _kGate;
  }

  RouteResult get _routed =>
      PathGraph.route(_origin, widget.target.position);

  double get _distMeters => _routed.meters;

  int get _walkMin => _routed.walkMinutes;

  String get _bearingLabel {
    final from = _origin;
    final to = widget.target.position;
    final lat1 = from.latitude * math.pi / 180;
    final lat2 = to.latitude * math.pi / 180;
    final dLon = (to.longitude - from.longitude) * math.pi / 180;
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    final brng = (math.atan2(y, x) * 180 / math.pi + 360) % 360;
    const labels = ['북', '북동', '동', '남동', '남', '남서', '서', '북서'];
    final idx = ((brng + 22.5) ~/ 45) % 8;
    return labels[idx];
  }

  static String _fmtDist(double m) {
    if (m < 1000) return '${m.round()}m';
    return '${(m / 1000).toStringAsFixed(1)}km';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 지도 — 사용자 ↔ 목적지 polyline
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapCtrl,
              options: MapOptions(
                initialCenter: widget.target.position,
                initialZoom: 17,
                minZoom: 15,
                maxZoom: 19,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://api.vworld.kr/req/wmts/1.0.0/{apiKey}/Base/{z}/{y}/{x}.png',
                  additionalOptions: const {
                    'apiKey': String.fromEnvironment(
                      'VWORLD_KEY',
                      defaultValue:
                          '9783E3A8-A564-37C0-A9DC-42D67CAA8112',
                    ),
                  },
                  userAgentPackageName: 'com.seoulland.app',
                ),
                PolylineLayer(polylines: [
                  Polyline(
                    points: _routed.points,
                    color: AppColors.red,
                    strokeWidth: 5,
                  ),
                ]),
                MarkerLayer(markers: [
                  Marker(
                    point: widget.target.position,
                    width: 56,
                    height: 56,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(widget.target.icon,
                          style: const TextStyle(fontSize: 26)),
                    ),
                  ),
                  if (_myPos != null)
                    Marker(
                      point: _myPos!,
                      width: 28,
                      height: 28,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                    ),
                ]),
              ],
            ),
          ),

          // 상단 — 큰 폰트 거리/방향 카드
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _DistanceCard(
                  spotName: widget.target.name,
                  spotEmoji: widget.target.icon,
                  distance: _fmtDist(_distMeters),
                  bearing: _bearingLabel,
                  walkMin: _walkMin,
                  onBack: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ),

          // 하단 — "도착했어요" 또는 도움말
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          AppL10n.of(context)!.nav_arrival_hint,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DistanceCard extends StatelessWidget {
  final String spotName;
  final String spotEmoji;
  final String distance;
  final String bearing;
  final int walkMin;
  final VoidCallback onBack;
  const _DistanceCard({
    required this.spotName,
    required this.spotEmoji,
    required this.distance,
    required this.bearing,
    required this.walkMin,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              Text(spotEmoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(spotName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    )),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(distance,
                  style: const TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    height: 1,
                  )),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('· $bearing',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textSecondary,
                    )),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(AppL10n.of(context)!.nav_walk_eta_short(walkMin),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    )),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
