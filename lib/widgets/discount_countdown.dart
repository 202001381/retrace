import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// 할인 유효 시각까지의 카운트다운. 1초마다 갱신, 만료 시 onExpired 호출 + 자체 비노출.
/// 호출 측은 onExpired 에서 카드 비활성/제거 등 후속 처리 담당.
class DiscountCountdown extends StatefulWidget {
  final DateTime validUntil;
  final VoidCallback? onExpired;
  final Color defaultColor;
  final Color urgentColor;        // 10분 미만 강조 색
  final double fontSize;
  final FontWeight fontWeight;
  final bool showIcon;

  const DiscountCountdown({
    super.key,
    required this.validUntil,
    this.onExpired,
    this.defaultColor = AppColors.textMuted,
    this.urgentColor = AppColors.coral,
    this.fontSize = 12,
    this.fontWeight = FontWeight.w700,
    this.showIcon = true,
  });

  @override
  State<DiscountCountdown> createState() => _DiscountCountdownState();
}

class _DiscountCountdownState extends State<DiscountCountdown> {
  Timer? _ticker;
  late Duration _remaining;
  bool _expiredFired = false;

  @override
  void initState() {
    super.initState();
    _remaining = _calc();
    // 진입 시점에 이미 만료 → 즉시 콜백 (단, build 이후로 미룸).
    if (_remaining == Duration.zero) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fireExpired());
    } else {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _remaining = _calc());
        if (_remaining == Duration.zero) _fireExpired();
      });
    }
  }

  @override
  void didUpdateWidget(covariant DiscountCountdown old) {
    super.didUpdateWidget(old);
    if (old.validUntil != widget.validUntil) {
      _expiredFired = false;
      setState(() => _remaining = _calc());
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Duration _calc() {
    final d = widget.validUntil.difference(DateTime.now());
    return d.isNegative ? Duration.zero : d;
  }

  void _fireExpired() {
    if (_expiredFired) return;
    _expiredFired = true;
    _ticker?.cancel();
    widget.onExpired?.call();
  }

  String _label() {
    if (_remaining == Duration.zero) return '만료됨';
    if (_remaining.inHours >= 1) {
      final h = _remaining.inHours.toString().padLeft(2, '0');
      final m = (_remaining.inMinutes % 60).toString().padLeft(2, '0');
      final s = (_remaining.inSeconds % 60).toString().padLeft(2, '0');
      return '$h:$m:$s 남음';
    }
    if (_remaining.inMinutes >= 10) {
      return '${_remaining.inMinutes}분 남음';
    }
    // <10분: 분초 같이 표시 — 긴급감.
    final m = _remaining.inMinutes;
    final s = _remaining.inSeconds % 60;
    return '${m}분 ${s.toString().padLeft(2, '0')}초 남음';
  }

  bool get _isUrgent => _remaining.inMinutes < 10 && _remaining != Duration.zero;

  @override
  Widget build(BuildContext context) {
    if (_remaining == Duration.zero) return const SizedBox.shrink();
    final color = _isUrgent ? widget.urgentColor : widget.defaultColor;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showIcon) ...[
          Icon(Icons.schedule_rounded, size: widget.fontSize + 2, color: color),
          const SizedBox(width: 4),
        ],
        Text(_label(),
            style: TextStyle(
              color: color,
              fontSize: widget.fontSize,
              fontWeight: widget.fontWeight,
            )),
      ],
    );
  }
}
