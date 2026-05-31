import 'package:flutter/foundation.dart';

import '../models/luna_recommendation.dart';

/// 마이 루나 추천 단일 진실 — 화면 간 공유 (현재 MyLuna ↔ Map).
/// MyLuna 가 source-of-truth, Map 은 read-only 구독자.
/// 추후 RouteController 도입 시 이 store 가 그 안으로 흡수될 가능성 있음.
class LunaRecommendationStore {
  LunaRecommendationStore._();
  static final LunaRecommendationStore instance =
      LunaRecommendationStore._();

  final ValueNotifier<LunaRecommendation?> notifier =
      ValueNotifier<LunaRecommendation?>(null);

  LunaRecommendation? get current => notifier.value;

  void set(LunaRecommendation? r) => notifier.value = r;

  void clear() => notifier.value = null;
}
