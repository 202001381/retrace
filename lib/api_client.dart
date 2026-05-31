// 백엔드 3개 엔드포인트 호출 래퍼.
// 백엔드 응답 컨벤션: 성공 { "data": ... } / 실패 { "error": { code, message } }

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'config.dart';
import 'models.dart';

class ApiException implements Exception {
  final String code;
  final String message;
  ApiException(this.code, this.message);

  @override
  String toString() => '[$code] $message';
}

class ApiClient {
  final String baseUrl;
  final http.Client _client;

  ApiClient({String? baseUrl, http.Client? client})
      : baseUrl = baseUrl ?? apiBaseUrl,
        _client = client ?? http.Client();

  Future<PricingResponse> getPricing() async {
    final data = await _post('/api/pricing', const {});
    return PricingResponse.fromJson(data);
  }

  Future<List<RecommendedAttraction>> getRecommend({
    required List<Map<String, dynamic>> members,
    Map<String, double>? currentLocation,
  }) async {
    final body = <String, dynamic>{
      'members': members,
      'current_location': ?currentLocation,
    };
    final data = await _post('/api/recommend', body);
    return (data['top'] as List)
        .map((a) => RecommendedAttraction.fromJson(a as Map<String, dynamic>))
        .toList();
  }

  Future<StoryResponse> getStory(String attractionId) async {
    final data = await _post('/api/story', {'attraction_id': attractionId});
    return StoryResponse.fromJson(data);
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final uri = Uri.parse('$baseUrl$path');
    final http.Response resp = await _client.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    } catch (e) {
      throw ApiException(
        'INVALID_RESPONSE',
        'HTTP ${resp.statusCode}: 응답 본문이 JSON이 아님',
      );
    }

    if (resp.statusCode >= 400 || decoded.containsKey('error')) {
      final err = decoded['error'] as Map<String, dynamic>? ??
          {'code': 'HTTP_${resp.statusCode}', 'message': '요청 실패'};
      throw ApiException(err['code'] as String, err['message'] as String);
    }
    return decoded['data'] as Map<String, dynamic>;
  }
}
