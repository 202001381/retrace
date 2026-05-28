import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../widgets/design/condition_pip.dart';

/// 마케팅 정보 수신 동의 풀스크린 모달 (정통법 §50 명시적 동의).
/// 호출 측은 [showMarketingConsentModal] 사용 → bool 반환 (true = 동의).
///
/// TODO: 법무 검토 필요 — 본문 텍스트, 수집 항목, 수신 시간대, 거부 흐름 모두
/// placeholder 상태. 베타 출시 전 법무 팀 검토 + 약관 페이지 정식 텍스트 교체.
class MarketingConsentModal extends StatelessWidget {
  const MarketingConsentModal({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 22, 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close_rounded,
                        size: 22, color: AppColors.ink900),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Eyebrow('LEGAL · MARKETING'),
                          SizedBox(height: 6),
                          Text(
                            '마케팅 정보\n수신 동의',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: AppColors.ink900,
                              letterSpacing: -0.8,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    _Section(
                      title: '수신 동의 시 받게 되는 정보',
                      lines: [
                        '· 비수기·날씨 기반 한산 알림',
                        '· 할인 쿠폰·이벤트 안내',
                        '· 신규 어트랙션·시즌 콘텐츠 소식',
                      ],
                    ),
                    _Section(
                      title: '수신 시간대',
                      lines: ['오전 8시 ~ 오후 9시'],
                    ),
                    _Section(
                      title: '수집·이용 항목',
                      lines: [
                        '· 닉네임',
                        '· 카카오톡 ID (선택)',
                        '· 휴대폰 번호 (선택)',
                        '· 방문 이력',
                      ],
                    ),
                    _Section(
                      title: '수신 거부 방법',
                      lines: [
                        '언제든 마이페이지 > 알림 설정에서 OFF 가능합니다.',
                        '수신 거부 시 한산 알림 등 일부 기능이 제한됩니다.',
                      ],
                    ),
                    SizedBox(height: 12),
                    Text(
                      '법적 근거: 정보통신망 이용촉진 및 정보보호 등에 관한 법률 제50조',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: AppColors.line),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: AppColors.line),
                        foregroundColor: AppColors.textSecondary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(99)),
                      ),
                      child: const Text('동의하지 않음',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: AppColors.red,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(99)),
                      ),
                      child: const Text('동의하기',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w900)),
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

class _Section extends StatelessWidget {
  final String title;
  final List<String> lines;
  const _Section({required this.title, required this.lines});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              )),
          const SizedBox(height: 8),
          ...lines.map((l) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(l,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    )),
              )),
        ],
      ),
    );
  }
}

/// 마케팅 동의 모달을 풀스크린 라우트로 띄우고 결과(true=동의)를 반환.
Future<bool> showMarketingConsentModal(BuildContext context) async {
  final result = await Navigator.of(context).push<bool>(
    MaterialPageRoute<bool>(
      fullscreenDialog: true,
      builder: (_) => const MarketingConsentModal(),
    ),
  );
  return result ?? false;
}
