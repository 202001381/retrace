/// 옵션 D — 데이터 모델은 한국어 유지하면서 영어 모드에서 메타데이터만 영문화.
/// 어트랙션 zone, 이벤트 태그, 시간 표기 변환 헬퍼.
library;

import 'package:flutter/widgets.dart';

import '../l10n/generated/app_localizations.dart';

/// 한국어 zone 명 → locale 따라 영문/한글.
/// 매핑 안 되는 zone (오타·신규) 은 원본 그대로.
String localizedZone(BuildContext context, String koZone) {
  final l = AppL10n.of(context);
  switch (koZone) {
    case '모험의 나라':
      return l.zone_adventure;
    case '미래의 나라':
      return l.zone_future;
    case '삼천리 동산':
      return l.zone_samcheonri;
    case '세계의 광장':
      return l.zone_world_plaza;
    case '캐릭터 타운':
      return l.zone_character_town;
    default:
      return koZone;
  }
}

/// 이벤트 태그 (D-DAY/인기/신규/...) — `'[D-DAY]'` 형식 그대로 반환.
String localizedEventTag(BuildContext context, String koTagWithBrackets) {
  final l = AppL10n.of(context);
  // 대괄호 제거 후 매칭.
  final raw = koTagWithBrackets.replaceAll(RegExp(r'[\[\]]'), '');
  final mapped = switch (raw) {
    'D-DAY' => l.event_tag_dday,
    '인기' => l.event_tag_popular,
    '신규' => l.event_tag_new,
    '야간' => l.event_tag_night,
    '주말' => l.event_tag_weekend,
    '가족' => l.event_tag_family,
    _ => raw,
  };
  return '[$mapped]';
}

/// "오후 2:00" / "오전 9:30" → locale 따라 "2:00 PM" / "9:30 AM".
/// 매칭 안 되는 포맷은 원본 그대로.
String localizedTime(BuildContext context, String koTime) {
  final l = AppL10n.of(context);
  final pmMatch = RegExp(r'^오후\s+(\d{1,2}:\d{2})$').firstMatch(koTime);
  if (pmMatch != null) return l.time_pm(pmMatch.group(1)!);
  final amMatch = RegExp(r'^오전\s+(\d{1,2}:\d{2})$').firstMatch(koTime);
  if (amMatch != null) return l.time_am(amMatch.group(1)!);
  return koTime;
}
