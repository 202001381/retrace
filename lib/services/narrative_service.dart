import 'dart:convert';

import 'package:http/http.dart' as http;

/// 싱글톤 — instance.generate(req) 한 번에 호출. baseUrl 은 환경에서 추출.
class NarrativeServiceLite {
  NarrativeServiceLite._();
  static final NarrativeServiceLite instance = NarrativeServiceLite._();

  static const String _baseUrl = String.fromEnvironment('API_BASE_URL');
  static const bool _useMock = _baseUrl.length == 0;

  Future<NarrativeResult> generate(NarrativeRequest req) async {
    if (_useMock) return _mockResult(req);
    try {
      final svc = NarrativeService(baseUrl: _baseUrl);
      return await svc.generate(req);
    } catch (_) {
      return _mockResult(req);
    }
  }

  NarrativeResult _mockResult(NarrativeRequest req) {
    final season = {
      'spring': '벚꽃이 흩날리던',
      'summer': '햇살 짙던 여름',
      'autumn': '단풍이 절정이던 가을',
      'winter': '눈 내리던 겨울',
    }[req.season] ?? '기억에 남는';
    final c = {
      '혼자': '혼자만의 발걸음',
      '연인': '둘만의 발걸음',
      '친구': '친구들과의 발걸음',
      '가족': '가족과의 발걸음',
    }[req.companionType] ?? '당신의 발걸음';
    return NarrativeResult(
      narrative:
          '$season 날, $c이 만든 한 페이지입니다. 1988년 개장 이래 셀 수 없이 많은 사람들의 기억이 이 자리에 쌓였고, 오늘 당신의 방문이 새로운 챕터를 더합니다 🌙',
      attractionName: req.attractionId,
    );
  }
}

class NarrativeRequest {
  final String attractionId;
  final String companionType;
  final String season; // spring/summer/autumn/winter
  final String weather; // 맑음/흐림/소나기/강우
  final int visitCount;

  const NarrativeRequest({
    required this.attractionId,
    required this.companionType,
    required this.season,
    required this.weather,
    required this.visitCount,
  });

  Map<String, Object?> toJson() => {
        'attraction_id': attractionId,
        'companion_type': companionType,
        'season': season,
        'weather': weather,
        'visit_count': visitCount,
      };
}

class NarrativeResult {
  final String narrative;
  final String attractionName;
  const NarrativeResult({required this.narrative, required this.attractionName});
}

class NarrativeService {
  NarrativeService({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  final String baseUrl; // e.g. https://api.retrace.app
  final http.Client _client;

  Future<NarrativeResult> generate(NarrativeRequest req) async {
    final uri = Uri.parse('$baseUrl/api/narrative');
    final resp = await _client
        .post(
          uri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode(req.toJson()),
        )
        .timeout(const Duration(seconds: 25));

    if (resp.statusCode >= 400) {
      throw NarrativeException('서사 생성 실패 (${resp.statusCode})');
    }
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    return NarrativeResult(
      narrative: body['narrative'] as String? ?? '',
      attractionName: body['attraction_name'] as String? ?? '',
    );
  }
}

class NarrativeException implements Exception {
  final String message;
  NarrativeException(this.message);
  @override
  String toString() => message;
}
