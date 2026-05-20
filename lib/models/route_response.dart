import '../services/onboarding_service.dart';

/// 백엔드 `POST /api/route` 요청·응답 타입.
/// 목업이 동일 contract 을 따르므로 실제 백엔드 붙을 때 swap 만 하면 됨.

class RouteRequest {
  final String uid;
  final double lat;
  final double lng;
  final bool hasGps;
  final SurveyAnswers onboarding;
  final Set<String> completedIds;
  final Set<String> discoveredEggs;
  final String requestReason; // initial | gps_moved | manual_refresh | attraction_completed

  const RouteRequest({
    required this.uid,
    required this.lat,
    required this.lng,
    required this.hasGps,
    required this.onboarding,
    required this.completedIds,
    required this.discoveredEggs,
    required this.requestReason,
  });

  Map<String, Object?> toJson() => {
        'uid': uid,
        'lat': lat,
        'lng': lng,
        'has_gps': hasGps,
        'onboarding': {
          'headcount': onboarding.total,
          'members': {
            for (final c in MemberCategory.values) c.name: onboarding.count(c),
          },
          'favorite_type': onboarding.favoriteType,
          'purpose': onboarding.purpose,
        },
        'completed_attraction_ids': completedIds.toList(),
        'discovered_eggs': discoveredEggs.toList(),
        'request_reason': requestReason,
      };
}

class RouteStop {
  final String id;
  final int order;
  final int etaMinFromPrev;
  const RouteStop({required this.id, required this.order, required this.etaMinFromPrev});

  static RouteStop fromJson(Map<String, Object?> m) => RouteStop(
        id: m['id'] as String,
        order: (m['order'] as num).toInt(),
        etaMinFromPrev: (m['eta_min_from_prev'] as num).toInt(),
      );
}

class RouteResponse {
  final List<RouteStop> route;
  final int totalMin;
  final String? rationale;
  final DateTime computedAt;
  final String cacheKey;

  const RouteResponse({
    required this.route,
    required this.totalMin,
    required this.rationale,
    required this.computedAt,
    required this.cacheKey,
  });

  static RouteResponse fromJson(Map<String, Object?> m) => RouteResponse(
        route: ((m['route'] as List?) ?? const [])
            .whereType<Map<String, Object?>>()
            .map(RouteStop.fromJson)
            .toList(),
        totalMin: (m['total_min'] as num?)?.toInt() ?? 0,
        rationale: m['rationale'] as String?,
        computedAt: DateTime.tryParse((m['computed_at'] as String?) ?? '') ?? DateTime.now(),
        cacheKey: (m['cache_key'] as String?) ?? '',
      );
}
