// lib/core/theme/app_colors.dart

import 'package:flutter/material.dart';

/// RE-TRACE 컬러 팔레트 — "달밤의 놀이공원".
/// Luna 모티프(달·밤하늘) + Re-trace 모티프(기억·복원).
/// Deep Navy + Sunset Coral + Cream 의 빈티지 놀이공원 포스터 무드.
///
/// 비율 원칙
/// - 60% Cream surfaces
/// - 30% Luna Navy (브랜드·헤딩·텍스트)
/// - 10% Sunset Coral (CTA·강조)
///
/// 규칙: 같은 hex 라도 *사용 의도*가 다르면 다른 토큰. hex 직접 사용 금지.
/// alpha 변형은 별도 토큰 X — `.withValues(alpha: ...)` 로 wrap.
class AppColors {
  AppColors._();

  // Brand
  static const lunaNavy      = Color(0xFF1B2A4E);
  static const lunaNavyLight = Color(0xFF2D3F6A);
  static const lunaNavyDeep  = Color(0xFF0E1A36);

  // Accent
  static const sunsetCoral     = Color(0xFFFF6B4A);
  static const moonlightGold   = Color(0xFFF4B942);
  static const discoveryPurple = Color(0xFF7B5FC4);
  static const memoryPink      = Color(0xFFFFB4B4);

  // Status
  static const success = Color(0xFF3DAE7B);
  static const warning = Color(0xFFE89B2C);
  static const danger  = Color(0xFFD63A3A);
  static const info    = Color(0xFF4A7BC8);

  // Surface
  static const cream        = Color(0xFFFAF6EE);
  static const cardWhite    = Color(0xFFFFFFFF);
  static const cardElevated = Color(0xFFF2EBDA);
  static const border       = Color(0xFFE8E2D2);

  // Text
  static const textPrimary   = lunaNavy;
  static const textSecondary = Color(0xFF5A6478);
  static const textTertiary  = Color(0xFF9AA1B0);
  static const textOnDark    = cream;

  // Map markers
  static const markerAttraction = sunsetCoral;
  static const markerEasterEgg  = discoveryPurple;
  static const markerFood       = moonlightGold;
  static const markerCafe       = Color(0xFF8B5E3C);
  static const markerPhoto      = memoryPink;
}
