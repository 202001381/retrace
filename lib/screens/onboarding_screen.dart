import 'package:flutter/material.dart';

import '../services/onboarding_service.dart';

const _kAccent = Color(0xFFE60012);
const _kSelectedBg = Color(0xFFFFF0F0);
const _kBorderIdle = Color(0xFFE0E0E0);
const _kText = Color(0xFF1F1F1F);
const _kMuted = Color(0xFF888888);
const int _kTotalPages = 5;

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;
  const OnboardingScreen({super.key, required this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  int _headcount = 2;
  final Set<String> _ageGroups = {};
  String? _gender;
  String? _favoriteType;
  String? _purpose;

  bool get _canAdvance {
    switch (_page) {
      case 0:
        return _headcount >= 1 && _headcount <= 20;
      case 1:
        return _ageGroups.isNotEmpty;
      case 2:
        return _gender != null;
      case 3:
        return _favoriteType != null;
      case 4:
        return _purpose != null;
    }
    return false;
  }

  Future<void> _next() async {
    if (_page < _kTotalPages - 1) {
      await _controller.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    await OnboardingService.save(SurveyAnswers(
      headcount: _headcount,
      ageGroups: _ageGroups.toList(),
      gender: _gender!,
      favoriteType: _favoriteType!,
      purpose: _purpose!,
    ));
    if (!mounted) return;
    widget.onDone();
  }

  Future<void> _back() async {
    if (_page == 0) return;
    await _controller.previousPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              page: _page,
              onBack: _page == 0 ? null : _back,
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _HeadcountPage(
                    value: _headcount,
                    onChanged: (v) => setState(() => _headcount = v),
                  ),
                  _AgeGroupsPage(
                    selected: _ageGroups,
                    onToggle: (label) => setState(() {
                      if (_ageGroups.contains(label)) {
                        _ageGroups.remove(label);
                      } else {
                        _ageGroups.add(label);
                      }
                    }),
                  ),
                  _SingleChoicePage(
                    stepLabel: 'STEP 3 / $_kTotalPages',
                    title: '성별을\n알려주세요',
                    options: const [
                      _Option(label: Gender.male, emoji: '👨'),
                      _Option(label: Gender.female, emoji: '👩'),
                      _Option(label: Gender.undisclosed, emoji: '🙅'),
                    ],
                    selected: _gender,
                    onSelect: (v) => setState(() => _gender = v),
                  ),
                  _SingleChoicePage(
                    stepLabel: 'STEP 4 / $_kTotalPages',
                    title: '어떤 어트랙션을\n선호하세요?',
                    options: const [
                      _Option(label: FavoriteType.thrill, emoji: '🎢'),
                      _Option(label: FavoriteType.family, emoji: '🎠'),
                      _Option(label: FavoriteType.both, emoji: '✨'),
                    ],
                    selected: _favoriteType,
                    onSelect: (v) => setState(() => _favoriteType = v),
                  ),
                  _SingleChoicePage(
                    stepLabel: 'STEP 5 / $_kTotalPages',
                    title: '오늘 방문 목적이\n무엇인가요?',
                    options: const [
                      _Option(label: VisitPurpose.rides, emoji: '🎡'),
                      _Option(label: VisitPurpose.picnic, emoji: '🌿'),
                      _Option(label: VisitPurpose.kidsOuting, emoji: '👶'),
                      _Option(label: VisitPurpose.date, emoji: '💑'),
                    ],
                    selected: _purpose,
                    onSelect: (v) => setState(() => _purpose = v),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _canAdvance ? _next : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kAccent,
                    disabledBackgroundColor: const Color(0xFFE0E0E0),
                    foregroundColor: Colors.white,
                    disabledForegroundColor: const Color(0xFF9E9E9E),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    _page < _kTotalPages - 1 ? '다음' : '시작하기',
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

// ─── 상단 진행 바 + 뒤로가기 ───────────────────────────────
class _TopBar extends StatelessWidget {
  final int page;
  final VoidCallback? onBack;
  const _TopBar({required this.page, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: Icon(Icons.arrow_back, color: onBack == null ? const Color(0xFFD0D0D0) : _kText),
          ),
          Expanded(
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(_kTotalPages, (i) {
                  final filled = i <= page;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Container(
                      width: 10, height: 10,
                      decoration: BoxDecoration(
                        color: filled ? _kAccent : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(color: filled ? _kAccent : const Color(0xFFD0D0D0), width: 1.5),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}

// ─── 공통 페이지 골격 ──────────────────────────────────────
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
              style: const TextStyle(color: _kAccent, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
          const SizedBox(height: 8),
          Text(title,
              style: const TextStyle(color: _kText, fontSize: 24, fontWeight: FontWeight.w900, height: 1.3)),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(subtitle!, style: const TextStyle(color: _kMuted, fontSize: 13)),
          ],
          const SizedBox(height: 24),
          Expanded(child: child),
        ],
      ),
    );
  }
}

// ─── 문항 1: 인원수 카운터 ─────────────────────────────────
class _HeadcountPage extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const _HeadcountPage({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return _PageScaffold(
      stepLabel: 'STEP 1 / $_kTotalPages',
      title: '오늘 함께 가는\n인원은 몇 명인가요?',
      subtitle: '1명 ~ 20명까지 선택할 수 있어요',
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _CounterButton(
              icon: Icons.remove,
              enabled: value > 1,
              onTap: () => onChanged(value - 1),
            ),
            const SizedBox(width: 28),
            SizedBox(
              width: 120,
              child: Center(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '$value',
                        style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: _kText, height: 1),
                      ),
                      const TextSpan(
                        text: '  명',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _kMuted),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 28),
            _CounterButton(
              icon: Icons.add,
              enabled: value < 20,
              onTap: () => onChanged(value + 1),
            ),
          ],
        ),
      ),
    );
  }
}

class _CounterButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _CounterButton({required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: enabled ? onTap : null,
      radius: 32,
      child: Container(
        width: 56, height: 56,
        decoration: BoxDecoration(
          color: enabled ? _kAccent : const Color(0xFFEEEEEE),
          shape: BoxShape.circle,
          boxShadow: enabled
              ? [BoxShadow(color: _kAccent.withValues(alpha: 0.25), blurRadius: 12, offset: const Offset(0, 4))]
              : const [],
        ),
        child: Icon(icon, color: enabled ? Colors.white : const Color(0xFFAAAAAA), size: 24),
      ),
    );
  }
}

// ─── 문항 2: 연령대 복수 선택 ──────────────────────────────
class _AgeGroupsPage extends StatelessWidget {
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  const _AgeGroupsPage({required this.selected, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return _PageScaffold(
      stepLabel: 'STEP 2 / $_kTotalPages',
      title: '함께 가는 분들의\n연령대를 골라주세요',
      subtitle: '복수 선택 가능 · 최소 1개',
      child: ListView.separated(
        itemCount: AgeGroups.all.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final label = AgeGroups.all[i];
          final isSelected = selected.contains(label);
          return _SelectTile(
            label: label,
            selected: isSelected,
            leading: _CheckboxBox(checked: isSelected),
            onTap: () => onToggle(label),
          );
        },
      ),
    );
  }
}

class _CheckboxBox extends StatelessWidget {
  final bool checked;
  const _CheckboxBox({required this.checked});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22, height: 22,
      decoration: BoxDecoration(
        color: checked ? _kAccent : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: checked ? _kAccent : const Color(0xFFCCCCCC), width: 2),
      ),
      child: checked
          ? const Icon(Icons.check, color: Colors.white, size: 14)
          : null,
    );
  }
}

// ─── 문항 3~5: 단일 선택 (성별/선호/목적) ─────────────────
class _Option {
  final String label;
  final String emoji;
  const _Option({required this.label, required this.emoji});
}

class _SingleChoicePage extends StatelessWidget {
  final String stepLabel;
  final String title;
  final List<_Option> options;
  final String? selected;
  final ValueChanged<String> onSelect;

  const _SingleChoicePage({
    required this.stepLabel,
    required this.title,
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return _PageScaffold(
      stepLabel: stepLabel,
      title: title,
      child: ListView.separated(
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final o = options[i];
          final isSelected = selected == o.label;
          return _SelectTile(
            label: o.label,
            selected: isSelected,
            leading: Text(o.emoji, style: const TextStyle(fontSize: 30)),
            onTap: () => onSelect(o.label),
          );
        },
      ),
    );
  }
}

// ─── 공용 선택 카드 ────────────────────────────────────────
class _SelectTile extends StatelessWidget {
  final String label;
  final bool selected;
  final Widget leading;
  final VoidCallback onTap;
  const _SelectTile({
    required this.label,
    required this.selected,
    required this.leading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: selected ? _kSelectedBg : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? _kAccent : _kBorderIdle, width: 2),
        ),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: selected ? _kAccent : _kText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
