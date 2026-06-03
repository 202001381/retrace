import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// 도장(Stamp) — 어트랙션·이스터에그·메모리 표시.
/// 이모지 대신 2~3글자 코드 + 컬러 도장으로 표현. v3 디자인 시스템.
enum StampTone {
  navy, navySolid, red, redOutline, blue, blueOutline,
  yellow, gold, mint, grape, blush, sage, paper,
}

class _ToneStyle {
  final Color bg, ink, border;
  const _ToneStyle(this.bg, this.ink, this.border);
}

const Map<StampTone, _ToneStyle> _kStampPalette = {
  StampTone.navy: _ToneStyle(Colors.transparent, AppColors.ink900, AppColors.ink900),
  StampTone.navySolid: _ToneStyle(AppColors.ink900, Colors.white, AppColors.ink900),
  StampTone.red: _ToneStyle(AppColors.red, Colors.white, AppColors.red),
  StampTone.redOutline: _ToneStyle(AppColors.redTint, AppColors.redDeep, AppColors.red),
  StampTone.blue: _ToneStyle(AppColors.blue, Colors.white, AppColors.blue),
  StampTone.blueOutline: _ToneStyle(AppColors.blueTint, AppColors.blueDeep, AppColors.blue),
  StampTone.yellow: _ToneStyle(AppColors.yellow, AppColors.ink900, AppColors.yellowDeep),
  StampTone.gold: _ToneStyle(AppColors.yellowTint, Color(0xFF7A5715), AppColors.yellowDeep),
  StampTone.mint: _ToneStyle(AppColors.mint, Colors.white, AppColors.mint),
  StampTone.grape: _ToneStyle(AppColors.grape, Colors.white, AppColors.grape),
  StampTone.blush: _ToneStyle(AppColors.blushTint, Color(0xFFB5395A), AppColors.blush),
  StampTone.sage: _ToneStyle(AppColors.bgMint, Color(0xFF0A6B47), AppColors.mint),
  StampTone.paper: _ToneStyle(AppColors.bgCard, AppColors.ink900, AppColors.ink300),
};

class Stamp extends StatelessWidget {
  final String code;
  final double size;
  final StampTone tone;
  final double rotate; // degrees, ±10 for hand-stamp feel
  final TextStyle? textStyle;
  /// 이모지로 표시. 비어있으면 [code] 텍스트로 fallback.
  /// 지도 마커처럼 시각 강조가 필요한 곳에서 사용.
  final String? emoji;

  const Stamp({
    super.key,
    required this.code,
    this.size = 36,
    this.tone = StampTone.navy,
    this.rotate = 0,
    this.textStyle,
    this.emoji,
  });

  /// 어트랙션명에서 2~3 글자 도장 코드를 도출.
  /// 영문/숫자가 있으면 첫 글자(들) 추출, 한글뿐이면 첫 음절 한 글자.
  static String codeFromName(String name) {
    final cleaned = name.replaceAll(RegExp(r'\s+'), ' ').trim();
    // 숫자(예: "은하열차 888") 우선.
    final numMatch = RegExp(r'\d{2,4}').firstMatch(cleaned);
    if (numMatch != null) return numMatch.group(0)!;
    // 영문 시작이면 앞 2~3 글자.
    final asciiMatch = RegExp(r'[A-Za-z]{2,3}').firstMatch(cleaned);
    if (asciiMatch != null) return asciiMatch.group(0)!.toUpperCase();
    // 한글 단어별 첫 글자 추출 (예: "퍼레이드 아치" → "퍼아").
    final tokens = cleaned.split(RegExp(r'[ ·\-]+')).where((t) => t.isNotEmpty).toList();
    if (tokens.length >= 2) {
      final c = tokens[0].characters.first + tokens[1].characters.first;
      return c;
    }
    if (cleaned.isEmpty) return '·';
    return cleaned.characters.first;
  }

  /// 카테고리/스릴 기반 톤 추천.
  static StampTone toneFromHints({
    required String category,
    int thrillLevel = 0,
    bool hasEasterEgg = false,
  }) {
    switch (category) {
      case '카페':
        return StampTone.yellow;
      case '음식점':
        return StampTone.gold;
      case '포토스팟':
        return StampTone.blush;
      default:
        if (thrillLevel >= 4) return StampTone.red;
        if (thrillLevel == 3) return StampTone.grape;
        if (hasEasterEgg) return StampTone.blue;
        return StampTone.blueOutline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _kStampPalette[tone] ?? _kStampPalette[StampTone.navy]!;
    final useEmoji = (emoji != null && emoji!.isNotEmpty);
    final fs = useEmoji
        ? size * 0.55
        : (code.length >= 3 ? size * 0.28 : size * 0.34);
    final stamp = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: p.bg,
        shape: BoxShape.circle,
        border: Border.all(color: p.border, width: 1.5),
      ),
      child: Text(
        useEmoji ? emoji! : code,
        style: (textStyle ?? const TextStyle()).copyWith(
          color: p.ink,
          fontSize: fs,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.4,
          height: 1.0,
        ),
      ),
    );
    if (rotate == 0) return stamp;
    return Transform.rotate(angle: rotate * 3.141592653589793 / 180, child: stamp);
  }
}
