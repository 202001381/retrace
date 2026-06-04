import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/spot_model.dart';

class SpotDetailSheet extends StatelessWidget {
  final Spot spot;
  final VoidCallback? onNavigate;
  final bool isNavigating;
  final int? walkMinutes;

  const SpotDetailSheet({
    super.key,
    required this.spot,
    this.onNavigate,
    this.isNavigating = false,
    this.walkMinutes,
  });

  Color get _catColor {
    switch (spot.category) {
      case SpotCategory.attraction: return const Color(0xFFE60012);
      case SpotCategory.food:       return const Color(0xFFFF6D00);
      case SpotCategory.photo:      return const Color(0xFF8E24AA);
    }
  }

  String _catLabel(BuildContext context) {
    final l = AppL10n.of(context);
    switch (spot.category) {
      case SpotCategory.attraction: return l.cat_attraction;
      case SpotCategory.food:       return l.cat_restaurant;
      case SpotCategory.photo:      return l.cat_photo_spot;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 핸들
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 4),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE0E0E0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 헤더
                Row(
                  children: [
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        color: _catColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _catColor.withValues(alpha: 0.3)),
                      ),
                      child: Center(
                        child: Text(spot.icon, style: const TextStyle(fontSize: 28)),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: _catColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _catLabel(context),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: _catColor,
                                  ),
                                ),
                              ),
                              if (spot.hasEasterEgg) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF8E1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFFFB300)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text('🥚', style: TextStyle(fontSize: 10)),
                                      const SizedBox(width: 3),
                                      Text(AppL10n.of(context).common_easter_egg,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFFFF8F00),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            spot.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF1F1F1F),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 닫기 버튼
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF888888)),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // 정보 행
                Row(
                  children: [
                    _infoChip(Icons.location_on_rounded, spot.zone, const Color(0xFF1E3158)),
                    const SizedBox(width: 8),
                    _infoChip(Icons.star_rounded, spot.rating.toStringAsFixed(1), const Color(0xFFFFB300)),
                    const SizedBox(width: 8),
                    _infoChip(Icons.reviews_rounded, AppL10n.of(context).spot_reviews_count(spot.reviewCount), const Color(0xFF4CAF50)),
                    const SizedBox(width: 8),
                    _infoChip(Icons.schedule_rounded, AppL10n.of(context).spot_duration_min(spot.visitDurationMin), const Color(0xFF9E9E9E)),
                  ],
                ),

                const SizedBox(height: 14),

                // 설명
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F8F8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    spot.description,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF444444),
                      height: 1.55,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // 카테고리별 추가 정보
                if (spot.waitTime != null)
                  _extraInfoCard(
                    icon: '⏱️',
                    label: AppL10n.of(context).spot_wait_now_label,
                    value: spot.waitTime!,
                    color: spot.waitTime == '없음'
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFFFFB300),
                  ),

                if (spot.priceRange != null)
                  _extraInfoCard(
                    icon: '💰',
                    label: AppL10n.of(context).spot_price_range_label,
                    value: spot.priceRange!,
                    color: const Color(0xFFFF6D00),
                  ),

                if (spot.photoTip != null)
                  _photoTipCard(context, spot.photoTip!),

                const SizedBox(height: 16),

                // 길 찾기 버튼
                if (walkMinutes != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _catColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.directions_walk_rounded, size: 16, color: _catColor),
                        const SizedBox(width: 6),
                        Text(AppL10n.of(context).attr_walk_eta(walkMinutes!),
                            style: TextStyle(color: _catColor, fontSize: 13, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: onNavigate,
                    icon: Icon(
                      isNavigating ? Icons.hourglass_top_rounded : Icons.directions_walk_rounded,
                      size: 20,
                    ),
                    label: Text(
                      isNavigating
                          ? AppL10n.of(context).common_traveling
                          : AppL10n.of(context).attr_go_here,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _catColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String text, Color color) {
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                text,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _extraInfoCard({
    required String icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: Color(0xFF666666)),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _photoTipCard(BuildContext context, String tip) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF8E24AA).withValues(alpha: 0.06),
            const Color(0xFF8E24AA).withValues(alpha: 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF8E24AA).withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('📸', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppL10n.of(context).spot_photo_tip_title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF8E24AA),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tip,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF444444),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
