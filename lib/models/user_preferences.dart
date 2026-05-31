/// 알림·위치·마케팅 동의 사용자 설정. immutable + Firestore/SharedPreferences 양쪽 직렬화.
enum AlertChannel {
  appPush('app_push'),
  kakao('kakao'),
  sms('sms');

  final String key;
  const AlertChannel(this.key);

  static AlertChannel? fromKey(String k) {
    for (final c in AlertChannel.values) {
      if (c.key == k) return c;
    }
    return null;
  }
}

class UserPreferences {
  final bool appPushEnabled;          // 서비스 알림 (동선 업데이트 / 이스터에그 / 이벤트)
  final bool lowCrowdAlertEnabled;    // 한산 알림 마스터 스위치
  final Set<AlertChannel> lowCrowdChannels;
  final bool marketingConsent;        // 광고성 정보 수신 동의 (정통법 §50)
  final DateTime? marketingConsentAt; // 동의 시각 — 감사 추적용
  final bool locationTrackingEnabled;

  const UserPreferences({
    required this.appPushEnabled,
    required this.lowCrowdAlertEnabled,
    required this.lowCrowdChannels,
    required this.marketingConsent,
    required this.marketingConsentAt,
    required this.locationTrackingEnabled,
  });

  /// 신규 사용자 디폴트 — 모두 OFF (opt-in 원칙).
  static const UserPreferences defaults = UserPreferences(
    appPushEnabled: false,
    lowCrowdAlertEnabled: false,
    lowCrowdChannels: {},
    marketingConsent: false,
    marketingConsentAt: null,
    locationTrackingEnabled: false,
  );

  /// 카카오·SMS 같은 광고성 채널 사용 가능 여부 — 마케팅 동의가 게이트.
  bool get canUseKakaoOrSms => marketingConsent;

  UserPreferences copyWith({
    bool? appPushEnabled,
    bool? lowCrowdAlertEnabled,
    Set<AlertChannel>? lowCrowdChannels,
    bool? marketingConsent,
    DateTime? marketingConsentAt,
    bool clearMarketingConsentAt = false,
    bool? locationTrackingEnabled,
  }) {
    return UserPreferences(
      appPushEnabled: appPushEnabled ?? this.appPushEnabled,
      lowCrowdAlertEnabled: lowCrowdAlertEnabled ?? this.lowCrowdAlertEnabled,
      lowCrowdChannels: lowCrowdChannels ?? this.lowCrowdChannels,
      marketingConsent: marketingConsent ?? this.marketingConsent,
      marketingConsentAt: clearMarketingConsentAt
          ? null
          : (marketingConsentAt ?? this.marketingConsentAt),
      locationTrackingEnabled:
          locationTrackingEnabled ?? this.locationTrackingEnabled,
    );
  }

  /// 마케팅 OFF 강제 시 카카오·SMS 채널을 동반 정리하는 헬퍼 (정합성 유지).
  UserPreferences withoutAdChannels() {
    final next = {...lowCrowdChannels}..removeAll(
        const [AlertChannel.kakao, AlertChannel.sms]);
    return copyWith(lowCrowdChannels: next);
  }

  Map<String, Object?> toMap() => {
        'app_push_enabled': appPushEnabled,
        'low_crowd_alert_enabled': lowCrowdAlertEnabled,
        'low_crowd_channels':
            lowCrowdChannels.map((c) => c.key).toList(),
        'marketing_consent': marketingConsent,
        'marketing_consent_at': marketingConsentAt?.toIso8601String(),
        'location_tracking_enabled': locationTrackingEnabled,
      };

  static UserPreferences fromMap(Map<String, Object?>? m) {
    if (m == null) return defaults;
    final channels = <AlertChannel>{};
    final list = m['low_crowd_channels'];
    if (list is List) {
      for (final v in list) {
        final c = AlertChannel.fromKey(v.toString());
        if (c != null) channels.add(c);
      }
    }
    DateTime? at;
    final raw = m['marketing_consent_at'];
    if (raw is String) at = DateTime.tryParse(raw);
    return UserPreferences(
      appPushEnabled: (m['app_push_enabled'] as bool?) ?? false,
      lowCrowdAlertEnabled: (m['low_crowd_alert_enabled'] as bool?) ?? false,
      lowCrowdChannels: channels,
      marketingConsent: (m['marketing_consent'] as bool?) ?? false,
      marketingConsentAt: at,
      locationTrackingEnabled:
          (m['location_tracking_enabled'] as bool?) ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is UserPreferences &&
      other.appPushEnabled == appPushEnabled &&
      other.lowCrowdAlertEnabled == lowCrowdAlertEnabled &&
      _setEq(other.lowCrowdChannels, lowCrowdChannels) &&
      other.marketingConsent == marketingConsent &&
      other.marketingConsentAt == marketingConsentAt &&
      other.locationTrackingEnabled == locationTrackingEnabled;

  @override
  int get hashCode => Object.hash(
        appPushEnabled,
        lowCrowdAlertEnabled,
        Object.hashAllUnordered(lowCrowdChannels),
        marketingConsent,
        marketingConsentAt,
        locationTrackingEnabled,
      );

  static bool _setEq(Set<AlertChannel> a, Set<AlertChannel> b) =>
      a.length == b.length && a.containsAll(b);
}
