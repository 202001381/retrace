import 'package:flutter_test/flutter_test.dart';
import 'package:seoul_land_app/models/reward.dart';

void main() {
  group('Reward.fromJson', () {
    test('parses all fields from backend response', () {
      final r = Reward.fromJson(const {
        'reward_id': 'autumn_3',
        'type': 'goods',
        'threshold': 3,
        'season': 'autumn',
        'granted_at': '2026-09-15T09:00:00+09:00',
        'redeemed_at': null,
        'code': 'DEMO-u12345-autumn_3',
      });
      expect(r.rewardId, 'autumn_3');
      expect(r.type, 'goods');
      expect(r.threshold, 3);
      expect(r.season, 'autumn');
      expect(r.code, 'DEMO-u12345-autumn_3');
      expect(r.grantedAt, isNotNull);
      expect(r.isRedeemed, isFalse);
    });

    test('isRedeemed true when redeemed_at present', () {
      final r = Reward.fromJson(const {
        'reward_id': 'autumn_3',
        'type': 'goods',
        'threshold': 3,
        'season': 'autumn',
        'granted_at': '2026-09-15T09:00:00+09:00',
        'redeemed_at': '2026-09-16T10:00:00+09:00',
        'code': 'DEMO-u12345-autumn_3',
      });
      expect(r.isRedeemed, isTrue);
      expect(r.redeemedAt, isNotNull);
    });

    test('handles missing optional fields gracefully', () {
      final r = Reward.fromJson(const {
        'reward_id': 'winter_5',
        'granted_at': '2026-12-01T09:00:00+09:00',
      });
      expect(r.rewardId, 'winter_5');
      expect(r.type, 'goods');         // default
      expect(r.threshold, 0);          // default
      expect(r.season, 'spring');      // default
      expect(r.code, isNull);
      expect(r.redeemedAt, isNull);
    });
  });

  group('RewardCheckResult.fromJson', () {
    test('splits newly_granted vs already_granted', () {
      final result = RewardCheckResult.fromJson(const {
        'season': 'autumn',
        'unlocked_count': 5,
        'newly_granted': [
          {
            'reward_id': 'autumn_5',
            'type': 'ticket',
            'threshold': 5,
            'season': 'autumn',
            'granted_at': '2026-09-20T09:00:00+09:00',
          },
        ],
        'already_granted': [
          {
            'reward_id': 'autumn_3',
            'type': 'goods',
            'threshold': 3,
            'season': 'autumn',
            'granted_at': '2026-09-15T09:00:00+09:00',
          },
        ],
      });
      expect(result.season, 'autumn');
      expect(result.unlockedCount, 5);
      expect(result.newlyGranted, hasLength(1));
      expect(result.newlyGranted.first.type, 'ticket');
      expect(result.alreadyGranted, hasLength(1));
      expect(result.alreadyGranted.first.type, 'goods');
    });

    test('handles empty arrays', () {
      final r = RewardCheckResult.fromJson(const {
        'season': 'spring',
        'unlocked_count': 1,
        'newly_granted': [],
        'already_granted': [],
      });
      expect(r.newlyGranted, isEmpty);
      expect(r.alreadyGranted, isEmpty);
    });
  });
}
