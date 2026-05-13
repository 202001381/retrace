import 'dart:convert';

import 'package:http/http.dart' as http;

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
