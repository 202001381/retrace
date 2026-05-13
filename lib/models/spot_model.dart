import 'package:latlong2/latlong.dart';

enum SpotCategory {
  attraction, // 어트랙션
  food,       // 음식점
  photo,      // 포토스팟
}

enum SpotTheme {
  thrill,   // 스릴
  family,   // 가족
  relaxed,  // 여유
  photo,    // 포토
  food,     // 먹거리
}

class Spot {
  final String id;
  final String name;
  final String nameEn;
  final LatLng position;
  final SpotCategory category;
  final List<SpotTheme> themes;
  final String icon;
  final String description;
  final double rating;
  final int reviewCount;
  final String? waitTime;
  final String? priceRange;
  final String? photoTip;
  final bool hasEasterEgg;
  final bool isOperating;
  final String zone;
  final int visitDurationMin;
  // 추천 스코어링용 부가 필드 (default 적용 — 기존 const 리터럴 호환)
  final bool indoor;
  final int thrillLevel; // 1~5
  final int? heightLimitCm; // null = 키 제한 없음

  const Spot({
    required this.id,
    required this.name,
    required this.nameEn,
    required this.position,
    required this.category,
    required this.themes,
    required this.icon,
    required this.description,
    required this.rating,
    required this.reviewCount,
    this.waitTime,
    this.priceRange,
    this.photoTip,
    this.hasEasterEgg = false,
    this.isOperating = true,
    required this.zone,
    required this.visitDurationMin,
    this.indoor = false,
    this.thrillLevel = 2,
    this.heightLimitCm,
  });
}

// ─────────────────────────────────────────────────────────────
//  서울랜드 실제 좌표 기준
//  중심: 37.4279° N, 127.0247° E  (경기 과천시 막계동)
// ─────────────────────────────────────────────────────────────
class SeoulLandSpots {
  static const LatLng center = LatLng(37.4279, 127.0247);

  static const List<Spot> all = [

    // ════════════════════════════════════════
    // 🎢 어트랙션 (15개)
    // ════════════════════════════════════════

    Spot(
      id: 'a01',
      name: '은하열차 888',
      nameEn: 'Galaxy Train 888',
      position: LatLng(37.4291, 127.0231),
      category: SpotCategory.attraction,
      themes: [SpotTheme.thrill, SpotTheme.family],
      icon: '🎢',
      description: '1988년 개장 당시 대한민국 최초 롤러코스터. 38년 역사의 레전드!',
      rating: 4.5,
      reviewCount: 3240,
      waitTime: '15분',
      hasEasterEgg: true,
      zone: '미래의 나라',
      visitDurationMin: 10,
    ),

    Spot(
      id: 'a02',
      name: '블랙홀 2000',
      nameEn: 'Black Hole 2000',
      position: LatLng(37.4295, 127.0228),
      category: SpotCategory.attraction,
      themes: [SpotTheme.thrill],
      icon: '🌀',
      description: '어둠 속 스크류 코스터! 서울랜드 최고 스릴 어트랙션',
      rating: 4.7,
      reviewCount: 2180,
      waitTime: '25분',
      zone: '미래의 나라',
      visitDurationMin: 8,
    ),

    Spot(
      id: 'a03',
      name: '후룸라이드',
      nameEn: 'Flume Ride',
      position: LatLng(37.4284, 127.0255),
      category: SpotCategory.attraction,
      themes: [SpotTheme.thrill, SpotTheme.family],
      icon: '🌊',
      description: '시원한 물줄기를 가르며 스릴을 만끽! 여름 필수 어트랙션',
      rating: 4.8,
      reviewCount: 4120,
      waitTime: '20분',
      zone: '세계의 광장',
      visitDurationMin: 12,
    ),

    Spot(
      id: 'a04',
      name: '자이로스윙',
      nameEn: 'Gyro Swing',
      position: LatLng(37.4272, 127.0241),
      category: SpotCategory.attraction,
      themes: [SpotTheme.thrill],
      icon: '🎡',
      description: '360도 회전하며 하늘을 나는 익스트림 스윙!',
      rating: 4.6,
      reviewCount: 1870,
      waitTime: '30분',
      zone: '모험의 나라',
      visitDurationMin: 6,
    ),

    Spot(
      id: 'a05',
      name: '킹바이킹',
      nameEn: 'King Viking',
      position: LatLng(37.4268, 127.0237),
      category: SpotCategory.attraction,
      themes: [SpotTheme.thrill, SpotTheme.family],
      icon: '⚓',
      description: '거대 해적선이 하늘 높이! 짜릿한 진자 운동의 묘미',
      rating: 4.4,
      reviewCount: 2560,
      waitTime: '10분',
      zone: '모험의 나라',
      visitDurationMin: 8,
    ),

    Spot(
      id: 'a06',
      name: '급류타기',
      nameEn: 'Rapid Ride',
      position: LatLng(37.4266, 127.0252),
      category: SpotCategory.attraction,
      themes: [SpotTheme.thrill, SpotTheme.family],
      icon: '🚤',
      description: '격렬한 급류를 타며 물보라 속으로! 여름 인기 1위',
      rating: 4.5,
      reviewCount: 3450,
      waitTime: '20분',
      zone: '모험의 나라',
      visitDurationMin: 10,
    ),

    Spot(
      id: 'a07',
      name: '대관람차',
      nameEn: 'Ferris Wheel',
      position: LatLng(37.4282, 127.0262),
      category: SpotCategory.attraction,
      themes: [SpotTheme.relaxed, SpotTheme.family, SpotTheme.photo],
      icon: '🎠',
      description: '서울랜드 전경을 한눈에! 낭만적인 뷰 포인트',
      rating: 4.7,
      reviewCount: 5200,
      waitTime: '없음',
      zone: '세계의 광장',
      visitDurationMin: 15,
    ),

    Spot(
      id: 'a08',
      name: '회전목마',
      nameEn: 'Carousel',
      position: LatLng(37.4278, 127.0258),
      category: SpotCategory.attraction,
      themes: [SpotTheme.family, SpotTheme.relaxed, SpotTheme.photo],
      icon: '🐴',
      description: '동화 속 클래식 회전목마. 사진 명소로도 유명!',
      rating: 4.6,
      reviewCount: 3100,
      waitTime: '없음',
      zone: '환상의 나라',
      visitDurationMin: 8,
    ),

    Spot(
      id: 'a09',
      name: '범퍼카',
      nameEn: 'Bumper Car',
      position: LatLng(37.4274, 127.0248),
      category: SpotCategory.attraction,
      themes: [SpotTheme.family],
      icon: '🚗',
      description: '신나게 부딪히며 즐기는 가족 필수 코스!',
      rating: 4.3,
      reviewCount: 2890,
      waitTime: '5분',
      zone: '환상의 나라',
      visitDurationMin: 8,
    ),

    Spot(
      id: 'a10',
      name: '해적소굴',
      nameEn: 'Pirate Cave',
      position: LatLng(37.4263, 127.0243),
      category: SpotCategory.attraction,
      themes: [SpotTheme.family],
      icon: '🏴‍☠️',
      description: '어린이 인기 1위! 해적 테마의 다크 라이드',
      rating: 4.4,
      reviewCount: 1560,
      waitTime: '10분',
      zone: '모험의 나라',
      visitDurationMin: 10,
    ),

    Spot(
      id: 'a11',
      name: '타임머신 5D 360',
      nameEn: 'Time Machine 5D',
      position: LatLng(37.4298, 127.0234),
      category: SpotCategory.attraction,
      themes: [SpotTheme.family, SpotTheme.thrill],
      icon: '🛸',
      description: '실감나는 5D 입체 영상과 360도 회전 체험!',
      rating: 4.2,
      reviewCount: 1230,
      waitTime: '15분',
      zone: '미래의 나라',
      visitDurationMin: 15,
    ),

    Spot(
      id: 'a12',
      name: '스카이X',
      nameEn: 'Sky X',
      position: LatLng(37.4300, 127.0238),
      category: SpotCategory.attraction,
      themes: [SpotTheme.thrill],
      icon: '🚀',
      description: '수직 낙하 타워! 서울랜드 스카이라인 위에서 자유낙하',
      rating: 4.6,
      reviewCount: 980,
      waitTime: '20분',
      zone: '미래의 나라',
      visitDurationMin: 6,
    ),

    Spot(
      id: 'a13',
      name: 'VR게이트',
      nameEn: 'VR Gate',
      position: LatLng(37.4276, 127.0266),
      category: SpotCategory.attraction,
      themes: [SpotTheme.family, SpotTheme.thrill],
      icon: '🥽',
      description: '최신 VR 기술로 가상현실 속 모험! 신규 어트랙션',
      rating: 4.3,
      reviewCount: 870,
      waitTime: '15분',
      zone: '세계의 광장',
      visitDurationMin: 15,
    ),

    Spot(
      id: 'a14',
      name: '빅회전목마',
      nameEn: 'Big Carousel',
      position: LatLng(37.4270, 127.0259),
      category: SpotCategory.attraction,
      themes: [SpotTheme.family, SpotTheme.relaxed],
      icon: '🎪',
      description: '어린이들의 천국! 대형 회전목마로 동화 속 나들이',
      rating: 4.5,
      reviewCount: 2100,
      waitTime: '없음',
      zone: '환상의 나라',
      visitDurationMin: 8,
    ),

    Spot(
      id: 'a15',
      name: '코끼리 열차',
      nameEn: 'Elephant Train',
      position: LatLng(37.4280, 127.0244),
      category: SpotCategory.attraction,
      themes: [SpotTheme.family, SpotTheme.relaxed],
      icon: '🐘',
      description: '서울랜드 전체를 한 바퀴! 이동하며 즐기는 파크 투어',
      rating: 4.4,
      reviewCount: 3400,
      waitTime: '5분',
      zone: '전체',
      visitDurationMin: 20,
    ),

    // ════════════════════════════════════════
    // 🍽️ 음식점 (12개)
    // ════════════════════════════════════════

    Spot(
      id: 'f01',
      name: '캘리포니아 피자',
      nameEn: 'California Pizza',
      position: LatLng(37.4277, 127.0260),
      category: SpotCategory.food,
      themes: [SpotTheme.food],
      icon: '🍕',
      description: '서울랜드 대표 레스토랑. 피자·파스타 인기!',
      rating: 4.1,
      reviewCount: 1560,
      priceRange: '₩9,000~16,000',
      zone: '세계의 광장',
      visitDurationMin: 30,
    ),

    Spot(
      id: 'f02',
      name: '장터 한식당',
      nameEn: 'Jangter Korean',
      position: LatLng(37.4282, 127.0250),
      category: SpotCategory.food,
      themes: [SpotTheme.food, SpotTheme.family],
      icon: '🍱',
      description: '소고기국밥, 해물파전, 분식! 민속촌 감성 한식',
      rating: 4.0,
      reviewCount: 2100,
      priceRange: '₩7,000~22,000',
      zone: '세계의 광장',
      visitDurationMin: 25,
    ),

    Spot(
      id: 'f03',
      name: '카레원',
      nameEn: 'Curry One',
      position: LatLng(37.4271, 127.0253),
      category: SpotCategory.food,
      themes: [SpotTheme.food],
      icon: '🍛',
      description: '줄 서서 먹는 인기 카레! 단체 학생 최애 맛집',
      rating: 4.3,
      reviewCount: 3200,
      priceRange: '₩9,000~13,000',
      zone: '환상의 나라',
      visitDurationMin: 20,
    ),

    Spot(
      id: 'f04',
      name: '부자분식',
      nameEn: 'Buja Snack',
      position: LatLng(37.4265, 127.0248),
      category: SpotCategory.food,
      themes: [SpotTheme.food],
      icon: '🌭',
      description: '왕닭꼬치, 소떡소떡, 슬러시! 간식 타임 핵심',
      rating: 4.2,
      reviewCount: 1870,
      priceRange: '₩3,000~6,000',
      zone: '모험의 나라',
      visitDurationMin: 15,
    ),

    Spot(
      id: 'f05',
      name: '롯데리아',
      nameEn: 'Lotteria',
      position: LatLng(37.4288, 127.0242),
      category: SpotCategory.food,
      themes: [SpotTheme.food, SpotTheme.family],
      icon: '🍔',
      description: '지구별 광장 위치. 테라스 좌석에서 루나파크 뷰!',
      rating: 3.9,
      reviewCount: 2450,
      priceRange: '₩5,000~10,000',
      zone: '미래의 나라',
      visitDurationMin: 20,
    ),

    Spot(
      id: 'f06',
      name: '쥬라기 바베큐',
      nameEn: 'Jurassic BBQ',
      position: LatLng(37.4260, 127.0258),
      category: SpotCategory.food,
      themes: [SpotTheme.food, SpotTheme.family],
      icon: '🍖',
      description: '공룡 다리(칠면조), 백립, 소시지! 크라켄 앞 파라솔 석',
      rating: 4.4,
      reviewCount: 2180,
      priceRange: '₩21,000~25,000',
      zone: '쥬라기랜드',
      visitDurationMin: 30,
    ),

    Spot(
      id: 'f07',
      name: '푸드트럭존',
      nameEn: 'Food Truck Zone',
      position: LatLng(37.4286, 127.0268),
      category: SpotCategory.food,
      themes: [SpotTheme.food],
      icon: '🚚',
      description: '오징어·브리또·닭강정·스테이크 다양한 길거리 음식!',
      rating: 4.2,
      reviewCount: 2780,
      priceRange: '₩4,000~15,000',
      zone: '루나힐',
      visitDurationMin: 15,
    ),

    Spot(
      id: 'f08',
      name: '캐루셀 라멘',
      nameEn: 'Carousel Ramen',
      position: LatLng(37.4275, 127.0255),
      category: SpotCategory.food,
      themes: [SpotTheme.food],
      icon: '🍜',
      description: '돈코츠·미소 라멘, 함박스테이크! 포토존까지 있는 일식당',
      rating: 4.2,
      reviewCount: 1340,
      priceRange: '₩12,000~14,000',
      zone: '환상의 나라',
      visitDurationMin: 25,
    ),

    Spot(
      id: 'f09',
      name: '바른치킨',
      nameEn: 'Barun Chicken',
      position: LatLng(37.4277, 127.0235),
      category: SpotCategory.food,
      themes: [SpotTheme.food, SpotTheme.family],
      icon: '🍗',
      description: '동문 근처 넓고 쾌적한 매장. 콘센트 있어 충전 가능!',
      rating: 4.1,
      reviewCount: 980,
      priceRange: '₩9,000~10,000',
      zone: '정문',
      visitDurationMin: 20,
    ),

    Spot(
      id: 'f10',
      name: '메르하바 케밥',
      nameEn: 'Merhaba Kebab',
      position: LatLng(37.4274, 127.0233),
      category: SpotCategory.food,
      themes: [SpotTheme.food],
      icon: '🌯',
      description: '터키 아이스크림 퍼포먼스로 아이들 인기 폭발! 케밥 7,000원',
      rating: 4.3,
      reviewCount: 1560,
      priceRange: '₩5,000~7,000',
      zone: '정문',
      visitDurationMin: 10,
    ),

    Spot(
      id: 'f11',
      name: '포메인',
      nameEn: 'Pho Mayne',
      position: LatLng(37.4279, 127.0238),
      category: SpotCategory.food,
      themes: [SpotTheme.food],
      icon: '🍝',
      description: '베트남식 쌀국수 전문점. 소고기 쌀국수 인기 1위!',
      rating: 4.0,
      reviewCount: 1230,
      priceRange: '₩12,000~17,500',
      zone: '정문',
      visitDurationMin: 25,
    ),

    Spot(
      id: 'f12',
      name: '초당 순두부',
      nameEn: 'Chodang Tofu',
      position: LatLng(37.4269, 127.0264),
      category: SpotCategory.food,
      themes: [SpotTheme.food, SpotTheme.family],
      icon: '🥘',
      description: '순두부찌개·김치찌개·왕갈비탕. 정갈한 한식 보양식!',
      rating: 4.1,
      reviewCount: 870,
      priceRange: '₩10,000~19,000',
      zone: '키즈팰리스',
      visitDurationMin: 30,
    ),

    // ════════════════════════════════════════
    // 📸 포토스팟 (30개)
    // ════════════════════════════════════════

    Spot(
      id: 'p01',
      name: '루나파크 불빛 아치',
      nameEn: 'Luna Park Light Arch',
      position: LatLng(37.4283, 127.0247),
      category: SpotCategory.photo,
      themes: [SpotTheme.photo],
      icon: '🌟',
      description: '야간 루나파크 메인 입구 LED 아치. 인스타 1위 포토스팟!',
      rating: 4.9,
      reviewCount: 6700,
      photoTip: '야간 6시 이후 방문, 아치 정중앙에서 광각 촬영',
      zone: '루나파크',
      visitDurationMin: 10,
    ),

    Spot(
      id: 'p02',
      name: '대관람차 골든아워',
      nameEn: 'Ferris Wheel Golden Hour',
      position: LatLng(37.4283, 127.0263),
      category: SpotCategory.photo,
      themes: [SpotTheme.photo, SpotTheme.relaxed],
      icon: '🌅',
      description: '석양 무렵 대관람차 배경 샷. 커플 & 솔로 사진 모두 최적!',
      rating: 4.8,
      reviewCount: 5400,
      photoTip: '일몰 30분 전 방문, 대관람차 왼편 벤치 앞 위치',
      zone: '세계의 광장',
      visitDurationMin: 15,
    ),

    Spot(
      id: 'p03',
      name: '벚꽃 터널 (봄)',
      nameEn: 'Cherry Blossom Tunnel',
      position: LatLng(37.4290, 127.0258),
      category: SpotCategory.photo,
      themes: [SpotTheme.photo, SpotTheme.relaxed],
      icon: '🌸',
      description: '봄 시즌 한정 벚꽃 터널 포토존. 3~4월이면 줄 서는 명소',
      rating: 4.9,
      reviewCount: 8200,
      photoTip: '3월 말~4월 초 오전. 터널 중간에서 양쪽 방향 촬영',
      zone: '세계의 광장',
      visitDurationMin: 20,
    ),

    Spot(
      id: 'p04',
      name: '회전목마 동화 포토존',
      nameEn: 'Carousel Fairy Tale',
      position: LatLng(37.4278, 127.0257),
      category: SpotCategory.photo,
      themes: [SpotTheme.photo, SpotTheme.family],
      icon: '🎠',
      description: '클래식 회전목마 앞 동화 컨셉 포토존. 아이 사진 최적!',
      rating: 4.7,
      reviewCount: 4100,
      photoTip: '탑승 전 정면에서 측면 45도 각도, 낮 시간 자연광 활용',
      zone: '환상의 나라',
      visitDurationMin: 10,
    ),

    Spot(
      id: 'p05',
      name: '세계의 광장 분수대',
      nameEn: 'World Plaza Fountain',
      position: LatLng(37.4280, 127.0265),
      category: SpotCategory.photo,
      themes: [SpotTheme.photo, SpotTheme.relaxed],
      icon: '⛲',
      description: '파크 중심 대형 분수대. 여름엔 물놀이 장면도 인기!',
      rating: 4.6,
      reviewCount: 3800,
      photoTip: '낮 12시 분수쇼 시간에 역광 실루엣 촬영 추천',
      zone: '세계의 광장',
      visitDurationMin: 10,
    ),

    Spot(
      id: 'p06',
      name: '미래의 나라 우주선',
      nameEn: 'Spaceship Sculpture',
      position: LatLng(37.4296, 127.0235),
      category: SpotCategory.photo,
      themes: [SpotTheme.photo],
      icon: '🛸',
      description: '미래의 나라 입구 대형 우주선 조형물. SF 감성 샷!',
      rating: 4.5,
      reviewCount: 2900,
      photoTip: '로우앵글(아래서 위로) 촬영시 우주선 규모감 극대화',
      zone: '미래의 나라',
      visitDurationMin: 8,
    ),

    Spot(
      id: 'p07',
      name: '루나힐 야경 뷰포인트',
      nameEn: 'Luna Hill Night View',
      position: LatLng(37.4287, 127.0270),
      category: SpotCategory.photo,
      themes: [SpotTheme.photo],
      icon: '🌃',
      description: '파크 뒤편 언덕에서 서울랜드 야경 전체가 한눈에!',
      rating: 4.8,
      reviewCount: 5100,
      photoTip: '야간 7시 이후, 광각 렌즈 또는 파노라마 모드',
      zone: '루나힐',
      visitDurationMin: 15,
    ),

    Spot(
      id: 'p08',
      name: '오징어게임 세트장',
      nameEn: 'Squid Game Set',
      position: LatLng(37.4273, 127.0243),
      category: SpotCategory.photo,
      themes: [SpotTheme.photo],
      icon: '🦑',
      description: '넷플릭스 오징어게임2 촬영지! 달고나 게임판 포토존',
      rating: 4.9,
      reviewCount: 9200,
      photoTip: '달고나 도구 들고 놀이판 앞에서 캐릭터 컨셉 촬영',
      zone: '모험의 나라',
      visitDurationMin: 20,
    ),

    Spot(
      id: 'p09',
      name: '단풍 산책로 (가을)',
      nameEn: 'Autumn Leaf Path',
      position: LatLng(37.4288, 127.0261),
      category: SpotCategory.photo,
      themes: [SpotTheme.photo, SpotTheme.relaxed],
      icon: '🍂',
      description: '10~11월 단풍이 물드는 파크 내 산책로. 가을 감성 최고!',
      rating: 4.7,
      reviewCount: 3600,
      photoTip: '10월 말 오전, 역광으로 단풍잎 빛 투과 촬영',
      zone: '삼천리 동산',
      visitDurationMin: 15,
    ),

    Spot(
      id: 'p10',
      name: '쥬라기랜드 공룡 포토존',
      nameEn: 'Jurassic Land Dinos',
      position: LatLng(37.4261, 127.0256),
      category: SpotCategory.photo,
      themes: [SpotTheme.photo, SpotTheme.family],
      icon: '🦕',
      description: '실물 크기 움직이는 공룡 모형 앞! 아이들 최애 포토존',
      rating: 4.6,
      reviewCount: 4400,
      photoTip: '공룡 머리가 움직이는 타이밍에 맞춰 반응샷 촬영',
      zone: '쥬라기랜드',
      visitDurationMin: 15,
    ),

    Spot(
      id: 'p11',
      name: '불빛축제 거리 (야간)',
      nameEn: 'Light Festival Street',
      position: LatLng(37.4285, 127.0252),
      category: SpotCategory.photo,
      themes: [SpotTheme.photo],
      icon: '✨',
      description: '야간 LED 불빛축제 메인 거리. 겨울 시즌 필수 포토스팟',
      rating: 4.9,
      reviewCount: 7800,
      photoTip: '야간 6시 이후, ISO 낮추고 장노출 or 폰 야간모드',
      zone: '루나파크',
      visitDurationMin: 20,
    ),

    Spot(
      id: 'p12',
      name: '미러볼 광장',
      nameEn: 'Mirror Ball Plaza',
      position: LatLng(37.4278, 127.0269),
      category: SpotCategory.photo,
      themes: [SpotTheme.photo],
      icon: '🪩',
      description: '대형 미러볼 설치물. 반짝이는 빛 반사로 환상적인 셀피!',
      rating: 4.7,
      reviewCount: 3200,
      photoTip: '맑은 날 낮 시간 미러볼 정면에서 선글라스 착용 촬영',
      zone: '세계의 광장',
      visitDurationMin: 10,
    ),

    Spot(
      id: 'p13',
      name: '은하열차 역 플랫폼',
      nameEn: 'Galaxy Train Platform',
      position: LatLng(37.4292, 127.0230),
      category: SpotCategory.photo,
      themes: [SpotTheme.photo],
      icon: '🚂',
      description: '복고풍 역 플랫폼 컨셉 포토존. 빈티지 감성 인증샷!',
      rating: 4.6,
      reviewCount: 2800,
      photoTip: '플랫폼 의자에 앉아 열차 방향 바라보는 구도 추천',
      zone: '미래의 나라',
      visitDurationMin: 10,
      hasEasterEgg: true,
    ),

    Spot(
      id: 'p14',
      name: '해적선 포토존',
      nameEn: 'Pirate Ship Photo',
      position: LatLng(37.4265, 127.0240),
      category: SpotCategory.photo,
      themes: [SpotTheme.photo, SpotTheme.family],
      icon: '🏴‍☠️',
      description: '킹바이킹 옆 해적선 세트. 아이들 모험가 컨셉 사진!',
      rating: 4.4,
      reviewCount: 2100,
      photoTip: '해적 깃발 배경으로 점프샷, 과감한 포즈 추천',
      zone: '모험의 나라',
      visitDurationMin: 10,
    ),

    Spot(
      id: 'p15',
      name: '눈썰매장 설경 (겨울)',
      nameEn: 'Snow Sled Scenery',
      position: LatLng(37.4259, 127.0262),
      category: SpotCategory.photo,
      themes: [SpotTheme.photo, SpotTheme.family],
      icon: '⛷️',
      description: '겨울 한정 눈썰매장. 눈 덮인 서울랜드 설경 포토스팟',
      rating: 4.7,
      reviewCount: 4500,
      photoTip: '눈 쌓인 나무 배경 활용, 털모자+장갑 착용 겨울 감성샷',
      zone: '삼천리 동산',
      visitDurationMin: 30,
    ),

    Spot(
      id: 'p16',
      name: '무지개 게이트',
      nameEn: 'Rainbow Gate',
      position: LatLng(37.4276, 127.0241),
      category: SpotCategory.photo,
      themes: [SpotTheme.photo],
      icon: '🌈',
      description: '무지개색 아치형 게이트. 통과하며 찍는 트렌디 인증샷!',
      rating: 4.5,
      reviewCount: 3100,
      photoTip: '아치 가운데 서서 정면 촬영, 화사한 색감 필터 추천',
      zone: '환상의 나라',
      visitDurationMin: 8,
    ),

    Spot(
      id: 'p17',
      name: '앨리스 원더하우스',
      nameEn: 'Alice Wonderhouse',
      position: LatLng(37.4270, 127.0251),
      category: SpotCategory.photo,
      themes: [SpotTheme.photo, SpotTheme.family],
      icon: '🐇',
      description: '이상한 나라의 앨리스 테마 실내 포토존. 키홀, 카드병사 등',
      rating: 4.6,
      reviewCount: 2700,
      photoTip: '카드병사 사이에 끼어서 찍는 구도가 인기 최고!',
      zone: '환상의 나라',
      visitDurationMin: 20,
    ),

    Spot(
      id: 'p18',
      name: '대공원 연결 숲길',
      nameEn: 'Grand Park Trail',
      position: LatLng(37.4302, 127.0246),
      category: SpotCategory.photo,
      themes: [SpotTheme.photo, SpotTheme.relaxed],
      icon: '🌳',
      description: '서울대공원과 이어지는 숲 산책로. 자연 감성 셀피!',
      rating: 4.5,
      reviewCount: 2400,
      photoTip: '역광 골든아워 활용, 나뭇잎 사이 빛 줄기 배경',
      zone: '삼천리 동산',
      visitDurationMin: 15,
    ),

    Spot(
      id: 'p19',
      name: '캐릭터 타운 포토월',
      nameEn: 'Character Town Photo Wall',
      position: LatLng(37.4267, 127.0260),
      category: SpotCategory.photo,
      themes: [SpotTheme.photo, SpotTheme.family],
      icon: '🎭',
      description: '서울랜드 캐릭터들이 그려진 대형 포토월. 아이 사진 필수!',
      rating: 4.4,
      reviewCount: 3500,
      photoTip: '캐릭터 옆에 같은 포즈 따라하기가 인기 챌린지!',
      zone: '캐릭터 타운',
      visitDurationMin: 10,
    ),

    Spot(
      id: 'p20',
      name: '하늘 구름다리',
      nameEn: 'Sky Cloud Bridge',
      position: LatLng(37.4294, 127.0262),
      category: SpotCategory.photo,
      themes: [SpotTheme.photo],
      icon: '☁️',
      description: '파크 후문 근처 흰 구름 조형물 다리. 하늘 배경 청량 샷!',
      rating: 4.6,
      reviewCount: 2900,
      photoTip: '맑은 날 낮, 파란 하늘 배경으로 흰옷 착용 추천',
      zone: '루나힐',
      visitDurationMin: 10,
    ),

    Spot(
      id: 'p21',
      name: '네온사인 포토터널',
      nameEn: 'Neon Sign Tunnel',
      position: LatLng(37.4284, 127.0269),
      category: SpotCategory.photo,
      themes: [SpotTheme.photo],
      icon: '💡',
      description: '형형색색 네온사인 터널. 야간 야광 인증샷 맛집!',
      rating: 4.8,
      reviewCount: 5600,
      photoTip: '야간 전용. 슬로우 셔터나 폰 야간 모드로 빛 번짐 표현',
      zone: '루나파크',
      visitDurationMin: 10,
    ),

    Spot(
      id: 'p22',
      name: '수변 공원 호수뷰',
      nameEn: 'Lakeside Park View',
      position: LatLng(37.4258, 127.0267),
      category: SpotCategory.photo,
      themes: [SpotTheme.photo, SpotTheme.relaxed],
      icon: '🏞️',
      description: '파크 남측 수변 공원. 호수 반영샷이 압도적으로 아름다움!',
      rating: 4.7,
      reviewCount: 3100,
      photoTip: '이른 아침 물안개 낄 때 최고. 호수 반영 구도 추천',
      zone: '삼천리 동산',
      visitDurationMin: 15,
    ),

    Spot(
      id: 'p23',
      name: '꽃밭 정원 (시즌별)',
      nameEn: 'Seasonal Flower Garden',
      position: LatLng(37.4262, 127.0252),
      category: SpotCategory.photo,
      themes: [SpotTheme.photo, SpotTheme.relaxed],
      icon: '🌺',
      description: '계절별 꽃이 피는 정원. 튤립·해바라기·코스모스',
      rating: 4.6,
      reviewCount: 4200,
      photoTip: '꽃밭 한가운데 앉아서 로우앵글 근접 촬영 추천',
      zone: '삼천리 동산',
      visitDurationMin: 15,
    ),

    Spot(
      id: 'p24',
      name: '하이킹 전망대',
      nameEn: 'Hiking Viewpoint',
      position: LatLng(37.4305, 127.0256),
      category: SpotCategory.photo,
      themes: [SpotTheme.photo, SpotTheme.relaxed],
      icon: '🏔️',
      description: '파크 북쪽 전망대에서 서울대공원 + 관악산 전경!',
      rating: 4.5,
      reviewCount: 1800,
      photoTip: '맑은 날 오전, 관악산 배경으로 파노라마 촬영',
      zone: '삼천리 동산',
      visitDurationMin: 20,
    ),

    Spot(
      id: 'p25',
      name: '레트로 게임 포토존',
      nameEn: 'Retro Game Photo',
      position: LatLng(37.4269, 127.0246),
      category: SpotCategory.photo,
      themes: [SpotTheme.photo],
      icon: '🎮',
      description: '레트로 오락실 스타일 포토존. 90년대 감성 소환!',
      rating: 4.4,
      reviewCount: 2300,
      photoTip: '80~90년대 복고 스타일 의상 착용 시 분위기 극대화',
      zone: '미래의 나라',
      visitDurationMin: 10,
    ),

    Spot(
      id: 'p26',
      name: '서울랜드 정문 브랜드샷',
      nameEn: 'Main Gate Brand Shot',
      position: LatLng(37.4275, 127.0232),
      category: SpotCategory.photo,
      themes: [SpotTheme.photo],
      icon: '🏰',
      description: '서울랜드 정문 간판 배경. 방문 인증 필수 포토스팟!',
      rating: 4.6,
      reviewCount: 7800,
      photoTip: '정문 계단 아래서 간판 위로 향하는 구도, 입장 전 필수',
      zone: '정문',
      visitDurationMin: 5,
    ),

    Spot(
      id: 'p27',
      name: '버블 포토존',
      nameEn: 'Bubble Photo Zone',
      position: LatLng(37.4289, 127.0248),
      category: SpotCategory.photo,
      themes: [SpotTheme.photo],
      icon: '🫧',
      description: '대형 투명 버블 안에 들어가서 찍는 신기한 포토존!',
      rating: 4.7,
      reviewCount: 3400,
      photoTip: '버블 안에서 밖을 바라보는 구도, 어안렌즈 효과 연출',
      zone: '환상의 나라',
      visitDurationMin: 10,
    ),

    Spot(
      id: 'p28',
      name: '하늘그네 배경샷',
      nameEn: 'Sky Swing Background',
      position: LatLng(37.4291, 127.0244),
      category: SpotCategory.photo,
      themes: [SpotTheme.photo, SpotTheme.thrill],
      icon: '🕊️',
      description: '자이로스윙 탑승 전 배경샷. 하늘 배경 인생 사진 명소!',
      rating: 4.6,
      reviewCount: 2600,
      photoTip: '자이로스윙 대기줄 옆 포토존, 하늘 바라보며 양팔 벌리기',
      zone: '모험의 나라',
      visitDurationMin: 8,
    ),

    Spot(
      id: 'p29',
      name: '키즈 스탬프 랠리 존',
      nameEn: 'Kids Stamp Rally',
      position: LatLng(37.4264, 127.0266),
      category: SpotCategory.photo,
      themes: [SpotTheme.photo, SpotTheme.family],
      icon: '🎒',
      description: '파크 내 스탬프 랠리 완성 후 기념 포토존. 아이 성취감 UP!',
      rating: 4.5,
      reviewCount: 1900,
      photoTip: '스탬프북 들고 완성본 펼쳐서 기념 촬영',
      zone: '캐릭터 타운',
      visitDurationMin: 10,
    ),

    Spot(
      id: 'p30',
      name: '야간 퍼레이드 촬영 포인트',
      nameEn: 'Night Parade Shot',
      position: LatLng(37.4279, 127.0248),
      category: SpotCategory.photo,
      themes: [SpotTheme.photo],
      icon: '🎆',
      description: '퍼레이드 행렬이 지나가는 최적의 촬영 포인트!',
      rating: 4.8,
      reviewCount: 5300,
      photoTip: '퍼레이드 10분 전 도착, 세계의 광장 중앙 4열 이내',
      zone: '세계의 광장',
      visitDurationMin: 30,
    ),
  ];

  // 카테고리별 필터
  static List<Spot> byCategory(SpotCategory category) =>
      all.where((s) => s.category == category).toList();

  // 테마별 필터
  static List<Spot> byTheme(SpotTheme theme) =>
      all.where((s) => s.themes.contains(theme)).toList();

  // 개인화 동선 추천 (동행자 타입 + 선호도 기반)
  static List<Spot> recommendedRoute({
    required String companionType,
    required List<String> preferences,
    int maxSpots = 8,
  }) {
    final List<SpotTheme> preferredThemes = [];

    switch (companionType) {
      case '가족':
        preferredThemes.addAll([SpotTheme.family, SpotTheme.relaxed]);
        break;
      case '연인':
        preferredThemes.addAll([SpotTheme.photo, SpotTheme.relaxed]);
        break;
      case '친구':
        preferredThemes.addAll([SpotTheme.thrill, SpotTheme.food]);
        break;
      case '혼자':
        preferredThemes.addAll([SpotTheme.photo, SpotTheme.thrill]);
        break;
    }

    for (final pref in preferences) {
      if (pref.contains('스릴')) preferredThemes.add(SpotTheme.thrill);
      if (pref.contains('사진') || pref.contains('인생샷')) preferredThemes.add(SpotTheme.photo);
      if (pref.contains('여유') || pref.contains('힐링')) preferredThemes.add(SpotTheme.relaxed);
      if (pref.contains('먹')) preferredThemes.add(SpotTheme.food);
    }

    final scored = all.map((spot) {
      int score = 0;
      for (final theme in spot.themes) {
        if (preferredThemes.contains(theme)) score += 2;
      }
      if (spot.rating >= 4.7) score += 3;
      if (spot.rating >= 4.5) score += 1;
      return MapEntry(spot, score);
    }).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final result = <Spot>[];
    final attractions = scored.where((e) => e.key.category == SpotCategory.attraction).take(4).map((e) => e.key).toList();
    final photos = scored.where((e) => e.key.category == SpotCategory.photo).take(3).map((e) => e.key).toList();
    final foods = scored.where((e) => e.key.category == SpotCategory.food).take(2).map((e) => e.key).toList();

    result.addAll(attractions);
    result.addAll(photos);
    result.addAll(foods);

    return _sortByProximity(result.take(maxSpots).toList());
  }

  static List<Spot> _sortByProximity(List<Spot> spots) {
    if (spots.isEmpty) return spots;
    final result = <Spot>[];
    final remaining = List<Spot>.from(spots);
    result.add(remaining.removeAt(0));
    while (remaining.isNotEmpty) {
      final last = result.last;
      double minDist = double.infinity;
      int minIdx = 0;
      for (int i = 0; i < remaining.length; i++) {
        final d = _dist(last.position, remaining[i].position);
        if (d < minDist) { minDist = d; minIdx = i; }
      }
      result.add(remaining.removeAt(minIdx));
    }
    return result;
  }

  static double _dist(LatLng a, LatLng b) {
    final dlat = a.latitude - b.latitude;
    final dlng = a.longitude - b.longitude;
    return dlat * dlat + dlng * dlng;
  }
}
