import 'dart:async';
import 'dart:io' show Platform;

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GeofenceTarget {
  final String id;
  final String name;
  final LatLng position;
  const GeofenceTarget({required this.id, required this.name, required this.position});
}

typedef GeofenceEnterHandler = Future<void> Function(GeofenceTarget target, Position position);

/// 어트랙션 좌표 반경 진입 감지. 동일 타깃 당일 1회만 트리거.
class GeofenceService {
  GeofenceService({
    required this.targets,
    required this.onEnter,
    this.radiusMeters = 20.0,
  });

  List<GeofenceTarget> targets;
  final GeofenceEnterHandler onEnter;
  final double radiusMeters;

  static const _distance = Distance();
  static const _prefsKey = 'geofence_fired';

  StreamSubscription<Position>? _sub;
  bool _background = false;
  Set<String> _firedToday = {};
  String _todayKey = '';

  Future<bool> _ensurePermission() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    return perm != LocationPermission.denied && perm != LocationPermission.deniedForever;
  }

  static String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _loadFiredSet() async {
    final today = _dateKey(DateTime.now());
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_prefsKey) ?? const [];
    final fresh = stored.where((s) => s.startsWith('$today|')).toList();
    if (fresh.length != stored.length) {
      await prefs.setStringList(_prefsKey, fresh);
    }
    _todayKey = today;
    _firedToday = fresh.map((s) => s.split('|').last).toSet();
  }

  Future<void> _persistFired(String attractionId) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_prefsKey) ?? const [];
    final next = [...stored, '$_todayKey|$attractionId'];
    await prefs.setStringList(_prefsKey, next);
  }

  LocationSettings _buildSettings(bool background) {
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: background ? LocationAccuracy.medium : LocationAccuracy.high,
        distanceFilter: background ? 100 : 5,
        intervalDuration: Duration(seconds: background ? 60 : 5),
        foregroundNotificationConfig: background
            ? const ForegroundNotificationConfig(
                notificationTitle: '서울랜드 동선 추적 중',
                notificationText: '이스터에그 발견을 위해 위치를 추적하고 있어요',
                enableWakeLock: false,
              )
            : null,
      );
    }
    if (Platform.isIOS || Platform.isMacOS) {
      // iOS: 백그라운드는 Significant-change 유사 동작을 위해 distanceFilter 100 + activityType=other
      return AppleSettings(
        accuracy: background ? LocationAccuracy.medium : LocationAccuracy.high,
        distanceFilter: background ? 100 : 5,
        activityType: ActivityType.other,
        pauseLocationUpdatesAutomatically: !background,
        allowBackgroundLocationUpdates: background,
        showBackgroundLocationIndicator: false,
      );
    }
    return LocationSettings(
      accuracy: background ? LocationAccuracy.medium : LocationAccuracy.high,
      distanceFilter: background ? 100 : 5,
    );
  }

  /// [background]=true 면 저전력 트래킹(distanceFilter 100m) 모드.
  Future<void> start({bool background = false}) async {
    if (!await _ensurePermission()) return;
    await _loadFiredSet();

    if (_sub != null && _background == background) return; // 같은 모드 재시작 방지
    await _sub?.cancel();
    _background = background;

    _sub = Geolocator.getPositionStream(locationSettings: _buildSettings(background))
        .listen(_onPosition, onError: (_) {/* swallow & keep stream alive */});
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }

  /// 외부(Map screen 등)에서 lifecycle 변화에 따라 호출.
  Future<void> switchMode({required bool background}) async {
    await start(background: background);
  }

  void updateTargets(List<GeofenceTarget> next) {
    targets = next;
  }

  Future<void> _onPosition(Position p) async {
    final today = _dateKey(DateTime.now());
    if (today != _todayKey) {
      // 자정 넘김: 당일 fired set 리로드
      await _loadFiredSet();
    }

    final here = LatLng(p.latitude, p.longitude);
    for (final t in targets) {
      if (_firedToday.contains(t.id)) continue;
      final d = _distance.as(LengthUnit.Meter, here, t.position);
      if (d <= radiusMeters) {
        _firedToday.add(t.id);
        await _persistFired(t.id);
        try {
          await onEnter(t, p);
        } catch (_) {
          // 외부 핸들러 실패는 dedup을 되돌리지 않음 (중복 호출 방지가 우선)
        }
      }
    }
  }
}
