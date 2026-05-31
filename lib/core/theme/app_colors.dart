// lib/core/theme/app_colors.dart

import 'package:flutter/material.dart';

/// Re·Trace v3 — Seoul Land 리브랜딩 디자인 시스템.
/// Pretendard Variable 단일 폰트. Red(#E60023) 주 강조, Yellow/Blue/Mint 보조.
///
/// 컬러 위계 원칙: 화면당 메인 액센트는 항상 Red 또는 Black.
/// Yellow/Blue 는 보조, Mint/Grape/Blush 는 도장/상태 표시 한정.
class AppColors {
  AppColors._();

  // ─── Surfaces ───
  static const bg          = Color(0xFFFFFFFF);
  static const bgPage      = Color(0xFFF7F7F5);
  static const bgCard      = Color(0xFFFFFFFF);
  static const bgCardWarm  = Color(0xFFFAFAF8);
  static const bgSoft      = Color(0xFFF2F2EF);
  static const bgSky       = Color(0xFFE8F2FC);
  static const bgMint      = Color(0xFFE5F4ED);
  static const bgBlush     = Color(0xFFFDECEE);
  static const bgYellow    = Color(0xFFFFF8E0);
  static const bgDeep      = Color(0xFF1A1A1A);
  static const bgDeeper    = Color(0xFF0D0D0D);

  // ─── Ink (text/icon) ───
  static const ink900 = Color(0xFF111111);
  static const ink800 = Color(0xFF1F1F1F);
  static const ink700 = Color(0xFF333333);
  static const ink500 = Color(0xFF707070);
  static const ink400 = Color(0xFF9A9A9A);
  static const ink300 = Color(0xFFC4C4C4);
  static const ink200 = Color(0xFFE5E5E5);
  static const ink100 = Color(0xFFF2F2F2);

  // ─── Lines ───
  static const line       = Color(0xFFECECEC);
  static const lineDim    = Color(0xFFF4F4F4);
  static const lineStrong = Color(0xFFD8D8D8);

  // ─── Brand — Seoul Land Red (primary) ───
  static const red     = Color(0xFFE60023);
  static const redDeep = Color(0xFFB8001C);
  static const redSoft = Color(0xFFFFD3D9);
  static const redTint = Color(0xFFFFEDF0);

  // ─── Yellow — secondary (mascot, fun, discount) ───
  static const yellow     = Color(0xFFFFC700);
  static const yellowDeep = Color(0xFFC99500);
  static const yellowTint = Color(0xFFFFF4C7);

  // ─── Blue — supporting (sky, luna, AI) ───
  static const blue     = Color(0xFF0084E0);
  static const blueDeep = Color(0xFF0064B0);
  static const blueTint = Color(0xFFDDEEFB);

  // ─── Mint — status OK ───
  static const mint     = Color(0xFF00A86B);
  static const mintTint = Color(0xFFD5EFE3);

  // ─── Stamp accent (도장 캐릭터 컬러 전용) ───
  static const grape     = Color(0xFF6E3FE0);
  static const grapeTint = Color(0xFFE4DAFB);
  static const blush     = Color(0xFFFF8FA3);
  static const blushTint = Color(0xFFFFE0E6);

  // ─── Semantic status ───
  static const good = mint;       // "여유"
  static const warn = yellowDeep; // "보통"
  static const busy = red;        // "혼잡"

  // ─── Convenience aliases (UI 의미별) ───
  static const textPrimary   = ink900;
  static const textSecondary = ink500;
  static const textTertiary  = ink400;
  static const textOnDark    = bg;       // 다크 surface 위 텍스트
}
