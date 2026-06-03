/// 시즌 보상 — 백엔드 `/api/rewards/*` 래퍼.
///
/// 백엔드 미설정 / 호출 실패 시: 빈 결과 반환 (절대 throw 하지 않음).
/// 베타 환경에서 백엔드 다운돼도 앱 자체는 정상 동작해야 함.
///
/// baseUrl 주입: `--dart-define=API_BASE_URL=http://localhost:5000`
library;

import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;

import '../models/reward.dart';

class RewardsService {
  RewardsService._();
  static final RewardsService instance = RewardsService._();

  static const String _baseUrl = String.fromEnvironment('API_BASE_URL');
  static const bool _enabled = _baseUrl.length > 0;
  static const Duration _timeout = Duration(seconds: 5);

  bool get enabled => _enabled;

  /// 현재 시즌 진행도 평가 + threshold 도달 시 발급.
  /// 백엔드 미설정·실패면 null 반환.
  /// [discovered] 가 주어지면 그 리스트 기준으로 카운트 (베타: SharedPreferences 동기화 대신).
  Future<RewardCheckResult?> checkAndGrant(String uid, {Iterable<String>? discovered}) async {
    if (!_enabled) return null;
    try {
      final uri = Uri.parse('$_baseUrl/api/rewards/check');
      final body = <String, Object?>{'uid': uid};
      if (discovered != null) body['discovered'] = discovered.toList();
      final resp = await http
          .post(
            uri,
            headers: const {'content-type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_timeout);
      if (resp.statusCode >= 400) {
        developer.log('rewards check ${resp.statusCode}: ${resp.body}',
            name: 'RewardsService');
        return null;
      }
      return RewardCheckResult.fromJson(
          jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>);
    } catch (e, st) {
      developer.log('rewards check failed', error: e, stackTrace: st,
          name: 'RewardsService');
      return null;
    }
  }

  /// 사용자 보유 리워드 목록.
  Future<List<Reward>> list(String uid) async {
    if (!_enabled) return const [];
    try {
      final uri = Uri.parse('$_baseUrl/api/rewards/list?uid=$uid');
      final resp = await http.get(uri).timeout(_timeout);
      if (resp.statusCode >= 400) return const [];
      final body = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      final items = (body['items'] as List?) ?? const [];
      return items
          .map((e) => Reward.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      developer.log('rewards list failed', error: e, stackTrace: st,
          name: 'RewardsService');
      return const [];
    }
  }

  /// 사용 처리 (redeemed_at 기록). 성공 시 갱신된 reward, 실패 시 null.
  Future<Reward?> redeem(String uid, String rewardId) async {
    if (!_enabled) return null;
    try {
      final uri = Uri.parse('$_baseUrl/api/rewards/redeem');
      final resp = await http
          .post(
            uri,
            headers: const {'content-type': 'application/json'},
            body: jsonEncode({'uid': uid, 'reward_id': rewardId}),
          )
          .timeout(_timeout);
      if (resp.statusCode >= 400) return null;
      return Reward.fromJson(
          jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>);
    } catch (e, st) {
      developer.log('rewards redeem failed', error: e, stackTrace: st,
          name: 'RewardsService');
      return null;
    }
  }
}
