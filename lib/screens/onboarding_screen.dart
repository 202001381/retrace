import 'package:flutter/material.dart';

import '../services/onboarding_service.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;
  const OnboardingScreen({super.key, required this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  CompanionType? _companion;
  ChildAge? _childAge;
  VisitPurpose? _purpose;

  bool get _canAdvance {
    switch (_page) {
      case 0:
        return _companion != null;
      case 1:
        return _childAge != null;
      case 2:
        return _purpose != null;
    }
    return false;
  }

  Future<void> _next() async {
    if (_page < 2) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
      setState(() => _page += 1);
      return;
    }
    await OnboardingService.saveAnswers(OnboardingAnswers(
      companion: _companion!,
      childAge: _childAge!,
      purpose: _purpose!,
    ));
    if (!mounted) return;
    widget.onDone();
  }

  void _back() {
    if (_page == 0) return;
    _controller.previousPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
    setState(() => _page -= 1);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: SafeArea(
        child: Column(
          children: [
            _ProgressBar(current: _page, total: 3),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  if (_page > 0)
                    IconButton(
                      onPressed: _back,
                      icon: const Icon(Icons.arrow_back),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.all(8),
                      ),
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: () async {
                      // 스킵: 기본값 저장 후 종료
                      await OnboardingService.saveAnswers(const OnboardingAnswers(
                        companion: CompanionType.family,
                        childAge: ChildAge.none,
                        purpose: VisitPurpose.both,
                      ));
                      if (!context.mounted) return;
                      widget.onDone();
                    },
                    child: const Text('건너뛰기',
                        style: TextStyle(color: Color(0xFF888888), fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _CompanionPage(selected: _companion, onSelect: (v) => setState(() => _companion = v)),
                  _ChildAgePage(selected: _childAge, onSelect: (v) => setState(() => _childAge = v)),
                  _PurposePage(selected: _purpose, onSelect: (v) => setState(() => _purpose = v)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _canAdvance ? _next : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE60012),
                    disabledBackgroundColor: const Color(0xFFE0E0E0),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    _page < 2 ? '다음' : '서울랜드 시작하기',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final int current;
  final int total;
  const _ProgressBar({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: List.generate(total, (i) {
          final active = i <= current;
          return Expanded(
            child: Container(
              height: 4,
              margin: EdgeInsets.only(right: i == total - 1 ? 0 : 6),
              decoration: BoxDecoration(
                color: active ? const Color(0xFFE60012) : const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _PageScaffold extends StatelessWidget {
  final String stepLabel;
  final String title;
  final String? subtitle;
  final Widget child;
  const _PageScaffold({
    required this.stepLabel,
    required this.title,
    this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(stepLabel,
              style: const TextStyle(color: Color(0xFFE60012), fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
          const SizedBox(height: 8),
          Text(title,
              style: const TextStyle(color: Color(0xFF1F1F1F), fontSize: 24, fontWeight: FontWeight.w900, height: 1.3)),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(subtitle!,
                style: const TextStyle(color: Color(0xFF888888), fontSize: 13)),
          ],
          const SizedBox(height: 24),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _SelectableTile<T> extends StatelessWidget {
  final String label;
  final String emoji;
  final bool selected;
  final VoidCallback onTap;
  const _SelectableTile({required this.label, required this.emoji, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE60012) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? const Color(0xFFE60012) : const Color(0xFFE0E0E0), width: 2),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 30)),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: selected ? Colors.white : const Color(0xFF1F1F1F),
                  )),
            ),
            if (selected) const Icon(Icons.check_circle, color: Colors.white, size: 22),
          ],
        ),
      ),
    );
  }
}

// ─── Page 1: 동행자 유형 ────────────────────────────────────
class _CompanionPage extends StatelessWidget {
  final CompanionType? selected;
  final ValueChanged<CompanionType> onSelect;
  const _CompanionPage({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return _PageScaffold(
      stepLabel: 'STEP 1 / 3',
      title: '누구와 함께\n오시나요?',
      subtitle: '동행자에 맞춰 동선을 추천해드려요',
      child: ListView.separated(
        itemCount: CompanionType.values.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final t = CompanionType.values[i];
          return _SelectableTile<CompanionType>(
            label: t.label,
            emoji: t.emoji,
            selected: selected == t,
            onTap: () => onSelect(t),
          );
        },
      ),
    );
  }
}

// ─── Page 2: 아이 연령 ──────────────────────────────────────
class _ChildAgePage extends StatelessWidget {
  final ChildAge? selected;
  final ValueChanged<ChildAge> onSelect;
  const _ChildAgePage({required this.selected, required this.onSelect});

  static const _emojis = {
    ChildAge.none: '🚫',
    ChildAge.under7: '👶',
    ChildAge.age7to13: '🧒',
  };

  @override
  Widget build(BuildContext context) {
    return _PageScaffold(
      stepLabel: 'STEP 2 / 3',
      title: '동행하는 아이\n나이가 있나요?',
      subtitle: '키 제한 어트랙션을 자동 필터링합니다',
      child: ListView.separated(
        itemCount: ChildAge.values.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final t = ChildAge.values[i];
          return _SelectableTile<ChildAge>(
            label: t.label,
            emoji: _emojis[t]!,
            selected: selected == t,
            onTap: () => onSelect(t),
          );
        },
      ),
    );
  }
}

// ─── Page 3: 방문 목적 ──────────────────────────────────────
class _PurposePage extends StatelessWidget {
  final VisitPurpose? selected;
  final ValueChanged<VisitPurpose> onSelect;
  const _PurposePage({required this.selected, required this.onSelect});

  static const _emojis = {
    VisitPurpose.thrill: '🎢',
    VisitPurpose.familyFriendly: '🎠',
    VisitPurpose.both: '✨',
  };

  @override
  Widget build(BuildContext context) {
    return _PageScaffold(
      stepLabel: 'STEP 3 / 3',
      title: '어떤 어트랙션을\n선호하세요?',
      subtitle: '추천 우선순위에 반영됩니다',
      child: ListView.separated(
        itemCount: VisitPurpose.values.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final t = VisitPurpose.values[i];
          return _SelectableTile<VisitPurpose>(
            label: t.label,
            emoji: _emojis[t]!,
            selected: selected == t,
            onTap: () => onSelect(t),
          );
        },
      ),
    );
  }
}
