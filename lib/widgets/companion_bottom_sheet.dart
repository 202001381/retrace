import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../l10n/generated/app_localizations.dart';

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

  // 키 — i18n 식별자 (영구 매칭용). 표시 라벨은 build 에서 AppL10n 으로.
  static const _companionKeys = ['family', 'couple', 'friend', 'solo'];
  static const _styleKeys = ['thrill', 'photo', 'relax', 'show'];
  static const _companionEmojis = {
    'family': '👨‍👩‍👧',
    'couple': '💑',
    'friend': '👫',
    'solo': '🙋',
  };
  static const _styleEmojis = {
    'thrill': '🎢',
    'photo': '📸',
    'relax': '🌿',
    'show': '🎭',
  };

  String _companionLabel(AppL10n l, String key) {
    switch (key) {
      case 'family': return l.companion_family;
      case 'couple': return l.companion_couple;
      case 'friend': return l.companion_friend;
      case 'solo': return l.companion_solo;
    }
    return key;
  }

  String _styleLabel(AppL10n l, String key) {
    switch (key) {
      case 'thrill': return l.style_thrill;
      case 'photo': return l.style_photo;
      case 'relax': return l.style_relax;
      case 'show': return l.style_show;
    }
    return key;
  }

  @override
  void initState() {
    super.initState();
    _companion = widget.initialCompanion;
    _style = widget.initialStyle;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bgCard,
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
              Expanded(
                child: Text(l.companion_change_title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 32, height: 32,
                  decoration: const BoxDecoration(color: AppColors.line, shape: BoxShape.circle),
                  child: const Icon(Icons.close, size: 16, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(l.companion_members, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textSecondary)),
          const SizedBox(height: 10),
          Row(
            children: _companionKeys
                .map((key) {
                  final label = _companionLabel(l, key);
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: key == _companionKeys.last ? 0 : 8),
                      child: _OptionTile(
                        label: label,
                        emoji: _companionEmojis[key]!,
                        selected: _companion == label,
                        activeColor: AppColors.ink900,
                        onTap: () => setState(() => _companion = label),
                      ),
                    ),
                  );
                })
                .toList(),
          ),
          const SizedBox(height: 20),
          Text(l.companion_preferred_style, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textSecondary)),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 3.2,
            children: _styleKeys
                .map((key) {
                  final label = _styleLabel(l, key);
                  return _OptionTile(
                    label: label,
                    emoji: _styleEmojis[key]!,
                    selected: _style == label,
                    activeColor: AppColors.yellow,
                    compact: false,
                    inline: true,
                    onTap: () => setState(() => _style = label),
                  );
                })
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
                backgroundColor: AppColors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(l.common_ok, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
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
    final borderColor = selected ? activeColor : AppColors.line;

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
