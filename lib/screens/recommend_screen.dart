import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/attraction.dart';
import '../services/onboarding_service.dart';
import 'onboarding_screen.dart'; // 조건 변경 시 이동할 온보딩 화면

class RecommendScreen extends StatefulWidget {
  const RecommendScreen({super.key});
  @override
  State<RecommendScreen> createState() => _RecommendScreenState();
}

class _RecommendScreenState extends State<RecommendScreen> {
  SurveyAnswers? _answers;
  List<Attraction> _top3 = const [];
  bool _loading = true;

  // 하단 카테고리 및 세부 필터용 상태 변수 (값은 데이터 일치를 위해 한국어 키 유지).
  String _selectedCategory = '어트랙션';
  final List<String> _categories = ['어트랙션', '음식점', '공연', '편의시설'];

  String _localCategory(BuildContext context, String cat) {
    final l = AppL10n.of(context)!;
    switch (cat) {
      case '어트랙션': return l.cat_attraction;
      case '음식점':   return l.cat_restaurant;
      case '공연':     return l.cat_show;
      case '편의시설': return l.cat_facility;
    }
    return cat;
  }

  // 🚀 기획서 반영: 세부 토글 필터 상태
  bool _showOperatingOnly = false;
  bool _showEasterEggOnly = false;

  @override
  void initState() {
    super.initState();
    _loadAndCompute();
  }

  Future<void> _loadAndCompute() async {
    setState(() => _loading = true);
    final ans = await OnboardingService.read();
    setState(() {
      _answers = ans;
      _top3 = _computeTop3(ans);
      _loading = false;
    });
  }

  /// 설문 응답 기반 동선 스코어링 (기획서 로직 100% 반영됨)
  List<Attraction> _computeTop3(SurveyAnswers? ans) {
    final answers = ans;
    Iterable<Attraction> pool = kAttractions.where((a) => a.category == '어트랙션');

    // 유아 동반 시 키 제한 필터링
    if (answers?.hasInfant ?? false) {
      pool = pool.where((a) => a.heightLimit == 0);
    }

    const center = (lat: 37.4279, lng: 127.0247);
    double distScore(Attraction a) {
      final dLat = a.lat - center.lat;
      final dLng = a.lng - center.lng;
      final d2 = dLat * dLat + dLng * dLng;
      return 1.0 / (1.0 + d2 * 1e6);
    }

    final scored = pool.map((a) {
      double score = 0;
      score += (60 - a.waitMinutes).clamp(-20, 60).toDouble();

      if (answers != null) {
        if (answers.hasInfant) {
          if (a.indoor) score += 30; // 실내 가중치 상향
          score += distScore(a) * 25;
        }
        if (answers.hasChild && a.thrillLevel <= 2) score += 20;
        if (answers.hasSenior) {
          if (a.thrillLevel <= 3) score += 10;
          score += distScore(a) * 8;
        }

        // 스릴 선호 가중치 상향
        if (answers.favoriteType == FavoriteType.thrill && a.thrillLevel >= 4) score += 20;
        if (answers.favoriteType == FavoriteType.family && a.thrillLevel <= 2) score += 20;

        switch (answers.purpose) {
          case VisitPurpose.rides:
            score += a.thrillLevel * 2.0;
            break;
          case VisitPurpose.picnic:
            if (a.thrillLevel <= 2) score += 8;
            break;
          case VisitPurpose.kidsOuting:
            if (a.heightLimit == 0) score += 10;
            if (a.indoor) score += 6;
            break;
          case VisitPurpose.date:
            if (a.thrillLevel >= 3 && a.thrillLevel <= 4) score += 10;
            break;
        }
      }

      return (attraction: a, score: score);
    }).toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    return scored.take(3).map((e) => e.attraction).toList();
  }

  void _goToOnboarding() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OnboardingScreen(
          onDone: (exitStatus) {
            Navigator.pop(context);
          },
        ),
      ),
    ).then((_) {
      _loadAndCompute();
    });
  }

  @override
  Widget build(BuildContext context) {
    // 🚀 기획서 반영: 세부 필터링 로직 적용
    final filteredAttractions = kAttractions.where((a) {
      if (a.category != _selectedCategory) return false;
      if (_showEasterEggOnly && !a.hasEasterEgg) return false;
      // 모델에 isOperating이 없다면 대기시간이 0 이상인 것을 운영 중으로 임시 간주
      if (_showOperatingOnly && a.waitMinutes < 0) return false;
      return true;
    }).toList();

    return ColoredBox(
      color: const Color(0xFFF7F7F7),
      child: SafeArea(
        bottom: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFE60012)))
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                children: [
                  _HeaderRow(
                    onRefresh: _loadAndCompute,
                    onChangeCondition: _goToOnboarding,
                  ),
                  const SizedBox(height: 16),
                  _SummaryChips(answers: _answers),
                  const SizedBox(height: 20),

                  if (_top3.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                      child: Center(
                        child: Text(AppL10n.of(context)!.map_no_attractions_match, style: const TextStyle(color: Color(0xFF888888), fontWeight: FontWeight.w700)),
                      ),
                    )
                  else
                    ..._top3.asMap().entries.map((e) => Padding(
                          padding: EdgeInsets.only(bottom: e.key == _top3.length - 1 ? 0 : 12),
                          child: _AttractionCard(index: e.key + 1, item: e.value),
                        )),

                  const SizedBox(height: 32),
                  const Divider(height: 1, color: Color(0xFFDDDDDD)),
                  const SizedBox(height: 24),

                  Text(AppL10n.of(context)!.rec_browse_all,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF1F1F1F))),
                  const SizedBox(height: 16),

                  // 메인 카테고리 칩
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _categories.map((cat) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(_localCategory(context, cat),
                            style: TextStyle(fontWeight: FontWeight.w700, color: _selectedCategory == cat ? Colors.white : const Color(0xFF555555))),
                          selected: _selectedCategory == cat,
                          selectedColor: const Color(0xFFE60012),
                          backgroundColor: Colors.white,
                          side: BorderSide(color: _selectedCategory == cat ? const Color(0xFFE60012) : const Color(0xFFDDDDDD)),
                          showCheckmark: false,
                          onSelected: (selected) {
                            if (selected) setState(() => _selectedCategory = cat);
                          },
                        ),
                      )).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 🚀 기획서 반영: 운영중 / 이스터에그 세부 필터
                  Row(
                    children: [
                      FilterChip(
                        label: Text(AppL10n.of(context)!.rec_filter_operating),
                        selected: _showOperatingOnly,
                        onSelected: (val) => setState(() => _showOperatingOnly = val),
                        backgroundColor: Colors.white,
                        selectedColor: const Color(0xFFE60012).withOpacity(0.1),
                        side: BorderSide(color: _showOperatingOnly ? const Color(0xFFE60012) : const Color(0xFFDDDDDD)),
                        labelStyle: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _showOperatingOnly ? const Color(0xFFE60012) : const Color(0xFF888888)
                        ),
                        showCheckmark: false,
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: Text(AppL10n.of(context)!.rec_filter_egg),
                        selected: _showEasterEggOnly,
                        onSelected: (val) => setState(() => _showEasterEggOnly = val),
                        backgroundColor: Colors.white,
                        selectedColor: const Color(0xFFFFB800).withOpacity(0.15),
                        side: BorderSide(color: _showEasterEggOnly ? const Color(0xFFFFB800) : const Color(0xFFDDDDDD)),
                        labelStyle: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _showEasterEggOnly ? const Color(0xFFD49A00) : const Color(0xFF888888)
                        ),
                        showCheckmark: false,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (filteredAttractions.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Center(child: Text(AppL10n.of(context)!.no_facility_match, style: const TextStyle(color: Colors.grey))),
                    )
                  else
                    ...filteredAttractions.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _AllAttractionCard(item: item),
                    )),
                ],
              ),
      ),
    );
  }
}

// ----------------------------------------------------
// UI 위젯들
// ----------------------------------------------------

class _HeaderRow extends StatelessWidget {
  final VoidCallback onRefresh;
  final VoidCallback onChangeCondition;

  const _HeaderRow({required this.onRefresh, required this.onChangeCondition});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome_rounded, color: Color(0xFFE60012), size: 22),
          const SizedBox(width: 6),
          const Text('Re·Trace', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFFE60012))),
          const Spacer(),
          TextButton(
            onPressed: onChangeCondition,
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: Size.zero),
            child: Text(AppL10n.of(context)!.home_change_conditions, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF888888))),
          ),
          const SizedBox(width: 4),
          OutlinedButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: Text(AppL10n.of(context)!.common_refresh, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1E3158),
              side: const BorderSide(color: Color(0xFFDDDDDD)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryChips extends StatelessWidget {
  final SurveyAnswers? answers;
  const _SummaryChips({required this.answers});

  @override
  Widget build(BuildContext context) {
    if (answers == null) return Text(AppL10n.of(context)!.no_survey_default, style: const TextStyle(color: Color(0xFF888888), fontSize: 12));
    final a = answers!;
    final memberText = MemberCategory.values.where((c) => a.count(c) > 0).map((c) => '${c.emoji}${a.count(c)}').join(' ');
    final chips = <String>[
      '👥 총 ${a.total}명',
      if (memberText.isNotEmpty) memberText,
      if (a.favoriteType != null) '🎯 ${a.favoriteType}',
      if (a.purpose != null) '📍 ${a.purpose}',
    ];
    return Wrap(spacing: 6, runSpacing: 6, children: chips.map((t) => _Chip(text: t)).toList());
  }
}

class _Chip extends StatelessWidget {
  final String text;
  const _Chip({required this.text});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(99), border: Border.all(color: const Color(0xFFEEEEEE))),
      child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1F1F1F))),
    );
  }
}

String _crowdLabel(BuildContext context, int waitMinutes) {
  final l = AppL10n.of(context)!;
  if (waitMinutes <= 5) return l.home_crowd_low;
  if (waitMinutes <= 20) return l.home_crowd_mid;
  return l.home_crowd_high;
}

class _AttractionCard extends StatelessWidget {
  final int index;
  final Attraction item;
  const _AttractionCard({required this.index, required this.item});

  Color get _crowdColor {
    switch (item.crowdLabel) {
      case '여유': return const Color(0xFF4CAF50);
      case '보통': return const Color(0xFFFFC107);
      default: return const Color(0xFFE60012);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))]),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 32, height: 32, decoration: const BoxDecoration(color: Color(0xFFE60012), shape: BoxShape.circle), alignment: Alignment.center, child: Text('$index', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900))),
          const SizedBox(width: 12),
          Container(width: 56, height: 56, decoration: BoxDecoration(color: const Color(0xFFE60012).withOpacity(0.08), borderRadius: BorderRadius.circular(14)), alignment: Alignment.center, child: Text(item.icon, style: const TextStyle(fontSize: 28))),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(item.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF1F1F1F))),
                const SizedBox(height: 4),
                Text('${item.zone} · ${item.indoor ? AppL10n.of(context)!.common_indoor : AppL10n.of(context)!.common_outdoor} · ${AppL10n.of(context)!.rec_thrill_level(item.thrillLevel)}', style: const TextStyle(fontSize: 11, color: Color(0xFF888888))),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: _crowdColor.withOpacity(0.12), borderRadius: BorderRadius.circular(99)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 6, height: 6, decoration: BoxDecoration(color: _crowdColor, shape: BoxShape.circle)), const SizedBox(width: 4), Text(_crowdLabel(context, item.waitMinutes), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _crowdColor))]),
                    ),
                    Text(AppL10n.of(context)!.rec_wait_eta_short(item.waitMinutes), style: const TextStyle(fontSize: 11, color: Color(0xFF555555), fontWeight: FontWeight.w700)),
                    if (item.heightLimit > 0) Text('📏 ${item.heightLimit}cm+', style: const TextStyle(fontSize: 11, color: Color(0xFF555555), fontWeight: FontWeight.w700)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AllAttractionCard extends StatelessWidget {
  final Attraction item;
  const _AllAttractionCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(color: const Color(0xFFF0F4F8), borderRadius: BorderRadius.circular(12)),
            alignment: Alignment.center,
            child: Text(item.icon, style: const TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1F1F1F))),
                const SizedBox(height: 4),
                // 🚀 기획서 반영: 대기시간 및 구역 표시
                Text(AppL10n.of(context)!.rec_zone_wait_eta(item.zone, item.waitMinutes), style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
              ],
            ),
          ),
          // 🚀 기획서 반영: 이스터에그 보유 여부 뱃지 표시
          if (item.hasEasterEgg)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(color: const Color(0xFFFFF7E6), borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  const Icon(Icons.stars_rounded, color: Color(0xFFFFB800), size: 14),
                  const SizedBox(width: 4),
                  Text(AppL10n.of(context)!.common_easter_egg, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFFFFB800))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
