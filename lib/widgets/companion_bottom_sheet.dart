import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

class CompanionBottomSheet extends StatefulWidget {
  final String initialCompanion;
  final String initialStyle;
  final void Function(String companion, String style) onConfirm;

  const CompanionBottomSheet({
    super.key,
    required this.initialCompanion,
    required this.initialStyle,
    required this.onConfirm,
  });

  @override
  State<CompanionBottomSheet> createState() => _CompanionBottomSheetState();
}

class _CompanionBottomSheetState extends State<CompanionBottomSheet> {
  late String _companion;
  late String _style;

  static const _companions = [
    ('가족', '👨‍👩‍👧'),
    ('연인', '💑'),
    ('친구', '👫'),
    ('혼자', '🙋'),
  ];
  static const _styles = [
    ('스릴·액티비티', '🎢'),
    ('사진·인생샷', '📸'),
    ('여유·힐링', '🌿'),
    ('공연·퍼레이드', '🎭'),
  ];

  @override
  void initState() {
    super.initState();
    _companion = widget.initialCompanion;
    _style = widget.initialStyle;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(context).viewInsets.bottom + 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 5,
              decoration: BoxDecoration(color: AppColors.textSecondary, borderRadius: BorderRadius.circular(99)),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Expanded(
                child: Text('마이 루나 조건 변경',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 32, height: 32,
                  decoration: const BoxDecoration(color: AppColors.bgSunken, shape: BoxShape.circle),
                  child: const Icon(Icons.close, size: 16, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text('구성원', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textSecondary)),
          const SizedBox(height: 10),
          Row(
            children: _companions
                .map((c) => Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: c == _companions.last ? 0 : 8),
                        child: _OptionTile(
                          label: c.$1,
                          emoji: c.$2,
                          selected: _companion == c.$1,
                          activeColor: AppColors.brandNavy,
                          onTap: () => setState(() => _companion = c.$1),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 20),
          const Text('선호 스타일', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textSecondary)),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 3.2,
            children: _styles
                .map((s) => _OptionTile(
                      label: s.$1,
                      emoji: s.$2,
                      selected: _style == s.$1,
                      activeColor: const Color(0xFFE6A817),
                      compact: false,
                      inline: true,
                      onTap: () => setState(() => _style = s.$1),
                    ))
                .toList(),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () {
                widget.onConfirm(_companion, _style);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandCoral,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('확인', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final String label;
  final String emoji;
  final bool selected;
  final Color activeColor;
  final bool compact;
  final bool inline;
  final VoidCallback onTap;

  const _OptionTile({
    required this.label,
    required this.emoji,
    required this.selected,
    required this.activeColor,
    this.compact = true,
    this.inline = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected ? activeColor : Colors.white;
    final textColor = selected ? Colors.white : AppColors.textPrimary;
    final borderColor = selected ? activeColor : AppColors.bgSunken;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 2),
        ),
        alignment: Alignment.center,
        child: inline
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(label,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: textColor),
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 18)),
                  const SizedBox(height: 2),
                  Text(label,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: textColor)),
                ],
              ),
      ),
    );
  }
}
