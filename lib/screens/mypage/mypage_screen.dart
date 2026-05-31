import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

import '../../services/easter_egg_service.dart';
import '../../services/onboarding_service.dart';
import '../../widgets/design/condition_pip.dart';
import 'app_info_screen.dart';
import 'location_settings_screen.dart';
import 'notification_settings_screen.dart';

/// 마이페이지 v3 — 블루→그레이프 그라디언트 프로필 카드 + 18칸 에그 dot grid + 컬러 설정 리스트.
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
    final avgMin = _survey?.total == null ? '—' : '44분';
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: ListView(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 32),
        children: [
          // ── 헤더 ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Eyebrow('MY · RE·TRACE'),
                SizedBox(height: 6),
                Text(
                  '마이페이지',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.0,
                    color: AppColors.ink900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // ── 프로필 그라디언트 카드 ───────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: _ProfileGradientCard(
              surveySummary: _surveySummary,
              eggsDiscovered: _discoveredEggs,
              eggsTotal: _kTotalEggCount,
              avgMinLabel: avgMin,
              partyCount: _survey?.total ?? 0,
            ),
          ),
          const SizedBox(height: 14),
          // ── 이스터에그 진행 ─────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: _EggProgressCard(
              discovered: _discoveredEggs,
              total: _kTotalEggCount,
            ),
          ),
          const SizedBox(height: 14),
          // ── 설정 리스트 (컬러 아이콘 박스) ───────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: _SettingsCard(rows: [
              _SettingsRow(
                icon: Icons.refresh_rounded,
                label: '온보딩 다시하기',
                sub: '취향 다시 받기',
                tint: _IconTint.red,
                onTap: widget.onResetOnboarding == null
                    ? null
                    : () {
                        Navigator.of(context).pop();
                        widget.onResetOnboarding!();
                      },
              ),
              _SettingsRow(
                icon: Icons.notifications_none_rounded,
                label: '알림 설정',
                tint: _IconTint.blue,
                onTap: () => _push(const NotificationSettingsScreen()),
              ),
              _SettingsRow(
                icon: Icons.location_on_outlined,
                label: '위치 정보',
                tint: _IconTint.mint,
                onTap: () => _push(const LocationSettingsScreen()),
              ),
              _SettingsRow(
                icon: Icons.credit_card_rounded,
                label: '결제 내역',
                badge: '준비 중',
                tint: _IconTint.yellow,
                onTap: () => _snack('결제 내역 (준비 중 — 백엔드 연동 필요)'),
              ),
              _SettingsRow(
                icon: Icons.description_outlined,
                label: '약관 및 정책',
                badge: '준비 중',
                tint: _IconTint.grape,
                onTap: () => _snack('약관 페이지 (준비 중 — 법무 검토 후 공개)'),
              ),
              _SettingsRow(
                icon: Icons.info_outline_rounded,
                label: '앱 정보',
                sub: 'v1.2.0 · build 0528',
                tint: _IconTint.blush,
                onTap: () => _push(const AppInfoScreen()),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          // ── 피드백 dashed button ────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: _DashedButton(
              label: '건의 · 피드백 보내기',
              onTap: () => _snack('건의·피드백 수집 채널 (준비 중)'),
            ),
          ),
        ],
        ),
      ),
    );
  }
}

// ─── 그라디언트 프로필 카드 ──────────────────────────────────
class _ProfileGradientCard extends StatelessWidget {
  final String? surveySummary;
  final int eggsDiscovered;
  final int eggsTotal;
  final String avgMinLabel;
  final int partyCount;
  const _ProfileGradientCard({
    required this.surveySummary,
    required this.eggsDiscovered,
    required this.eggsTotal,
    required this.avgMinLabel,
    required this.partyCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4D7AFF), Color(0xFF8B6CFF)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4D7AFF).withValues(alpha: 0.24),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            // 우상단 노란 글로우
            Positioned(
              top: -30,
              right: -20,
              child: Container(
                width: 140,
                height: 140,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: Alignment(-0.3, -0.3),
                    colors: [
                      Color(0xFFFFF5C7),
                      Color(0xFFFFCC2A),
                      Colors.transparent,
                    ],
                    stops: [0.0, 0.4, 0.7],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // 노랑 아바타 + 빨간 카운트 뱃지
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.yellow,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.6),
                                width: 3,
                              ),
                            ),
                            child: const Text(
                              'G',
                              style: TextStyle(
                                color: AppColors.ink900,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          if (partyCount > 0)
                            Positioned(
                              bottom: -2,
                              right: -2,
                              child: Container(
                                width: 22,
                                height: 22,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.red,
                                  border: Border.all(
                                      color: Colors.white, width: 2),
                                ),
                                child: Text(
                                  '$partyCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  '게스트',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.6,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'BETA',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              surveySummary ?? '온보딩 답변 없음',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // dashed divider
                  CustomPaint(
                    size: const Size(double.infinity, 1),
                    painter: _DashedLinePainter(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(child: _Stat(value: '${partyCount == 0 ? '—' : 3}', label: '누적 방문')),
                      Container(
                          width: 1, height: 32, color: Colors.white.withValues(alpha: 0.18)),
                      Expanded(
                          child: _Stat(value: '$eggsDiscovered / $eggsTotal', label: '이스터에그')),
                      Container(
                          width: 1, height: 32, color: Colors.white.withValues(alpha: 0.18)),
                      Expanded(child: _Stat(value: avgMinLabel, label: '평균 동선')),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  const _Stat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.75),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;
  _DashedLinePainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const dash = 4.0, gap = 4.0;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + dash, 0), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter o) => o.color != color;
}

// ─── 에그 진행 카드 (옐로우 박스 + 18칸 dot grid) ───────────
class _EggProgressCard extends StatelessWidget {
  final int discovered;
  final int total;
  const _EggProgressCard({required this.discovered, required this.total});

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : discovered / total;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.yellowTint,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.yellowDeep.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.egg_outlined,
                  size: 18, color: Color(0xFF8A6300)),
              const SizedBox(width: 8),
              const Text(
                '이스터에그 진행',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink900,
                ),
              ),
              const Spacer(),
              Text(
                '$discovered / $total',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.redDeep,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 진행 바
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: Stack(
              children: [
                Container(
                  height: 10,
                  color: const Color(0xFF8A6300).withValues(alpha: 0.12),
                ),
                FractionallySizedBox(
                  widthFactor: pct.clamp(0.0, 1.0),
                  child: Container(
                    height: 10,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.yellow, AppColors.red],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // 18칸 dot grid
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: List.generate(total, (i) {
              final filled = i < discovered;
              return Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: filled ? AppColors.red : Colors.transparent,
                  border: filled
                      ? null
                      : Border.all(
                          color: const Color(0xFFB5933D),
                          width: 1.5,
                          style: BorderStyle.solid,
                        ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ─── 설정 리스트 (컬러 아이콘 박스) ────────────────────────
enum _IconTint { red, blue, mint, yellow, grape, blush }

class _SettingsCard extends StatelessWidget {
  final List<_SettingsRow> rows;
  const _SettingsCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              rows[i],
              if (i < rows.length - 1)
                Container(height: 1, color: AppColors.lineDim),
            ],
          ],
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? sub;
  final String? badge;
  final _IconTint tint;
  final VoidCallback? onTap;
  const _SettingsRow({
    required this.icon,
    required this.label,
    required this.tint,
    this.sub,
    this.badge,
    this.onTap,
  });

  ({Color bg, Color fg}) _palette() {
    switch (tint) {
      case _IconTint.red:
        return (bg: AppColors.redTint, fg: AppColors.redDeep);
      case _IconTint.blue:
        return (bg: AppColors.blueTint, fg: AppColors.blueDeep);
      case _IconTint.mint:
        return (bg: AppColors.mintTint, fg: const Color(0xFF1E7754));
      case _IconTint.yellow:
        return (bg: AppColors.yellowTint, fg: const Color(0xFF8A6300));
      case _IconTint.grape:
        return (bg: AppColors.grapeTint, fg: const Color(0xFF5938C9));
      case _IconTint.blush:
        return (bg: AppColors.blushTint, fg: const Color(0xFFB5395A));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _palette();
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.bg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: c.fg),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink900,
                      letterSpacing: -0.2,
                    ),
                  ),
                  if (sub != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      sub!,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.ink500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (badge != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: AppColors.lineStrong),
                ),
                child: Text(
                  badge!,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            const Icon(Icons.chevron_right_rounded,
                size: 16, color: AppColors.ink300),
          ],
        ),
      ),
    );
  }
}

class _DashedButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _DashedButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: CustomPaint(
        painter: _DashedBorderPainter(color: AppColors.red),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.auto_awesome_outlined,
                  size: 14, color: AppColors.red),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.redDeep,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  _DashedBorderPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(14),
    );
    final path = Path()..addRRect(rect);
    // Dashed traversal
    final metrics = path.computeMetrics();
    const dash = 6.0, gap = 5.0;
    for (final m in metrics) {
      double d = 0;
      while (d < m.length) {
        final end = (d + dash).clamp(0.0, m.length);
        canvas.drawPath(m.extractPath(d, end), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter o) => o.color != color;
}
