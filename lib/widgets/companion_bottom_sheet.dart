import 'package:flutter/material.dart';

class CompanionBottomSheet extends StatefulWidget {
  final String initialCompanion;
  final List<String> initialPreferences;
  final Function(String companion, List<String> prefs) onConfirm;

  const CompanionBottomSheet({
    super.key,
    required this.initialCompanion,
    required this.initialPreferences,
    required this.onConfirm,
  });

  @override
  State<CompanionBottomSheet> createState() => _CompanionBottomSheetState();
}

class _CompanionBottomSheetState extends State<CompanionBottomSheet> {
  late String _selectedCompanion;
  late List<String> _selectedPrefs;

  final List<Map<String, String>> _companions = [
    {'label': '가족', 'icon': '👨‍👩‍👧'},
    {'label': '연인', 'icon': '💑'},
    {'label': '친구', 'icon': '👫'},
    {'label': '혼자', 'icon': '🙋'},
  ];

  final List<Map<String, String>> _preferences = [
    {'label': '스릴·액티비티', 'icon': '🎢'},
    {'label': '사진·인생샷', 'icon': '📸'},
    {'label': '여유·힐링', 'icon': '🌿'},
    {'label': '공연·퍼레이드', 'icon': '🎭'},
  ];

  @override
  void initState() {
    super.initState();
    _selectedCompanion = widget.initialCompanion;
    _selectedPrefs = List.from(widget.initialPreferences);
  }

  void _togglePref(String pref) {
    setState(() {
      if (_selectedPrefs.contains(pref)) {
        if (_selectedPrefs.length > 1) _selectedPrefs.remove(pref);
      } else {
        _selectedPrefs.add(pref);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 드래그 핸들
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 제목
          const Text(
            '누구와 함께 오셨나요?',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1F1F1F),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '맞춤형 동선 추천을 위해 정보를 선택해주세요.',
            style: TextStyle(fontSize: 13, color: Color(0xFF888888)),
          ),
          const SizedBox(height: 24),

          // 구성원 섹션
          const Row(
            children: [
              Icon(Icons.people_outline_rounded, size: 16, color: Color(0xFF555555)),
              SizedBox(width: 6),
              Text(
                '구성원',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF333333)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _companions.map((c) {
              final isSelected = _selectedCompanion == c['label'];
              return GestureDetector(
                onTap: () => setState(() => _selectedCompanion = c['label']!),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFE60012) : Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: isSelected ? const Color(0xFFE60012) : const Color(0xFFDDDDDD),
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: isSelected ? [
                      BoxShadow(
                        color: const Color(0xFFE60012).withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ] : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(c['icon']!, style: const TextStyle(fontSize: 15)),
                      const SizedBox(width: 6),
                      Text(
                        c['label']!,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : const Color(0xFF444444),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // 방문 목적 섹션
          const Row(
            children: [
              Text('✦', style: TextStyle(color: Color(0xFFE60012), fontSize: 14)),
              SizedBox(width: 6),
              Text(
                '방문 목적 및 선호도',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF333333)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _preferences.map((p) {
              final isSelected = _selectedPrefs.contains(p['label']);
              return GestureDetector(
                onTap: () => _togglePref(p['label']!),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF1E3158) : Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF1E3158) : const Color(0xFFDDDDDD),
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: isSelected ? [
                      BoxShadow(
                        color: const Color(0xFF1E3158).withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ] : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(p['icon']!, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Text(
                        p['label']!,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : const Color(0xFF444444),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 28),

          // 확인 버튼
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                widget.onConfirm(_selectedCompanion, _selectedPrefs);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE60012),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Text(
                '맞춤 추천 받기 🚀',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
