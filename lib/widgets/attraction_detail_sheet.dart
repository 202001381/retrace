import 'package:flutter/material.dart';

import '../models/attraction.dart';
import '../services/easter_egg_service.dart';

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
        return const Color(0xFFFF6D00);
      default:
        return const Color(0xFFE60012);
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
        color: Colors.white,
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
                decoration: BoxDecoration(color: const Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Row(
              children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    color: _catColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: Text(a.icon, style: const TextStyle(fontSize: 28)),
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
                              style: const TextStyle(fontSize: 11, color: Color(0xFF888888), fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(a.name,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1F1F1F))),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Color(0xFF888888)),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFF5F5F5),
                    minimumSize: const Size(32, 32),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(a.description,
                style: const TextStyle(fontSize: 13, color: Color(0xFF555555), height: 1.6)),
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
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text('$icon $text',
          style: const TextStyle(fontSize: 11, color: Color(0xFF555555), fontWeight: FontWeight.w700)),
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
    final bg = discovered ? const Color(0xFFF0F0F0) : const Color(0xFFFFF5F0);
    final border = discovered ? const Color(0xFFCCCCCC) : const Color(0xFFE60012);
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
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFFE60012))),
          const SizedBox(height: 4),
          const Text('이 어트랙션에 숨겨진 이야기가 있어요',
              style: TextStyle(fontSize: 13, color: Color(0xFF666666))),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE60012),
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
      backgroundColor: const Color(0xFF1E2B4A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            SizedBox(
              width: 32, height: 32,
              child: CircularProgressIndicator(color: Color(0xFFF4B633), strokeWidth: 3),
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
class _NarrativePopup extends StatelessWidget {
  final Attraction attraction;
  final String narrative;
  const _NarrativePopup({required this.attraction, required this.narrative});

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: const Color(0xFF1E2B4A),
      child: SafeArea(
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
              const Text('✦ AI SCANNED',
                  style: TextStyle(color: Color(0xFFF4B633), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
              const SizedBox(height: 18),
              Text(attraction.icon, style: const TextStyle(fontSize: 64)),
              const SizedBox(height: 14),
              Text(attraction.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  narrative,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.7),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF4B633),
                    foregroundColor: const Color(0xFF1E2B4A),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('확인', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
