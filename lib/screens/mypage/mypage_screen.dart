import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

import '../../services/easter_egg_service.dart';
import '../../services/onboarding_service.dart';
import 'app_info_screen.dart';
import 'location_settings_screen.dart';
import 'notification_settings_screen.dart';

/// 마이페이지 — 프로필 요약 + 4개 설정 메뉴 + 푸터.
/// 결제 내역·약관·건의는 placeholder (각각 별도 작업 / 백엔드·법무·피드백 시스템 의존).
class MypageScreen extends StatefulWidget {
  /// 온보딩 다시하기 — 부모(HomeScreen 트리)에서 OnboardingService.reset() + 라우팅.
  final VoidCallback? onResetOnboarding;
  const MypageScreen({super.key, this.onResetOnboarding});

  @override
  State<MypageScreen> createState() => _MypageScreenState();
}

class _MypageScreenState extends State<MypageScreen> {
  // kAttractions 중 hasEasterEgg=true 개수 (현재 18).
  static const int _kTotalEggCount = 18;

  SurveyAnswers? _survey;
  int _discoveredEggs = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await OnboardingService.read();
    final eggs = await EasterEggService.discoveredAll();
    if (!mounted) return;
    setState(() {
      _survey = s;
      _discoveredEggs = eggs.length;
    });
  }

  String? get _surveySummary {
    final s = _survey;
    if (s == null || s.total == 0) return null;
    final parts = <String>['${s.total}명'];
    if (s.purpose != null) parts.add(s.purpose!);
    if (s.favoriteType != null) parts.add(s.favoriteType!);
    return parts.join(' · ');
  }

  void _push(Widget screen) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => screen));
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text('마이페이지',
            style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: AppColors.cardWhite,
        elevation: 0.5,
        foregroundColor: AppColors.textPrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
        children: [
          // 프로필 row
          Container(
            color: AppColors.cardWhite,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        color: AppColors.border,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Text('👤', style: TextStyle(fontSize: 26)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('게스트',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textPrimary,
                              )),
                          const SizedBox(height: 4),
                          Text(
                            _surveySummary ?? '온보딩 답변 없음',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: widget.onResetOnboarding == null
                      ? null
                      : () {
                          Navigator.of(context).pop();
                          widget.onResetOnboarding!();
                        },
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('온보딩 다시하기'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.lunaNavy,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    textStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // 설정 메뉴
          _MenuGroup(items: [
            _MenuItem(
              icon: '🔔',
              label: '알림 설정',
              onTap: () => _push(const NotificationSettingsScreen()),
            ),
            _MenuItem(
              icon: '📍',
              label: '위치 정보',
              onTap: () => _push(const LocationSettingsScreen()),
            ),
            _MenuItem(
              icon: '💳',
              label: '결제 내역',
              trailing: const _PlaceholderTag(),
              onTap: () => _snack('결제 내역 (준비 중 — 백엔드 연동 필요)'),
            ),
            _MenuItem(
              icon: '✨',
              label: '내 이스터에그',
              trailing: Text(
                '$_discoveredEggs / $_kTotalEggCount',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.discoveryPurple,
                ),
              ),
              onTap: () => _snack('Archive 탭에서 확인하세요'),
            ),
          ]),
          const SizedBox(height: 12),
          _MenuGroup(items: [
            _MenuItem(
              icon: '📜',
              label: '약관 및 정책',
              trailing: const _PlaceholderTag(),
              onTap: () => _snack('약관 페이지 (준비 중 — 법무 검토 후 공개)'),
            ),
            _MenuItem(
              icon: 'ℹ️',
              label: '앱 정보',
              onTap: () => _push(const AppInfoScreen()),
            ),
          ]),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: OutlinedButton(
              onPressed: () => _snack('건의·피드백 수집 채널 (준비 중)'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: const BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                textStyle: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w800),
              ),
              child: const Text('건의·피드백 보내기'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuGroup extends StatelessWidget {
  final List<_MenuItem> items;
  const _MenuGroup({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.cardWhite,
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            items[i],
            if (i != items.length - 1)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Divider(height: 1, color: AppColors.border),
              ),
          ],
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final String icon;
  final String label;
  final Widget? trailing;
  final VoidCallback onTap;
  const _MenuItem({
    required this.icon,
    required this.label,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  )),
            ),
            if (trailing != null) ...[
              trailing!,
              const SizedBox(width: 6),
            ],
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderTag extends StatelessWidget {
  const _PlaceholderTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.border),
      ),
      child: const Text('준비 중',
          style: TextStyle(
            fontSize: 10,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w800,
          )),
    );
  }
}
