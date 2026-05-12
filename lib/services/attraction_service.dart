import 'package:latlong2/latlong.dart';

import '../models/attraction.dart';

class AttractionService {
  static const LatLng seoulLandCenter = LatLng(37.4346, 127.0167);

  static const List<Attraction> _data = [
    Attraction(
      id: 'blackhole',
      name: '블랙홀 2000',
      description: '실내 롤러코스터. 칠흑 같은 어둠 속에서 펼쳐지는 스릴 라이드.',
      category: AttractionCategory.thrill,
      minHeightCm: 120,
      thrillLevel: 5,
      location: LatLng(37.4349, 127.0162),
      waitMinutes: 35,
    ),
    Attraction(
      id: 'shoot',
      name: '샷드롭',
      description: '70m 상공에서 자유낙하하는 짜릿한 라이드.',
      category: AttractionCategory.thrill,
      minHeightCm: 130,
      thrillLevel: 5,
      location: LatLng(37.4351, 127.0170),
      waitMinutes: 25,
    ),
    Attraction(
      id: 'xflyer',
      name: 'X-Flyer',
      description: '공중에서 회전하는 인버티드 코스터.',
      category: AttractionCategory.thrill,
      minHeightCm: 130,
      thrillLevel: 4,
      location: LatLng(37.4344, 127.0173),
      waitMinutes: 40,
    ),
    Attraction(
      id: 'ferris',
      name: '대관람차',
      description: '서울랜드를 한눈에 볼 수 있는 대관람차.',
      category: AttractionCategory.family,
      minHeightCm: 0,
      thrillLevel: 1,
      location: LatLng(37.4341, 127.0159),
      waitMinutes: 10,
    ),
    Attraction(
      id: 'caravan',
      name: '캐러밴',
      description: '온 가족이 즐기는 회전 라이드.',
      category: AttractionCategory.family,
      minHeightCm: 100,
      thrillLevel: 2,
      location: LatLng(37.4348, 127.0166),
      waitMinutes: 5,
    ),
    Attraction(
      id: 'kidsplay',
      name: '유아놀이터',
      description: '미취학 아동을 위한 안전한 실내 놀이 공간.',
      category: AttractionCategory.kids,
      minHeightCm: 0,
      thrillLevel: 1,
      location: LatLng(37.4345, 127.0155),
      waitMinutes: 0,
    ),
    Attraction(
      id: 'parade',
      name: '메인 퍼레이드',
      description: '하루 두 번 진행되는 캐릭터 퍼레이드.',
      category: AttractionCategory.show,
      minHeightCm: 0,
      thrillLevel: 1,
      location: LatLng(37.4347, 127.0168),
      waitMinutes: 0,
    ),
    Attraction(
      id: 'foodcourt',
      name: '월드푸드코트',
      description: '한식·양식·디저트를 한자리에서.',
      category: AttractionCategory.food,
      minHeightCm: 0,
      thrillLevel: 0,
      location: LatLng(37.4343, 127.0164),
      waitMinutes: 0,
    ),
    Attraction(
      id: 'locker',
      name: '중앙 라커룸',
      description: '짐 보관·유모차 대여 가능.',
      category: AttractionCategory.facility,
      minHeightCm: 0,
      thrillLevel: 0,
      location: LatLng(37.4340, 127.0160),
      waitMinutes: 0,
    ),
  ];

  List<Attraction> getAll() => List.unmodifiable(_data);

  Attraction? findById(String id) {
    for (final a in _data) {
      if (a.id == id) return a;
    }
    return null;
  }

  List<Attraction> recommend({
    required int? heightCm,
    required Set<AttractionCategory> preferred,
    required int thrillTolerance,
  }) {
    final scored = _data.map((a) {
      var score = 0.0;
      if (preferred.contains(a.category)) score += 3.0;
      score -= (a.thrillLevel - thrillTolerance).abs() * 0.8;
      if (heightCm != null && heightCm < a.minHeightCm) score -= 10.0;
      score -= a.waitMinutes / 30.0;
      return MapEntry(a, score);
    }).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return scored.take(5).map((e) => e.key).toList();
  }
}
