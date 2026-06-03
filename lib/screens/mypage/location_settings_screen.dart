import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../l10n/generated/app_localizations.dart';
import 'package:geolocator/geolocator.dart';

import '../../models/user_preferences.dart';
import '../../services/preferences_service.dart';
import '../../widgets/design/v3_sub_header.dart';

/// 위치 정보 화면 — OS 권한과 앱 토글 양방향 동기화.
/// OS 권한 거부 시 토글 자동 OFF + "설정 열기" 안내.
class LocationSettingsScreen extends StatefulWidget {
  const LocationSettingsScreen({super.key});

  @override
  State<LocationSettingsScreen> createState() =>
      _LocationSettingsScreenState();
}

class _LocationSettingsScreenState extends State<LocationSettingsScreen>
    with WidgetsBindingObserver {
  final _prefs = PreferencesService.instance;
  UserPreferences _state = UserPreferences.defaults;
  LocationPermission _osPerm = LocationPermission.denied;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    // 설정 화면에서 돌아왔을 때 권한 재확인.
    if (s == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final p = await _prefs.read();
    final perm = await Geolocator.checkPermission();
    if (!mounted) return;
    setState(() {
      _state = p;
      _osPerm = perm;
      _loading = false;
    });
    // OS 권한 거부인데 토글 ON 상태면 자동 OFF 정합 처리.
    if (!_isPermGranted && p.locationTrackingEnabled) {
      await _prefs.update(p.copyWith(locationTrackingEnabled: false));
    }
  }

  bool get _isPermGranted =>
      _osPerm == LocationPermission.always ||
      _osPerm == LocationPermission.whileInUse;

  bool get _isPermPermDenied =>
      _osPerm == LocationPermission.deniedForever;

  Future<void> _onToggle(bool turnOn) async {
    if (!turnOn) {
      await _prefs.update(_state.copyWith(locationTrackingEnabled: false));
      setState(() => _state = _prefs.current);
      return;
    }
    // ON 시도: OS 권한 확보.
    var perm = _osPerm;
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (!mounted) return;
    setState(() => _osPerm = perm);
    if (perm == LocationPermission.always ||
        perm == LocationPermission.whileInUse) {
      await _prefs.update(_state.copyWith(locationTrackingEnabled: true));
      setState(() => _state = _prefs.current);
    }
    // 영구거부면 토글은 OFF 유지, 사용자가 설정에서 직접 허용해야 함.
  }

  Future<void> _openSystemSettings() async {
    await Geolocator.openAppSettings();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                V3SubHeader(eyebrow: 'SETTINGS · GPS', title: l.location_title),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.bgCard,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(l.location_title,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.textPrimary,
                                    )),
                                const SizedBox(height: 4),
                                Text(
                                  l.location_purpose,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch.adaptive(
                            value: _state.locationTrackingEnabled &&
                                _isPermGranted,
                            onChanged: _onToggle,
                            activeColor: AppColors.ink900,
                          ),
                        ],
                      ),
                      const Divider(height: 24, color: AppColors.line),
                      _PermStatusRow(
                        granted: _isPermGranted,
                        permanentlyDenied: _isPermPermDenied,
                        onOpenSettings: _openSystemSettings,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                // TODO: 법무 검토 필요 — 위치정보 이용약관 정식 텍스트 교체.
                InkWell(
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l.location_terms_coming)),
                  ),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.bgCard,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Text(l.location_terms_view,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            )),
                        const Spacer(),
                        const Icon(Icons.chevron_right_rounded,
                            color: AppColors.textSecondary),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      ),
    );
  }
}

class _PermStatusRow extends StatelessWidget {
  final bool granted;
  final bool permanentlyDenied;
  final VoidCallback onOpenSettings;
  const _PermStatusRow({
    required this.granted,
    required this.permanentlyDenied,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context)!;
    if (granted) {
      return Row(
        children: [
          const Icon(Icons.check_circle_rounded,
              size: 18, color: AppColors.mint),
          const SizedBox(width: 6),
          Text(l.location_os_granted,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.mint,
              )),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                size: 18, color: AppColors.red),
            const SizedBox(width: 6),
            Expanded(
              child: Text(l.location_os_denied,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.red,
                  )),
            ),
          ],
        ),
        if (permanentlyDenied) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onOpenSettings,
            icon: const Icon(Icons.settings_rounded, size: 16),
            label: Text(AppL10n.of(context)!.location_open_settings),
            style: OutlinedButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              side: const BorderSide(color: AppColors.line),
              foregroundColor: AppColors.textPrimary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ],
    );
  }
}
