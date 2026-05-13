import 'package:flutter/material.dart';

import '../services/narrative_service.dart';

/// Claude API 서사 결과를 보여주는 풀스크린 모달.
/// 호출 측이 [NarrativeService.generate] Future 를 넘기면 로딩→결과/에러 UI 자동 전환.
class NarrativeModal extends StatelessWidget {
  final String attractionEmoji;
  final String attractionName;
  final Future<NarrativeResult> future;
  final VoidCallback? onCollect;

  const NarrativeModal({
    super.key,
    required this.attractionEmoji,
    required this.attractionName,
    required this.future,
    this.onCollect,
  });

  static Future<void> show(
    BuildContext context, {
    required String attractionEmoji,
    required String attractionName,
    required Future<NarrativeResult> future,
    VoidCallback? onCollect,
  }) {
    return showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => NarrativeModal(
        attractionEmoji: attractionEmoji,
        attractionName: attractionName,
        future: future,
        onCollect: onCollect,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E2D4E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF4B633), width: 2),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4B633).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: const Color(0xFFF4B633).withValues(alpha: 0.5)),
                  ),
                  child: const Text('✦ AI SCANNED',
                      style: TextStyle(color: Color(0xFFF4B633), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white70, size: 18),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    minimumSize: const Size(32, 32),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('숨겨진 기억의 조각 발견!',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, height: 1.2)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.30),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('[서사 텍스트]',
                      style: TextStyle(color: Color(0xFFFF6B6B), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                  const SizedBox(height: 8),
                  Text('$attractionEmoji $attractionName',
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 12),
                  FutureBuilder<NarrativeResult>(
                    future: future,
                    builder: (context, snap) {
                      if (snap.connectionState != ConnectionState.done) {
                        return const _NarrativeLoading();
                      }
                      if (snap.hasError) {
                        return Text(
                          '서사를 가져오지 못했어요. 잠시 후 다시 시도해주세요.\n(${snap.error})',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13, height: 1.5),
                        );
                      }
                      return Text(
                        snap.data!.narrative,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13, height: 1.6),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  onCollect?.call();
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF4B633),
                  foregroundColor: const Color(0xFF1E2D4E),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('📖 연대기(Chronicle)에 수집하기',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NarrativeLoading extends StatefulWidget {
  const _NarrativeLoading();
  @override
  State<_NarrativeLoading> createState() => _NarrativeLoadingState();
}

class _NarrativeLoadingState extends State<_NarrativeLoading> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(3, (i) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, __) {
              final t = ((_c.value + i * 0.15) % 1.0);
              final opacity = 0.25 + 0.5 * (1 - (t - 0.5).abs() * 2).clamp(0, 1);
              return Container(
                height: 12,
                width: i == 2 ? 140 : double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: opacity),
                  borderRadius: BorderRadius.circular(6),
                ),
              );
            },
          ),
        );
      }),
    );
  }
}
