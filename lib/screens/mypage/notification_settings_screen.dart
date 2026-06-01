import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

import '../../models/user_preferences.dart';
import '../../services/preferences_service.dart';
import '../../widgets/design/v3_sub_header.dart';
import 'marketing_consent_modal.dart';

/// 알림 설정 — 한국 법규 분리 요건에 맞춰 3개 섹션 (서비스 / 한산 / 마케팅).
/// 카카오·SMS 채널은 마케팅 동의가 게이트.
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  final _prefs = PreferencesService.instance;
  UserPreferences _state = UserPreferences.defaults;

  @override
  void initState() {
    super.initState();
    _state = _prefs.current;
    _prefs.listenable.addListener(_onPrefsChanged);
    _load();
  }

  Future<void> _load() async {
    final s = await _prefs.read();
    if (!mounted) return;
    setState(() => _state = s);
  }

  void _onPrefsChanged() {
    if (!mounted) return;
    setState(() => _state = _prefs.listenable.value);
  }

  @override
  void dispose() {
    _prefs.listenable.removeListener(_onPrefsChanged);
    super.dispose();
  }

  Future<void> _apply(UserPreferences next) async {
    setState(() => _state = next);
    await _prefs.update(next);
  }

  Future<void> _toggleMarketing(bool turnOn) async {
    if (turnOn) {
      final agreed = await showMarketingConsentModal(context);
      if (!agreed) return;
      await _apply(_state.copyWith(
        marketingConsent: true,
        marketingConsentAt: DateTime.now(),
      ));
    } else {
      // OFF 시: 동의 시각 유지(감사 추적), 광고성 채널만 정리.
      final cleared = _state
          .copyWith(marketingConsent: false)
          .withoutAdChannels();
      await _apply(cleared);
    }
  }

  Future<void> _toggleChannel(AlertChannel c, bool on) async {
    final next = {..._state.lowCrowdChannels};
    if (on) {
      next.add(c);
    } else {
      next.remove(c);
    }
    await _apply(_state.copyWith(lowCrowdChannels: next));
  }

  @override
  Widget build(BuildContext context) {
    final s = _state;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            const V3SubHeader(eyebrow: 'SETTINGS · NOTIFY', title: '알림 설정'),
            const SizedBox(height: 8),
          // ── 서비스 알림 ─────────────────────────────────────
          _SectionCard(
            title: '서비스 알림',
            child: _ToggleRow(
              title: '앱 푸시 알림',
              subtitle:
                  '· 마이 루나 동선 업데이트\n· 이스터에그 발견 알림\n· 이벤트 시작 알림',
              value: s.appPushEnabled,
              onChanged: (v) => _apply(s.copyWith(appPushEnabled: v)),
            ),
          ),
          const SizedBox(height: 14),
          // ── 한산 알림 ───────────────────────────────────────
          _SectionCard(
            title: '한산 알림',
            badge: '⭐',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ToggleRow(
                  title: '비수기·날씨 한산 알림',
                  subtitle: 'AI가 서울랜드 한산 예측 시 알려드려요',
                  value: s.lowCrowdAlertEnabled,
                  onChanged: (v) =>
                      _apply(s.copyWith(lowCrowdAlertEnabled: v)),
                ),
                if (s.lowCrowdAlertEnabled) ...[
                  const Divider(height: 24, color: AppColors.line),
                  const Padding(
                    padding: EdgeInsets.only(left: 4, bottom: 8),
                    child: Text('발송 채널 (중복 선택)',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        )),
                  ),
                  _ChannelCheck(
                    label: '앱 푸시',
                    value: s.lowCrowdChannels.contains(AlertChannel.appPush),
                    enabled: true,
                    onChanged: (v) =>
                        _toggleChannel(AlertChannel.appPush, v ?? false),
                  ),
                  _ChannelCheck(
                    label: '카카오 알림톡',
                    value: s.lowCrowdChannels.contains(AlertChannel.kakao),
                    enabled: s.canUseKakaoOrSms,
                    onChanged: (v) =>
                        _toggleChannel(AlertChannel.kakao, v ?? false),
                  ),
                  _ChannelCheck(
                    label: 'SMS',
                    value: s.lowCrowdChannels.contains(AlertChannel.sms),
                    enabled: s.canUseKakaoOrSms,
                    onChanged: (v) =>
                        _toggleChannel(AlertChannel.sms, v ?? false),
                  ),
                  if (!s.canUseKakaoOrSms)
                    const Padding(
                      padding: EdgeInsets.only(left: 4, top: 6),
                      child: Text(
                        '※ 카카오·SMS 채널은 마케팅 정보 수신 동의 후 사용 가능합니다',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          // ── 마케팅 ──────────────────────────────────────────
          _SectionCard(
            title: '마케팅 정보 수신',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ToggleRow(
                  title: '할인 쿠폰·이벤트 광고',
                  subtitle: '💡 동의 시 한산 알림 + 추가 할인 쿠폰을 받을 수 있어요',
                  value: s.marketingConsent,
                  onChanged: _toggleMarketing,
                ),
                const SizedBox(height: 6),
                _LinkRow(
                  label: '동의 내용 자세히 보기',
                  onTap: () => showMarketingConsentModal(context),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 4),
                  child: Text(
                    '마지막 동의: ${_fmtConsentAt(s.marketingConsentAt)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  static String _fmtConsentAt(DateTime? at) {
    if (at == null) return '-';
    final y = at.year.toString().padLeft(4, '0');
    final m = at.month.toString().padLeft(2, '0');
    final d = at.day.toString().padLeft(2, '0');
    return '$y.$m.$d';
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String? badge;
  final Widget child;
  const _SectionCard({required this.title, this.badge, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
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
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Text(title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    )),
                if (badge != null) ...[
                  const SizedBox(width: 4),
                  Text(badge!, style: const TextStyle(fontSize: 13)),
                ],
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  )),
              const SizedBox(height: 4),
              Text(subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                  )),
            ],
          ),
        ),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeColor: AppColors.ink900,
        ),
      ],
    );
  }
}

class _ChannelCheck extends StatelessWidget {
  final String label;
  final bool value;
  final bool enabled;
  final ValueChanged<bool?> onChanged;
  const _ChannelCheck({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: InkWell(
        onTap: enabled ? () => onChanged(!value) : null,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Checkbox(
                value: value,
                onChanged: enabled ? onChanged : null,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              const SizedBox(width: 4),
              Text(label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _LinkRow({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            Text(label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink900,
                  decoration: TextDecoration.underline,
                )),
            const SizedBox(width: 2),
            const Icon(Icons.chevron_right_rounded,
                size: 14, color: AppColors.ink900),
          ],
        ),
      ),
    );
  }
}
