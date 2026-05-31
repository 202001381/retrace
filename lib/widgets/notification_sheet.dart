import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import 'design/condition_pip.dart';

/// 알림 시트 — 홈 헤더 벨 아이콘에서 진입.
/// mock 데이터로 푸시 알림 히스토리 표시. 백엔드 연동 전 placeholder.
class NotificationSheet extends StatelessWidget {
  const NotificationSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const NotificationSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.78;
    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // 핸들
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: AppColors.ink300,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: 16),
          // 헤더
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 14, 4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Eyebrow('INBOX · 알림'),
                      SizedBox(height: 4),
                      Text(
                        '오늘의 알림',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: AppColors.ink900,
                          letterSpacing: -0.6,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded,
                      size: 22, color: AppColors.ink700),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // 알림 리스트
          Expanded(
            child: ListView.separated(
              padding:
                  const EdgeInsets.fromLTRB(0, 4, 0, 24),
              itemCount: _kMockNotifications.length,
              separatorBuilder: (_, __) => const Divider(
                height: 1,
                thickness: 1,
                color: AppColors.lineDim,
                indent: 22,
                endIndent: 22,
              ),
              itemBuilder: (_, i) {
                final n = _kMockNotifications[i];
                return _NotificationRow(item: n);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  final _Notif item;
  const _NotificationRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(
            content: Text('${item.title} — 상세 페이지(준비 중)'),
            duration: const Duration(seconds: 2),
          ));
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 카테고리 아이콘 (컬러 박스)
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: item.category.tintBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                item.category.icon,
                size: 18,
                color: item.category.tintFg,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: item.unread
                                ? FontWeight.w900
                                : FontWeight.w700,
                            color: AppColors.ink900,
                            letterSpacing: -0.2,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (item.unread) ...[
                        const SizedBox(width: 6),
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: AppColors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.body,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.ink500,
                      fontWeight: FontWeight.w500,
                      height: 1.5,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.timeLabel,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.ink400,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Mock 데이터 모델 ───────────────────────────────────
enum _NotifCategory {
  pricing,
  route,
  egg,
  event,
  system,
}

extension on _NotifCategory {
  IconData get icon {
    switch (this) {
      case _NotifCategory.pricing:
        return Icons.local_offer_rounded;
      case _NotifCategory.route:
        return Icons.nightlight_round;
      case _NotifCategory.egg:
        return Icons.egg_outlined;
      case _NotifCategory.event:
        return Icons.celebration_rounded;
      case _NotifCategory.system:
        return Icons.info_outline_rounded;
    }
  }

  Color get tintBg {
    switch (this) {
      case _NotifCategory.pricing:
        return AppColors.redTint;
      case _NotifCategory.route:
        return AppColors.blueTint;
      case _NotifCategory.egg:
        return AppColors.yellowTint;
      case _NotifCategory.event:
        return AppColors.grapeTint;
      case _NotifCategory.system:
        return AppColors.bgPage;
    }
  }

  Color get tintFg {
    switch (this) {
      case _NotifCategory.pricing:
        return AppColors.redDeep;
      case _NotifCategory.route:
        return AppColors.blueDeep;
      case _NotifCategory.egg:
        return const Color(0xFF8A6300);
      case _NotifCategory.event:
        return const Color(0xFF5938C9);
      case _NotifCategory.system:
        return AppColors.ink700;
    }
  }
}

class _Notif {
  final _NotifCategory category;
  final String title;
  final String body;
  final String timeLabel;
  final bool unread;
  const _Notif({
    required this.category,
    required this.title,
    required this.body,
    required this.timeLabel,
    this.unread = false,
  });
}

const List<_Notif> _kMockNotifications = [
  _Notif(
    category: _NotifCategory.pricing,
    title: '오늘 −15% 루나 프라이싱',
    body: '흐려서 한산할 거예요. 09:53 까지 ₩29,750 으로 받을 수 있어요.',
    timeLabel: '방금',
    unread: true,
  ),
  _Notif(
    category: _NotifCategory.route,
    title: '마이 루나 동선이 업데이트됐어요',
    body: '대기시간 변화에 따라 라바트위스터를 두 번째 stop 으로 재배치했어요.',
    timeLabel: '12분 전',
    unread: true,
  ),
  _Notif(
    category: _NotifCategory.egg,
    title: '🥚 새 이스터에그 힌트',
    body: '미래의 골동품가게 근처에서 누군가가 도장을 찾았어요. 가까이 가보세요.',
    timeLabel: '1시간 전',
  ),
  _Notif(
    category: _NotifCategory.event,
    title: '오후 2시 퍼레이드 곧 시작',
    body: '중앙 광장에서 만나요. 좋은 자리는 30분 전부터 채워져요.',
    timeLabel: '오늘 13:30',
  ),
  _Notif(
    category: _NotifCategory.system,
    title: '오늘은 평일이라 비교적 한산',
    body: '오전 11시 이후 입장을 추천드려요. 주말보다 평균 대기 8분 짧음.',
    timeLabel: '오늘 08:00',
  ),
];
