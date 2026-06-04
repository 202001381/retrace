import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/attraction.dart';
import '../widgets/attraction_detail_sheet.dart';
import '../widgets/design/condition_pip.dart';
import '../widgets/design/stamp.dart';

/// v3 시안 10번 — "전체 51곳" 풀스크린 리스트.
/// 검색 + 카테고리 칩 + 카드 리스트. 카드 탭 → AttractionDetailSheet.
class AllAttractionsScreen extends StatefulWidget {
  const AllAttractionsScreen({super.key});

  @override
  State<AllAttractionsScreen> createState() => _AllAttractionsScreenState();
}

class _AllAttractionsScreenState extends State<AllAttractionsScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String? _category; // null = 전체

  static const _categories = <String>['어트랙션', '음식점', '카페', '포토스팟'];

  static String _categoryLabel(AppL10n l, String key) {
    switch (key) {
      case '어트랙션': return l.cat_attraction;
      case '음식점': return l.cat_restaurant;
      case '카페': return l.cat_cafe;
      case '포토스팟': return l.cat_photo_spot;
    }
    return key;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Attraction> get _visible {
    Iterable<Attraction> pool = kAttractions;
    if (_category != null) {
      pool = pool.where((a) => a.category == _category);
    }
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      pool = pool.where((a) =>
          a.name.toLowerCase().contains(q) ||
          a.zone.toLowerCase().contains(q));
    }
    return pool.toList();
  }

  void _openDetail(Attraction a) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AttractionDetailSheet(attraction: a),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _visible;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 헤더
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 22, 10),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.maybePop(context),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 18, color: AppColors.ink900),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Eyebrow('SEOULLAND · ALL'),
                        const SizedBox(height: 4),
                        Text(
                          '전체 ${kAttractions.length}곳',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: AppColors.ink900,
                            letterSpacing: -0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // 검색 pill
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.bgPage,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: AppColors.line),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded,
                        size: 16, color: AppColors.ink500),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (v) => setState(() => _query = v),
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.ink900),
                        decoration: InputDecoration(
                          isCollapsed: true,
                          border: InputBorder.none,
                          hintText: AppL10n.of(context).search_hint_all,
                          hintStyle: const TextStyle(
                              color: AppColors.ink400, fontSize: 13),
                        ),
                      ),
                    ),
                    if (_query.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                        child: const Icon(Icons.close_rounded,
                            size: 16, color: AppColors.ink500),
                      ),
                  ],
                ),
              ),
            ),
            // 카테고리 칩
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _categories.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, i) {
                  final l = AppL10n.of(context);
                  final isAll = i == 0;
                  final cat = isAll ? null : _categories[i - 1];
                  final label = isAll ? l.map_filter_all : _categoryLabel(l, cat!);
                  final active = _category == cat;
                  return GestureDetector(
                    onTap: () => setState(() => _category = cat),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: active ? AppColors.ink900 : Colors.white,
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                            color: active ? AppColors.ink900 : AppColors.line),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        label,
                        style: TextStyle(
                          color: active ? Colors.white : AppColors.ink700,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            // 결과 수
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Row(
                children: [
                  Text(
                    AppL10n.of(context).map_result_count(list.length),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // 카드 리스트
            Expanded(
              child: list.isEmpty
                  ? Center(
                      child: Text(
                        AppL10n.of(context).search_no_results,
                        style: const TextStyle(
                          color: AppColors.ink400,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final a = list[i];
                        return _AttractionListCard(
                          attraction: a,
                          onTap: () => _openDetail(a),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttractionListCard extends StatelessWidget {
  final Attraction attraction;
  final VoidCallback onTap;
  const _AttractionListCard(
      {required this.attraction, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final a = attraction;
    return Material(
      color: AppColors.bgCard,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            children: [
              Stamp(
                code: Stamp.codeFromName(a.name),
                emoji: a.icon,
                tone: Stamp.toneFromHints(
                  category: a.category,
                  thrillLevel: a.thrillLevel,
                  hasEasterEgg: a.hasEasterEgg,
                ),
                size: 44,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            a.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink900,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                        if (a.hasEasterEgg) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.yellowTint,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'EGG',
                              style: TextStyle(
                                color: Color(0xFF8A6300),
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      a.category == '어트랙션'
                          ? '${a.zone} · 대기 ${a.waitMinutes}분 · ★ ${a.rating}'
                          : '${a.category} · ${a.zone} · ★ ${a.rating}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.ink500,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppColors.ink300),
            ],
          ),
        ),
      ),
    );
  }
}
