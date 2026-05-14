import 'package:flutter/material.dart';

import '../models/attraction.dart';
import '../services/onboarding_service.dart';

class RecommendScreen extends StatefulWidget {
  const RecommendScreen({super.key});
  @override
  State<RecommendScreen> createState() => _RecommendScreenState();
}

class _RecommendScreenState extends State<RecommendScreen> {
  OnboardingAnswers? _answers;
  List<Attraction> _top3 = const [];
  bool _loading = true;

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

  /// 온보딩 결과 기반 스코어링.
  ///
  ///  유아 동반: 키 제한 없는 것만 → 실내 우선 → 거리 짧은 순
  ///  초등 동반: 110cm 이하 허용 → 실내외 혼합
  ///  성인/커플/친구: 스릴 우선 → 혼잡도 낮은 순
  List<Attraction> _computeTop3(OnboardingAnswers? ans) {
    final answers = ans ??
        const OnboardingAnswers(
          companion: CompanionType.family,
          childAge: ChildAge.none,
          purpose: VisitPurpose.both,
        );

    // 하드 필터 (키 제한)
    Iterable<Attraction> pool = kAttractions;
    switch (answers.childAge) {
      case ChildAge.under7:
        pool = pool.where((a) => a.heightLimit == 0);
        break;
      case ChildAge.age7to13:
        pool = pool.where((a) => a.heightLimit == 0 || a.heightLimit <= 110);
        break;
      case ChildAge.none:
        break;
    }

    // 스코어링
    const center = (lat: 37.4279, lng: 127.0247); // 서울랜드 중심 — 거리 기준점
    double distScore(Attraction a) {
      final dLat = a.lat - center.lat;
      final dLng = a.lng - center.lng;
      final d2 = (dLat * dLat + dLng * dLng); // 작을수록 가까움
      return 1.0 / (1.0 + d2 * 1e6);          // 0~1 정규화
    }

    final scored = pool.map((a) {
      double score = 0;

      // 혼잡도 낮을수록 +
      score += (60 - a.estimatedWaitMin).clamp(-20, 60).toDouble();

      switch (answers.childAge) {
        case ChildAge.under7:
          if (a.indoor) score += 30;
          score += distScore(a) * 20;
          break;
        case ChildAge.age7to13:
          score += distScore(a) * 10;
          break;
        case ChildAge.none:
          // 성인/청소년만 — 스릴 가중치
          if (a.thrillLevel >= 4) score += 20;
          // 오후 시간대 혼잡 회피
          final hour = DateTime.now().hour;
          if (hour >= 13 && a.estimatedWaitMin >= 15) score -= 10;
          break;
      }

      // 방문 목적 보너스
      switch (answers.purpose) {
        case VisitPurpose.thrill:
          score += a.thrillLevel * 4;
          break;
        case VisitPurpose.familyFriendly:
          score += (6 - a.thrillLevel) * 4;
          if (a.heightLimit == 0) score += 8;
          break;
        case VisitPurpose.both:
          break;
      }

      return (attraction: a, score: score);
    }).toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    return scored.take(3).map((e) => e.attraction).toList();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF7F7F7),
      child: SafeArea(
        bottom: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFE60012)))
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                children: [
                  _Header(answers: _answers, onRefresh: _loadAndCompute),
                  const SizedBox(height: 16),
                  _SummaryChips(answers: _answers),
                  const SizedBox(height: 20),
                  if (_top3.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Text('조건에 맞는 어트랙션이 없어요',
                            style: TextStyle(color: Color(0xFF888888), fontWeight: FontWeight.w700)),
                      ),
                    )
                  else
                    ..._top3.asMap().entries.map((e) => Padding(
                          padding: EdgeInsets.only(bottom: e.key == _top3.length - 1 ? 0 : 12),
                          child: _AttractionCard(index: e.key + 1, item: e.value),
                        )),
                ],
              ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final OnboardingAnswers? answers;
  final VoidCallback onRefresh;
  const _Header({required this.answers, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome_rounded, color: Color(0xFFE60012), size: 22),
          const SizedBox(width: 6),
          const Text('맞춤 추천',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFFE60012))),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('새로고침', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1E3158),
              side: const BorderSide(color: Color(0xFFDDDDDD)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryChips extends StatelessWidget {
  final OnboardingAnswers? answers;
  const _SummaryChips({required this.answers});

  @override
  Widget build(BuildContext context) {
    if (answers == null) {
      return const Text('온보딩 응답 없음 — 기본값(가족·둘 다)으로 추천',
          style: TextStyle(color: Color(0xFF888888), fontSize: 12));
    }
    final a = answers!;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _Chip(text: '${a.companion.emoji} ${a.companion.label}'),
        _Chip(text: '👶 ${a.childAge.label}'),
        _Chip(text: '🎯 ${a.purpose.label}'),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  const _Chip({required this.text});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Text(text,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1F1F1F))),
    );
  }
}

class _AttractionCard extends StatelessWidget {
  final int index;
  final Attraction item;
  const _AttractionCard({required this.index, required this.item});

  Color get _crowdColor {
    switch (item.crowdLabel) {
      case '여유':
        return const Color(0xFF4CAF50);
      case '보통':
        return const Color(0xFFFFC107);
      default:
        return const Color(0xFFE60012);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32, height: 32,
            decoration: const BoxDecoration(color: Color(0xFFE60012), shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text('$index',
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 12),
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFE60012).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Text(item.emoji, style: const TextStyle(fontSize: 28)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(item.name,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF1F1F1F))),
                const SizedBox(height: 4),
                Text('${item.zone} · ${item.indoor ? '실내' : '실외'} · 스릴 ${item.thrillLevel}/5',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF888888))),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _crowdColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(width: 6, height: 6, decoration: BoxDecoration(color: _crowdColor, shape: BoxShape.circle)),
                          const SizedBox(width: 4),
                          Text(item.crowdLabel,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _crowdColor)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text('⏱ 예상 ${item.estimatedWaitMin}분',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF555555), fontWeight: FontWeight.w700)),
                    if (item.heightLimit > 0) ...[
                      const SizedBox(width: 6),
                      Text('📏 ${item.heightLimit}cm+',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF555555), fontWeight: FontWeight.w700)),
                    ],
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
