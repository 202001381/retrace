import 'package:latlong2/latlong.dart';

enum AttractionCategory {
  thrill,
  family,
  kids,
  show,
  food,
  facility,
}

extension AttractionCategoryX on AttractionCategory {
  String get label {
    switch (this) {
      case AttractionCategory.thrill:
        return '스릴';
      case AttractionCategory.family:
        return '패밀리';
      case AttractionCategory.kids:
        return '키즈';
      case AttractionCategory.show:
        return '공연';
      case AttractionCategory.food:
        return '먹거리';
      case AttractionCategory.facility:
        return '편의시설';
    }
  }
}

class Attraction {
  final String id;
  final String name;
  final String description;
  final AttractionCategory category;
  final int minHeightCm;
  final int thrillLevel;
  final LatLng location;
  final int waitMinutes;

  const Attraction({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.minHeightCm,
    required this.thrillLevel,
    required this.location,
    this.waitMinutes = 0,
  });
}
