/// 풀스크린 보상 발급 모달 — "당장 사용하시겠습니까?" 형식.
/// 인커밍-콜 톤 (큰 글자, 두 개의 CTA, 코드는 사용 동의 후 노출).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_colors.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/reward.dart';
import '../services/rewards_service.dart';

class RewardUnlockModal extends StatefulWidget {
  final Reward reward;
  final int unlockedCount;
  final String uid;

  const RewardUnlockModal({
    super.key,
    required this.reward,
    required this.unlockedCount,
    required this.uid,
  });

  @override
  State<RewardUnlockModal> createState() => _RewardUnlockModalState();
}

class _RewardUnlockModalState extends State<RewardUnlockModal>
    with TickerProviderStateMixin {
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
        ..repeat(reverse: true);
  bool _redeeming = false;
  Reward? _redeemed;

  static const int _seasonTotal = 5; // chapterTargets 와 동일

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _useNow() async {
    if (_redeeming) return;
    setState(() => _redeeming = true);
    HapticFeedback.mediumImpact();
    final r = await RewardsService.instance.redeem(widget.uid, widget.reward.rewardId);
    if (!mounted) return;
    setState(() {
      _redeeming = false;
      _redeemed = r ?? widget.reward; // 백엔드 실패해도 코드 자체는 보여줌
    });
  }

  void _later() {
    HapticFeedback.selectionClick();
    Navigator.of(context).maybePop();
  }

  void _viewCode() {
    HapticFeedback.selectionClick();
    setState(() => _redeemed = widget.reward);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context)!;
    final isTicket = widget.reward.type == 'ticket';
    final accent = isTicket ? AppColors.yellow : AppColors.red;

    return Scaffold(
      backgroundColor: AppColors.ink900,
      body: SafeArea(
        child: _redeemed == null
            ? _buildOffer(l, isTicket, accent)
            : _buildCode(l, isTicket, accent, _redeemed!),
      ),
    );
  }

  Widget _buildOffer(AppL10n l, bool isTicket, Color accent) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 닫기 X — 작게 우상단.
          Align(
            alignment: Alignment.topRight,
            child: IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.close_rounded, color: Colors.white70),
            ),
          ),
          const Spacer(),
          // Eyebrow + 펄스.
          ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1.0).animate(
              CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: accent.withValues(alpha: 0.45)),
              ),
              child: Text(
                l.reward_unlock_eyebrow,
                style: TextStyle(
                  color: accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 큰 보상 타이틀
          Text(
            l.reward_unlock_title(widget.reward.type),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w900,
              height: 1.15,
              letterSpacing: -1.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            l.reward_unlock_subtitle(widget.unlockedCount, _seasonTotal),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 28),
          // CTA 질문 — 인커밍-콜 톤
          Text(
            l.reward_unlock_use_now_q,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
            ),
          ),
          const Spacer(),
          // ── 액션 두 줄 (지금 사용 → 나중에) ──
          _PrimaryAction(
            label: _redeeming ? '...' : l.reward_action_use_now,
            color: accent,
            onTap: _redeeming ? null : _useNow,
          ),
          const SizedBox(height: 10),
          _SecondaryAction(
            label: l.reward_action_view_code,
            onTap: _redeeming ? null : _viewCode,
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: _later,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white.withValues(alpha: 0.55),
              minimumSize: const Size.fromHeight(48),
            ),
            child: Text(l.reward_action_later,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildCode(AppL10n l, bool isTicket, Color accent, Reward r) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.topRight,
            child: IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.close_rounded, color: Colors.white70),
            ),
          ),
          const Spacer(),
          Text(
            l.reward_unlock_title(r.type),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l.reward_code_label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 18),
          // 코드 카드 — 매장 노출용
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: accent, width: 3),
            ),
            child: Column(
              children: [
                SelectableText(
                  r.code ?? '—',
                  style: TextStyle(
                    color: accent,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.0,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  l.reward_show_at_store,
                  style: const TextStyle(
                    color: AppColors.ink500,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (r.isRedeemed) ...[
                  const SizedBox(height: 8),
                  Text(
                    l.reward_already_redeemed,
                    style: const TextStyle(
                      color: AppColors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Spacer(),
          _PrimaryAction(
            label: l.common_ok,
            color: accent,
            onTap: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );
  }
}

class _PrimaryAction extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const _PrimaryAction({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: color == AppColors.yellow ? AppColors.ink900 : Colors.white,
          disabledBackgroundColor: color.withValues(alpha: 0.45),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
        ),
        child: Text(label,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
      ),
    );
  }
}

class _SecondaryAction extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const _SecondaryAction({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
        ),
        child: Text(label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
      ),
    );
  }
}
