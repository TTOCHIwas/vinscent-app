import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

enum StoryCardAction { download, delete, report }

Future<StoryCardAction?> showStoryCardActionSheet({
  required BuildContext context,
  required String cardId,
  required bool showDelete,
  required bool showReport,
}) {
  return showModalBottomSheet<StoryCardAction>(
    context: context,
    useRootNavigator: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    clipBehavior: Clip.antiAlias,
    builder: (context) => _StoryCardActionSheet(
      cardId: cardId,
      showDelete: showDelete,
      showReport: showReport,
    ),
  );
}

class _StoryCardActionSheet extends StatelessWidget {
  const _StoryCardActionSheet({
    required this.cardId,
    required this.showDelete,
    required this.showReport,
  });

  final String cardId;
  final bool showDelete;
  final bool showReport;

  @override
  Widget build(BuildContext context) {
    final actions = <_StoryCardActionItem>[
      const _StoryCardActionItem(
        action: StoryCardAction.download,
        icon: LucideIcons.download,
        label: '다운로드',
      ),
      if (showDelete)
        const _StoryCardActionItem(
          action: StoryCardAction.delete,
          icon: LucideIcons.trash2,
          label: '삭제',
          isDestructive: true,
        ),
      if (showReport)
        const _StoryCardActionItem(
          action: StoryCardAction.report,
          icon: LucideIcons.flag,
          label: '신고',
        ),
    ];

    return SafeArea(
      top: false,
      child: Padding(
        key: ValueKey('story-card-action-sheet-$cardId'),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _SheetHandle(),
            const SizedBox(height: 12),
            for (var index = 0; index < actions.length; index++) ...[
              _ActionRow(cardId: cardId, item: actions[index]),
              if (index != actions.length - 1) const SizedBox(height: 4),
            ],
          ],
        ),
      ),
    );
  }
}

class _StoryCardActionItem {
  const _StoryCardActionItem({
    required this.action,
    required this.icon,
    required this.label,
    this.isDestructive = false,
  });

  final StoryCardAction action;
  final IconData icon;
  final String label;
  final bool isDestructive;
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.cardId, required this.item});

  final String cardId;
  final _StoryCardActionItem item;

  @override
  Widget build(BuildContext context) {
    final errorColor = Theme.of(context).colorScheme.error;
    final iconColor = item.isDestructive ? errorColor : AppColors.textMuted;
    final labelColor = item.isDestructive ? errorColor : AppColors.textPrimary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('story-card-action-${item.action.name}-$cardId'),
        onTap: () => Navigator.of(context).pop(item.action),
        splashColor: AppColors.settingsPressed,
        highlightColor: AppColors.settingsPressed,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(item.icon, size: 22, color: iconColor),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    item.label,
                    style: AppTextStyles.homeBody.copyWith(color: labelColor),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.settingsDivider,
        borderRadius: BorderRadius.circular(2),
      ),
      child: const SizedBox(width: 36, height: 4),
    );
  }
}
