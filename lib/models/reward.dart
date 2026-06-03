/// 시즌별 보상. 백엔드 `/api/rewards/*` 응답과 1:1 매핑.
///
/// 발급 흐름:
///   1. 사용자가 챕터 어트랙션 발견 → easter_egg_service 가 Firestore 기록
///   2. 클라이언트 또는 백엔드가 `/api/rewards/check` 호출 → threshold(3/5)
///      도달 시 자동 발급. 동일 reward_id 중복 발급 없음 (트랜잭션).
///   3. 사용자가 매장에서 코드 제시 → `/api/rewards/redeem` 으로 redeemed_at 기록.
class Reward {
  final String rewardId; // '{season}_{threshold}' (예: autumn_3)
  final String type;     // 'goods' | 'ticket'
  final int threshold;   // 3 | 5
  final String season;   // 'spring'|'summer'|'autumn'|'winter'
  final DateTime? grantedAt;
  final DateTime? redeemedAt;
  final String? code;    // 'DEMO-{uid앞6}-{reward_id}'

  const Reward({
    required this.rewardId,
    required this.type,
    required this.threshold,
    required this.season,
    required this.grantedAt,
    required this.redeemedAt,
    required this.code,
  });

  bool get isRedeemed => redeemedAt != null;

  factory Reward.fromJson(Map<String, dynamic> json) => Reward(
        rewardId: json['reward_id'] as String,
        type: json['type'] as String? ?? 'goods',
        threshold: (json['threshold'] as num?)?.toInt() ?? 0,
        season: json['season'] as String? ?? 'spring',
        grantedAt: _parseTs(json['granted_at']),
        redeemedAt: _parseTs(json['redeemed_at']),
        code: json['code'] as String?,
      );
}

class RewardCheckResult {
  final String season;
  final int unlockedCount;
  final List<Reward> newlyGranted;
  final List<Reward> alreadyGranted;

  const RewardCheckResult({
    required this.season,
    required this.unlockedCount,
    required this.newlyGranted,
    required this.alreadyGranted,
  });

  factory RewardCheckResult.fromJson(Map<String, dynamic> json) {
    final newly = (json['newly_granted'] as List?) ?? const [];
    final already = (json['already_granted'] as List?) ?? const [];
    return RewardCheckResult(
      season: json['season'] as String? ?? 'spring',
      unlockedCount: (json['unlocked_count'] as num?)?.toInt() ?? 0,
      newlyGranted: newly.map((e) => Reward.fromJson(e as Map<String, dynamic>)).toList(),
      alreadyGranted: already.map((e) => Reward.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

DateTime? _parseTs(Object? v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v);
  return null;
}
