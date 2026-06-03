import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import '../core/walk_speed.dart';
import '../models/attraction.dart';
import '../models/route_response.dart';
import 'onboarding_service.dart';

/// 동선 추천 서비스 — 백엔드 `POST /api/route` 호출, 미설정·실패 시 mock fallback.
///
/// baseUrl 주입: 빌드 시 `--dart-define=API_BASE_URL=http://localhost:5000` 으로
/// 환경별 분리. 빈 문자열이면 mock 모드.
class RouteService {
  RouteService._();
  static final RouteService instance = RouteService._();

  /// 환경별 백엔드 baseUrl. dart-define 으로 주입.
  ///   flutter run --dart-define=API_BASE_URL=http://localhost:5000
  static const String _baseUrl = String.fromEnvironment('API_BASE_URL');

  /// baseUrl 비어있으면 mock 모드. const String.isEmpty 는 const eval 불가하여
  /// length 비교로 우회.
  static const bool _useMock = _baseUrl.length == 0;

  /// 단순 메모리 캐시 — 같은 cache_key 면 재사용.
  RouteResponse? _cached;
  String? _cachedKey;

  /// HTTP 호출 timeout. 백엔드 predict 가 첫 호출 시 모델 로드 ~2s 들 수 있어 넉넉히.
  static const Duration _timeout = Duration(seconds: 8);

  Future<RouteResponse> fetchRoute(RouteRequest req) async {
    if (_useMock) return _generateMock(req);
    try {
      final resp = await _fetchFromBackend(req).timeout(_timeout);
      _cached = resp;
      _cachedKey = resp.cacheKey;
      return resp;
    } catch (e, st) {
      // 네트워크·타임아웃·5xx — mock 으로 graceful fallback.
      developer.log(
        'route backend failed, falling back to mock',
        error: e,
        stackTrace: st,
        name: 'RouteService',
      );
      return _generateMock(req);
    }
  }

  RouteResponse? get cached => _cached;

  /// 시점 features 자동 구성 — 현재 시각/요일을 기준으로 백엔드 점수 함수에
  /// 들어가는 변수를 채움. forecast_* 는 호출 측에서 알면 override, 없으면
  /// 기본 가정으로. 모델 미가용 시에도 rain_prob/hour 만으로도 점수에 반영됨.
  Map<String, Object?> _autoFeatures({
    double? rainProb,
    double? forecastTemp,
    double? forecastPop,
  }) {
    final now = DateTime.now();
    final weekday = now.weekday; // 1=Mon..7=Sun
    final hour = now.hour;
    // 한국 휴일 판단은 별도 캘린더 필요 — 일단 false 기본.
    return {
      'rain_prob': rainProb ?? 0.0,
      'weekday': weekday,
      'is_holiday': 0,
      'hour': hour,
      'forecast_temp': forecastTemp ?? 20.0,
      'forecast_pop': forecastPop ?? (rainProb ?? 0.0),
    };
  }

  // ── HTTP ────────────────────────────────────────────────
  Future<RouteResponse> _fetchFromBackend(RouteRequest req) async {
    final uri = Uri.parse('$_baseUrl/api/route');
    final payload = req.toJson();
    payload['features'] = _autoFeatures(rainProb: req.rainProb);
    final resp = await http.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    if (resp.statusCode >= 400) {
      throw HttpException('route api ${resp.statusCode}: ${resp.body}');
    }
    final body = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, Object?>;
    return RouteResponse.fromJson(body);
  }

  // ── 목업 (백엔드 없을 때 fallback) ──────────────────────
  Future<RouteResponse> _generateMock(RouteRequest req) async {
    await Future.delayed(const Duration(milliseconds: 350));

    // 백엔드 점수 함수와 동일 규칙 — 시점 변수 적용해 결과 일관성 확보.
    final now = DateTime.now();
    final hour = now.hour;
    final weekday = now.weekday;
    final rainHigh = (req.rainProb ?? 0) >= 60;
    final isLunch = hour >= 11 && hour < 13;
    final isDinner = hour >= 17 && hour < 19;
    final crowdedDay = weekday >= 6; // 토·일

    Iterable<Attraction> pool = kAttractions
        .where((a) => a.isOperating)
        .where((a) => !req.completedIds.contains(a.id));

    if (req.onboarding.hasInfant) {
      pool = pool.where((a) => a.heightLimit == 0);
    }

    final scored = pool.map((a) {
      double score = 0;
      score += (60 - a.waitMinutes).clamp(-20, 60).toDouble();
      final dist = _hav(req.lat, req.lng, a.lat, a.lng);
      score += ((1200 - dist) / 80).clamp(-10, 15);
      if (a.hasEasterEgg && !req.discoveredEggs.contains(a.id)) score += 25;
      // 선호 + 반대 페널티 (1번 스팟 변별력)
      if (a.category == '어트랙션') {
        if (req.onboarding.favoriteType == FavoriteType.thrill) {
          if (a.thrillLevel >= 4) {
            score += 35;
          } else if (a.thrillLevel <= 2) {
            score -= 15;
          }
        } else if (req.onboarding.favoriteType == FavoriteType.family) {
          if (a.thrillLevel <= 2) {
            score += 30;
          } else if (a.thrillLevel >= 4) {
            score -= 15;
          }
        }
      }
      if (req.onboarding.hasChild && a.category == '어트랙션' && a.thrillLevel <= 2) {
        score += 15;
      }
      // 목적별 가중
      final purpose = req.onboarding.purpose;
      if (purpose == VisitPurpose.date) {
        if (a.category == '포토스팟') score += 22;
        if (a.indoor) score += 8;
        if (a.rating >= 4.5) score += 10;
      } else if (purpose == VisitPurpose.picnic) {
        if (!a.indoor) score += 10;
        if (a.category == '포토스팟') score += 18;
      } else if (purpose == VisitPurpose.kidsOuting) {
        if (a.category == '어트랙션' && a.thrillLevel <= 2) score += 12;
      } else if (purpose == VisitPurpose.rides) {
        if (a.category == '어트랙션') score += 8;
      }
      // 우천 → 실내 가산
      if (rainHigh && a.indoor) score += 18;
      // 식사 시간 → 음식점/카페 가산
      if ((isLunch || isDinner) && (a.category == '음식점' || a.category == '카페')) {
        score += isLunch ? 22 : 16;
      }
      // 주말 → 인기 어트랙션 가중치 완화
      final ratingMult = (crowdedDay ? 1.0 : 1.5) * (a.category == '어트랙션' ? 1.0 : 2.67);
      score += a.rating * ratingMult;
      return (a: a, score: score);
    }).toList()
      ..sort((x, y) => y.score.compareTo(x.score));

    final N = _routeLength(req.onboarding.purpose);
    final upper = (N - 1).clamp(2, N);
    final attractionCount = (N * 0.6).ceil().clamp(2, upper);
    final picked = <Attraction>[];
    picked.addAll(scored.where((s) => s.a.category == '어트랙션').take(attractionCount).map((s) => s.a));
    // extras — 카테고리당 최상위 1개를 점수 정렬 순서대로. 백엔드와 동일.
    // 데이트 모드에선 포토스팟 +22 보너스로 카페보다 먼저 잡힘.
    final seenExtra = <String>{};
    for (final s in scored) {
      if (picked.length >= N) break;
      final c = s.a.category;
      if (c == '어트랙션' || seenExtra.contains(c)) continue;
      picked.add(s.a);
      seenExtra.add(c);
      if (seenExtra.length >= 3) break;
    }

    // anchor 는 top-3 어트랙션 중 점수 가중 stochastic 샘플링 — 같은 입력에도
    // 약간 다른 동선이 나오게 ("AI 개인화" 경험). 백엔드와 동일 정책.
    List<Attraction> ordered;
    if (picked.isEmpty) {
      ordered = const [];
    } else {
      final scoreById = {for (final s in scored) s.a.id: s.score};
      final attractionsInPick =
          picked.where((a) => a.category == '어트랙션').toList()
            ..sort((a, b) =>
                (scoreById[b.id] ?? 0).compareTo(scoreById[a.id] ?? 0));
      final candidates = attractionsInPick.take(3).toList();
      final pool = candidates.isEmpty ? picked.take(3).toList() : candidates;
      final weights = pool.map((a) => math.max(0.1, scoreById[a.id] ?? 0)).toList();
      final total = weights.fold<double>(0, (a, b) => a + b);
      final rnd = math.Random().nextDouble() * total;
      double cum = 0;
      Attraction anchor = pool.first;
      for (var i = 0; i < pool.length; i++) {
        cum += weights[i];
        if (rnd <= cum) {
          anchor = pool[i];
          break;
        }
      }
      final rest = picked.where((a) => a.id != anchor.id).toList();
      ordered = [anchor, ..._nearestNeighbor(rest, anchor.lat, anchor.lng)];
    }

    final stops = <RouteStop>[];
    double prevLat = req.lat, prevLng = req.lng;
    int totalMin = 0;
    for (var i = 0; i < ordered.length; i++) {
      final a = ordered[i];
      final dist = _hav(prevLat, prevLng, a.lat, a.lng);
      final walkMin = (dist / kWalkSpeedMpm).ceil();
      final eta = walkMin + a.waitMinutes;
      stops.add(RouteStop(id: a.id, order: i + 1, etaMinFromPrev: eta));
      totalMin += eta;
      prevLat = a.lat;
      prevLng = a.lng;
    }

    final rationale = _mockRationale(req, ordered);
    final cacheKey = '${req.lat.toStringAsFixed(3)}_${req.lng.toStringAsFixed(3)}_'
        '${req.completedIds.length}_${req.onboarding.purpose ?? ''}_${req.requestReason}';

    final resp = RouteResponse(
      route: stops,
      totalMin: totalMin,
      rationale: rationale,
      computedAt: DateTime.now(),
      cacheKey: cacheKey,
    );
    _cached = resp;
    _cachedKey = cacheKey;
    return resp;
  }

  int _routeLength(String? purpose) {
    switch (purpose) {
      case VisitPurpose.date:
        return 4;
      case VisitPurpose.picnic:
        return 3;
      case VisitPurpose.kidsOuting:
        return 5;
      case VisitPurpose.rides:
        return 7;
      default:
        return 5;
    }
  }

  String _mockRationale(RouteRequest req, List<Attraction> route) {
    // 백엔드 _rationale 와 동일 우선순위.
    final now = DateTime.now();
    final hour = now.hour;
    final rainHigh = (req.rainProb ?? 0) >= 60;
    // 1순위 — 사용자가 방금 조건 바꿈
    if (req.requestReason == 'profile_changed') {
      if (req.onboarding.purpose == VisitPurpose.date) return '데이트 모드로 다시 짰어요 💑';
      if (req.onboarding.purpose == VisitPurpose.kidsOuting) return '아이와 함께할 코스로 다시 짰어요 🎠';
      if (req.onboarding.favoriteType == FavoriteType.thrill) return '스릴 위주로 다시 짰어요 🎢';
      if (req.onboarding.favoriteType == FavoriteType.family) return '가족·어린이 위주로 다시 짰어요 🎠';
      return '새 조건으로 다시 짰어요 ✨';
    }
    // 2순위 — 동반자 제약
    if (req.onboarding.hasInfant) return '유아 동반 — 키 제한 어트랙션 빼고 짰어요 🍼';
    // 3순위 — 시점 변수
    if (rainHigh) return '비 예보 — 실내 어트랙션 위주로 짰어요 ☔';
    if (hour >= 11 && hour < 13) return '점심시간 — 식사 동선부터 짰어요 🍽️';
    if (hour >= 17 && hour < 19) return '저녁시간 — 식사 동선 포함했어요 🍽️';
    // 4순위 — GPS/완료
    if (req.requestReason == 'gps_moved') return '이동하신 위치 기준으로 다시 짰어요 📍';
    if (req.requestReason == 'attraction_completed') return '방금 다녀온 코스 빼고 갱신했어요 ✨';
    // 5순위 — 의도
    if (req.onboarding.purpose == VisitPurpose.date) return '둘만의 데이트 코스로 짰어요 💑';
    if (req.onboarding.favoriteType == FavoriteType.thrill) return '스릴 위주 — 짜릿하게 즐겨보세요 🎢';
    if (req.onboarding.favoriteType == FavoriteType.family) return '가족이 함께 즐길 어트랙션 위주에요 🎠';
    // 6순위 — 이스터에그
    final undiscoveredEggs =
        route.where((a) => a.hasEasterEgg && !req.discoveredEggs.contains(a.id)).length;
    if (undiscoveredEggs >= 2) return '못 찾은 이스터에그 $undiscoveredEggs개 포함했어요 🥚';
    return '오늘의 추천 동선이에요 ✨';
  }

  List<Attraction> _nearestNeighbor(List<Attraction> pool, double startLat, double startLng) {
    if (pool.isEmpty) return const [];
    final remaining = [...pool];
    final result = <Attraction>[];
    double curLat = startLat, curLng = startLng;
    while (remaining.isNotEmpty) {
      var bestIdx = 0;
      var bestDist = double.infinity;
      for (var i = 0; i < remaining.length; i++) {
        final d = _hav(curLat, curLng, remaining[i].lat, remaining[i].lng);
        if (d < bestDist) {
          bestDist = d;
          bestIdx = i;
        }
      }
      final pick = remaining.removeAt(bestIdx);
      result.add(pick);
      curLat = pick.lat;
      curLng = pick.lng;
    }
    return result;
  }

  static double _hav(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000.0;
    final p1 = lat1 * math.pi / 180;
    final p2 = lat2 * math.pi / 180;
    final dp = (lat2 - lat1) * math.pi / 180;
    final dl = (lng2 - lng1) * math.pi / 180;
    final h = math.sin(dp / 2) * math.sin(dp / 2) +
        math.cos(p1) * math.cos(p2) * math.sin(dl / 2) * math.sin(dl / 2);
    return 2 * r * math.atan2(math.sqrt(h), math.sqrt(1 - h));
  }
}

class HttpException implements Exception {
  final String message;
  const HttpException(this.message);
  @override
  String toString() => 'HttpException: $message';
}
