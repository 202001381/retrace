import 'package:flutter/material.dart';

/// 정적 앱 정보 — 버전·라이선스·문의처 placeholder.
class AppInfoScreen extends StatelessWidget {
  const AppInfoScreen({super.key});

  // TODO: pubspec 의 version 을 package_info_plus 로 자동 주입.
  static const String _version = '0.1.0 BETA';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        title: const Text('앱 정보',
            style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        foregroundColor: const Color(0xFF1F1F1F),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _InfoCard(
            label: '서비스',
            value: 'RE-TRACE',
            sub: '서울랜드 AI 다이나믹 프라이싱 & 동선 추천',
          ),
          const SizedBox(height: 12),
          const _InfoCard(label: '버전', value: _version),
          const SizedBox(height: 12),
          const _InfoCard(
            label: '개발',
            value: '한국외국어대학교 캡스톤 1팀',
          ),
          const SizedBox(height: 12),
          _LinkCard(
            label: '오픈소스 라이선스',
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('라이선스 페이지 (준비 중)')),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  const _InfoCard({required this.label, required this.value, this.sub});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF888888),
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              )),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1F1F1F),
              )),
          if (sub != null) ...[
            const SizedBox(height: 4),
            Text(sub!,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF888888),
                  fontWeight: FontWeight.w600,
                )),
          ],
        ],
      ),
    );
  }
}

class _LinkCard extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _LinkCard({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Text(label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1F1F1F),
                )),
            const Spacer(),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF888888)),
          ],
        ),
      ),
    );
  }
}
