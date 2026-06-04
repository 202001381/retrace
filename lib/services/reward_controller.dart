/// 보상 자동 발급 트리거 — 챕터 어트랙션 발견 직후 호출.
///
/// 흐름:
///   1. easter_egg_service 가 어트랙션 발견 기록
///   2. RewardController.checkAfterDiscovery(context) 호출 — 백엔드에 발급 검사 요청
///   3. newly_granted 가 있으면 RewardUnlockModal 풀스크린 모달 + 진동 1회
///   4. 사용자가 "지금 사용하기" → redeem 호출 → 코드 표시
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/reward.dart';
import '../widgets/reward_unlock_modal.dart';
import 'easter_egg_service.dart';
import 'rewards_service.dart';

class RewardController {
  RewardController._();
  static final RewardController instance = RewardController._();

  /// 현재 사용자 식별자. Firebase Auth 도입 전엔 'guest' 단일 사용.
  /// 추후 PreferencesService.currentUid 또는 FirebaseAuth.uid 로 교체.
  static const String _uid = 'guest';

  // 동시 다발 모달 방지.
  bool _modalOpen = false;

  /// 어트랙션 발견 등 이벤트 후 호출. newly_granted 가 있으면 자동 풀스크린 모달.
  /// SharedPreferences 의 발견 기록을 그대로 백엔드에 동봉해 Firestore 동기화 미설치
  /// 환경에서도 작동.
  Future<void> checkAfterDiscovery(BuildContext context) async {
    if (!RewardsService.instance.enabled) return;
    // 동시 다발 호출 race — 첫 호출만 통과시키고 나머지 일찍 종료.
    if (_modalOpen) return;
    _modalOpen = true;
    try {
      final discovered = await EasterEggService.discoveredAll();
      final result = await RewardsService.instance.checkAndGrant(_uid, discovered: discovered);
      if (result == null || result.newlyGranted.isEmpty) return;
      // context 가 async 사이 unmount 됐을 수 있음.
      if (!context.mounted) return;
      // 우선순위: ticket > goods (큰 보상 먼저 보여줌).
      final sorted = [...result.newlyGranted]
        ..sort((a, b) => b.threshold.compareTo(a.threshold));
      final r = sorted.first;
      await _presentUnlock(context, r, result.unlockedCount);
    } finally {
      _modalOpen = false;
    }
  }

  Future<void> _presentUnlock(BuildContext context, Reward reward, int unlockedCount) async {
    // 풀스크린 인커밍-콜 톤 — 강 진동 1회 (사용자 알아채기 위함).
    HapticFeedback.heavyImpact();
    await Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black87,
        fullscreenDialog: true,
        transitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (_, __, ___) => RewardUnlockModal(
          reward: reward,
          unlockedCount: unlockedCount,
          uid: _uid,
        ),
        transitionsBuilder: (_, anim, __, child) {
          return FadeTransition(
            opacity: anim,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.94, end: 1.0).animate(
                CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
              ),
              child: child,
            ),
          );
        },
      ),
    );
  }

  String get uid => _uid;
}
