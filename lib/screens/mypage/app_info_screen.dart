import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../widgets/design/v3_sub_header.dart';

/// 정적 앱 정보 — 버전·라이선스·문의처 placeholder.
class AppInfoScreen extends StatelessWidget {
  const AppInfoScreen({super.key});

  // TODO: pubspec 의 version 을 package_info_plus 로 자동 주입.
  static const String _version = '0.1.0 BETA';

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            V3SubHeader(eyebrow: 'SETTINGS · ABOUT', title: l.app_info_title),
            const SizedBox(height: 8),
            _InfoCard(
              label: l.app_info_service,
              value: 'Re·Trace',
              sub: l.app_info_service_desc,
            ),
            const SizedBox(height: 12),
            _InfoCard(label: l.app_info_version, value: _version),
            const SizedBox(height: 12),
            _InfoCard(
              label: l.app_info_dev,
              value: l.app_info_dev_team,
            ),
            const SizedBox(height: 12),
            _LinkCard(
              label: l.app_info_oss_license,
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l.app_info_oss_coming)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  const _InfoCard({required this.label, required this.value, this.sub});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              )),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              )),
          if (sub != null) ...[
            const SizedBox(height: 4),
            Text(sub!,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                )),
          ],
        ],
      ),
    );
  }
}

class _LinkCard extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _LinkCard({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Text(label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                )),
            const Spacer(),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
