import 'dart:async';
import 'dart:developer' as developer;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// FCM 수신 — 토큰 등록 + 토픽 구독 + foreground/background 핸들러.
///
/// 백엔드 pipeline.py 가 매일 자동으로 토픽(`luna_pricing` 등) 으로 알림 발송.
/// Flutter 가 이 함수 한 번 실행하면:
///   1. APNs / FCM 토큰 발급
///   2. SharedPreferences 에 토큰 저장 (백엔드가 직접 token 발송 가능하게)
///   3. 알림 권한 요청 (iOS) + 토픽 구독
///   4. foreground 메시지 핸들러 등록 (앱 켜있을 때 in-app 표시)
///
/// 호출은 `main()` 의 Firebase.initializeApp() 직후. 권한 거부·키 미설정 시
/// silently skip — 앱 전체 흐름은 영향 받지 않음.
class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  static const String _kTokenKey = 'fcm_token';
  static const String _kTopicLunaPricing = 'luna_pricing';

  String? _token;
  StreamSubscription<RemoteMessage>? _foregroundSub;

  /// 알림 ON/OFF 토글 — 사용자 환경설정과 연동.
  bool _subscribed = false;

  Future<void> bootstrap() async {
    try {
      final fm = FirebaseMessaging.instance;
      // 권한 요청 (iOS 는 필수, Android 13+ 도 필수)
      final settings = await fm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      developer.log(
        'FCM permission: ${settings.authorizationStatus}',
        name: 'FcmService',
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return;
      }

      // 토큰 발급 + 저장
      _token = await fm.getToken();
      if (_token != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_kTokenKey, _token!);
        developer.log('FCM token saved (${_token!.substring(0, 12)}...)',
            name: 'FcmService');
      }
      fm.onTokenRefresh.listen((tok) async {
        _token = tok;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_kTokenKey, tok);
      });

      // 토픽 구독 (백엔드가 토픽으로 자동 발송)
      await subscribeLunaPricing(enabled: true);

      // foreground 메시지
      _foregroundSub = FirebaseMessaging.onMessage.listen(_onForeground);

      // 앱이 종료된 상태에서 탭으로 열린 경우 초기 메시지 처리
      final initial = await fm.getInitialMessage();
      if (initial != null) _onTap(initial);

      FirebaseMessaging.onMessageOpenedApp.listen(_onTap);
    } catch (e, st) {
      developer.log(
        'FCM bootstrap failed (graceful skip)',
        error: e,
        stackTrace: st,
        name: 'FcmService',
      );
    }
  }

  Future<String?> currentToken() async {
    if (_token != null) return _token;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kTokenKey);
  }

  Future<void> subscribeLunaPricing({required bool enabled}) async {
    try {
      final fm = FirebaseMessaging.instance;
      if (enabled) {
        await fm.subscribeToTopic(_kTopicLunaPricing);
        _subscribed = true;
        developer.log('subscribed to $_kTopicLunaPricing', name: 'FcmService');
      } else {
        await fm.unsubscribeFromTopic(_kTopicLunaPricing);
        _subscribed = false;
      }
    } catch (e) {
      developer.log('subscribe failed: $e', name: 'FcmService');
    }
  }

  bool get isSubscribed => _subscribed;

  /// 포그라운드 (앱 켜있을 때) 메시지 — 시스템 알림 안 뜸. 직접 in-app 표시
  /// 옵션: SnackBar / Banner / Notification stream 으로 화면에 노출.
  /// 호출 측이 `inboundMessages` 스트림 listen 하면 UI 에서 in-app banner 표시.
  final _inboundController = StreamController<RemoteMessage>.broadcast();
  Stream<RemoteMessage> get inboundMessages => _inboundController.stream;

  void _onForeground(RemoteMessage msg) {
    developer.log(
      'FCM foreground: ${msg.notification?.title} — ${msg.notification?.body}',
      name: 'FcmService',
    );
    _inboundController.add(msg);
  }

  /// 사용자가 시스템 알림 탭해서 앱 진입 — data payload 보고 라우팅.
  /// 현재 단순 로그. 추후 NavigatorState 와 연결하면 데이터별 화면 이동 가능.
  void _onTap(RemoteMessage msg) {
    developer.log(
      'FCM tapped: ${msg.data}',
      name: 'FcmService',
    );
    // TODO: msg.data['target_date'] 또는 'attraction_id' 로 라우팅.
  }

  void dispose() {
    _foregroundSub?.cancel();
    _inboundController.close();
  }

  @visibleForTesting
  void resetForTest() {
    _token = null;
    _subscribed = false;
  }
}
