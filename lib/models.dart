// 백엔드 응답 파싱용 데이터 클래스 (snake_case JSON ↔ camelCase Dart).

class WeatherInfo {
  final String condition;
  final double tempC;

  WeatherInfo({required this.condition, required this.tempC});

  factory WeatherInfo.fromJson(Map<String, dynamic> json) => WeatherInfo(
        condition: json['condition'] as String,
        tempC: (json['temp_c'] as num).toDouble(),
      );
}

class DiscountInfo {
  final String id;
  final String title;
  final double rate;

  DiscountInfo({required this.id, required this.title, required this.rate});

  factory DiscountInfo.fromJson(Map<String, dynamic> json) => DiscountInfo(
        id: json['id'] as String,
        title: json['title'] as String,
        rate: (json['rate'] as num).toDouble(),
      );
}

class PricingResponse {
  final WeatherInfo weather;
  final List<DiscountInfo> discounts;
  final int visitValueScore;
  final Map<String, int> congestionByZone;

  PricingResponse({
    required this.weather,
    required this.discounts,
    required this.visitValueScore,
    required this.congestionByZone,
  });

  factory PricingResponse.fromJson(Map<String, dynamic> json) => PricingResponse(
        weather: WeatherInfo.fromJson(json['weather'] as Map<String, dynamic>),
        discounts: (json['discounts'] as List)
            .map((d) => DiscountInfo.fromJson(d as Map<String, dynamic>))
            .toList(),
        visitValueScore: json['visit_value_score'] as int,
        congestionByZone:
            (json['congestion_by_zone'] as Map<String, dynamic>)
                .map((k, v) => MapEntry(k, v as int)),
      );
}

class RecommendedAttraction {
  final String id;
  final String name;
  final double score;
  final String reason;

  RecommendedAttraction({
    required this.id,
    required this.name,
    required this.score,
    required this.reason,
  });

  factory RecommendedAttraction.fromJson(Map<String, dynamic> json) =>
      RecommendedAttraction(
        id: json['id'] as String,
        name: json['name'] as String,
        score: (json['score'] as num).toDouble(),
        reason: json['reason'] as String,
      );
}

class StoryResponse {
  final String attractionId;
  final String title;
  final String body;
  final bool cached;
  final String model;

  StoryResponse({
    required this.attractionId,
    required this.title,
    required this.body,
    required this.cached,
    required this.model,
  });

  factory StoryResponse.fromJson(Map<String, dynamic> json) => StoryResponse(
        attractionId: json['attraction_id'] as String,
        title: json['title'] as String,
        body: json['body'] as String,
        cached: json['cached'] as bool,
        model: json['model'] as String,
      );
}
