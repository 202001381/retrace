import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

import '../models/attraction.dart';
import '../services/easter_egg_service.dart';
import 'design/stamp.dart';

/// 지도 마커/카드 탭 시 표시되는 어트랙션 상세 시트.
class AttractionDetailSheet extends StatefulWidget {
  final Attraction attraction;
  final VoidCallback? onNavigate;
  final bool isNavigating;
  final int? walkMinutes;

  const AttractionDetailSheet({
    super.key,
    required this.attraction,
    this.onNavigate,
    this.isNavigating = false,
    this.walkMinutes,
  });

  @override
  State<AttractionDetailSheet> createState() => _AttractionDetailSheetState();
}

class _AttractionDetailSheetState extends State<AttractionDetailSheet> {
  bool _eggDiscovered = false;
  bool _eggLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.attraction.hasEasterEgg) {
      EasterEggService.isDiscovered(widget.attraction.id).then((v) {
        if (mounted) setState(() => _eggDiscovered = v);
      });
    }
  }

  Color get _catColor {
    switch (widget.attraction.category) {
      case '음식점':
        return AppColors.yellow;
      default:
        return AppColors.red;
    }
  }

  Future<void> _onEasterEggTap() async {
    setState(() => _eggLoading = true);
    // 로딩 다이얼로그
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _LunaLoadingDialog(),
    );
    // Claude API 호출 자리 — 실제로는 NarrativeService.generate(...) 호출.
    // 데모용으로 1.4초 딜레이 후 스텁 서사 반환.
    await Future.delayed(const Duration(milliseconds: 1400));
    final narrative = _stubNarrative(widget.attraction);
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // 로딩 닫기

    // 발견 기록 저장
    await EasterEggService.markDiscovered(widget.attraction.id);
    if (mounted) setState(() {
      _eggDiscovered = true;
      _eggLoading = false;
    });

    // 전체화면 서사 팝업
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (_) => _NarrativePopup(
        attraction: widget.attraction,
        narrative: narrative,
      ),
    );
  }

  String _stubNarrative(Attraction a) {
    // TODO: NarrativeService 로 교체 — 백엔드 Claude API 호출.
    return '${a.name}. 1988년 개장 이후 38년간 수많은 발걸음이 만들어낸 서울랜드의 한 페이지입니다. 오늘 당신의 방문이 새로운 챕터를 더합니다 🌙';
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.attraction;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + MediaQuery.of(context).padding.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: AppColors.textSecondary, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Row(
              children: [
                Stamp(
                  code: Stamp.codeFromName(a.name),
                  tone: Stamp.toneFromHints(
                    category: a.category,
                    thrillLevel: a.thrillLevel,
                    hasEasterEgg: a.hasEasterEgg,
                  ),
                  size: 56,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: _catColor, borderRadius: BorderRadius.circular(99)),
                            child: Text(a.category,
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                          ),
                          const SizedBox(width: 6),
                          Text(a.zone,
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(a.name,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textPrimary, letterSpacing: -0.5)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.line,
                    minimumSize: const Size(32, 32),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // v3 — 이미지 strip (placeholder 3장)
            SizedBox(
              height: 88,
              child: ListView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                children: List.generate(3, (i) {
                  return Container(
                    width: 130,
                    margin: EdgeInsets.only(right: i == 2 ? 0 : 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: i.isEven
                            ? [const Color(0xFFEDDFBF), const Color(0xFFE2CF99)]
                            : [const Color(0xFFF8D8C0), const Color(0xFFF1C49E)],
                      ),
                    ),
                    alignment: Alignment.bottomLeft,
                    padding: const EdgeInsets.all(10),
                    child: Text(
                      i == 0
                          ? 'PHOTO · MAIN'
                          : i == 1
                              ? 'PHOTO · ZONE'
                              : 'PHOTO · DETAIL',
                      style: const TextStyle(
                        color: Color(0xFF7A5715),
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 14),
            Text(a.description,
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.6)),
            const SizedBox(height: 14),
            Row(
              children: [
                _InfoChip(icon: '⏱', text: '대기 ${a.waitMinutes}분'),
                const SizedBox(width: 6),
                _InfoChip(icon: '⭐', text: '${a.rating}'),
                if (a.heightLimit > 0) ...[
                  const SizedBox(width: 6),
                  _InfoChip(icon: '📏', text: '${a.heightLimit}cm+'),
                ],
                if (a.indoor) ...[
                  const SizedBox(width: 6),
                  _InfoChip(icon: '🏠', text: '실내'),
                ],
              ],
            ),
            const SizedBox(height: 16),
            if (widget.walkMinutes != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _catColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.directions_walk_rounded, size: 16, color: _catColor),
                    const SizedBox(width: 6),
                    Text('예상 도보 ${widget.walkMinutes}분',
                        style: TextStyle(color: _catColor, fontSize: 13, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: widget.onNavigate,
                icon: Icon(
                  widget.isNavigating ? Icons.hourglass_top_rounded : Icons.directions_walk_rounded,
                  size: 20,
                ),
                label: Text(widget.isNavigating ? '이동 중...' : '여기로 이동하기',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _catColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            // 이스터에그 섹션
            if (a.hasEasterEgg) ...[
              const SizedBox(height: 16),
              _EasterEggSection(
                discovered: _eggDiscovered,
                loading: _eggLoading,
                onTap: _eggLoading ? null : _onEasterEggTap,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String icon;
  final String text;
  const _InfoChip({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.bgPage,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text('$icon $text',
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
    );
  }
}

// ─── 이스터에그 섹션 ──────────────────────────────────────
class _EasterEggSection extends StatelessWidget {
  final bool discovered;
  final bool loading;
  final VoidCallback? onTap;
  const _EasterEggSection({required this.discovered, required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bg = discovered ? AppColors.bgCardWarm : AppColors.bgPage;
    final border = discovered ? AppColors.textSecondary : AppColors.red;
    final btnLabel = discovered ? '다시 듣기' : '이야기 들어보기';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(discovered ? '🌙 발견한 이야기' : '🌙 이스터에그 발견!',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.red)),
          const SizedBox(height: 4),
          const Text('이 어트랙션에 숨겨진 이야기가 있어요',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(btnLabel, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 로딩 다이얼로그 ───────────────────────────────────────
class _LunaLoadingDialog extends StatelessWidget {
  const _LunaLoadingDialog();
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.ink900,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            SizedBox(
              width: 32, height: 32,
              child: CircularProgressIndicator(color: AppColors.grape, strokeWidth: 3),
            ),
            SizedBox(height: 14),
            Text('🌙 루나가 이야기를 찾고 있어요...',
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

// ─── 전체화면 서사 팝업 ────────────────────────────────────
/// v3 이스터에그 발견 시퀀스 — 다크 라디얼 그라디언트 + 스파클 + 빨간 도장.
class _NarrativePopup extends StatelessWidget {
  final Attraction attraction;
  final String narrative;
  const _NarrativePopup({required this.attraction, required this.narrative});

  String get _today {
    final now = DateTime.now();
    return '${now.year}.${now.month.toString().padLeft(2, '0')}.${now.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: const Color(0xFF0A1631),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.2),
            radius: 0.95,
            colors: [Color(0xFF182849), Color(0xFF0A1631)],
          ),
        ),
        child: Stack(
          children: [
            // 산재된 별
            const Positioned.fill(child: _DarkStarField()),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white70),
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      '✦ EASTER EGG · DISCOVERED',
                      style: TextStyle(
                        color: AppColors.yellow,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.8,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // 큰 빨간 STAMPED 도장 — 살짝 기운 회전.
                    Transform.rotate(
                      angle: -0.12,
                      child: Container(
                        width: 180,
                        height: 180,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.red, width: 4),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.red.withValues(alpha: 0.55),
                              blurRadius: 40,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'STAMPED',
                              style: TextStyle(
                                color: AppColors.red,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              '발견!',
                              style: TextStyle(
                                color: AppColors.red,
                                fontSize: 38,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1.2,
                                height: 1.0,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              height: 1.5,
                              width: 60,
                              color: AppColors.red.withValues(alpha: 0.4),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _today,
                              style: TextStyle(
                                color: AppColors.red.withValues(alpha: 0.85),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      attraction.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: Text(
                        narrative,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.92),
                          fontSize: 14,
                          height: 1.65,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.red,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(99)),
                        ),
                        child: const Text(
                          '다음 동선 보기',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
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

class _DarkStarField extends StatelessWidget {
  const _DarkStarField();
  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _DarkStarPainter());
  }
}

class _DarkStarPainter extends CustomPainter {
  static const _stars = [
    [0.12, 0.18, 4.0, 0.9],
    [0.78, 0.14, 3.0, 0.7],
    [0.88, 0.32, 5.0, 0.85],
    [0.06, 0.36, 3.0, 0.6],
    [0.16, 0.68, 4.0, 0.8],
    [0.84, 0.62, 5.0, 0.75],
    [0.36, 0.86, 3.5, 0.65],
    [0.74, 0.88, 4.0, 0.7],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in _stars) {
      final cx = s[0] * size.width;
      final cy = s[1] * size.height;
      final r = s[2];
      final alpha = s[3];
      final paint = Paint()
        ..color = const Color(0xFFFFF5C7).withValues(alpha: alpha);
      final path = Path()
        ..moveTo(cx, cy - r * 2)
        ..lineTo(cx + r * 0.35, cy - r * 0.35)
        ..lineTo(cx + r * 2, cy)
        ..lineTo(cx + r * 0.35, cy + r * 0.35)
        ..lineTo(cx, cy + r * 2)
        ..lineTo(cx - r * 0.35, cy + r * 0.35)
        ..lineTo(cx - r * 2, cy)
        ..lineTo(cx - r * 0.35, cy - r * 0.35)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_DarkStarPainter o) => false;
}
