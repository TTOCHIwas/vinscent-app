import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

enum RecordingSlotAction { artwork, homePlacement, replace, delete }

enum RecordingSlotArtworkAction { add, edit, view }

Future<RecordingSlotAction?> showRecordingSlotActionSheet({
  required BuildContext context,
  required String slotId,
  required RecordingSlotArtworkAction? artworkAction,
  required bool showHomePlacement,
  required bool showReplace,
  required bool showDelete,
}) {
  return showModalBottomSheet<RecordingSlotAction>(
    context: context,
    useRootNavigator: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    clipBehavior: Clip.antiAlias,
    builder: (context) => RecordingSlotActionSheet(
      slotId: slotId,
      artworkAction: artworkAction,
      showHomePlacement: showHomePlacement,
      showReplace: showReplace,
      showDelete: showDelete,
    ),
  );
}

class RecordingSlotActionSheet extends StatelessWidget {
  const RecordingSlotActionSheet({
    super.key,
    required this.slotId,
    required this.artworkAction,
    required this.showHomePlacement,
    required this.showReplace,
    required this.showDelete,
  });

  final String slotId;
  final RecordingSlotArtworkAction? artworkAction;
  final bool showHomePlacement;
  final bool showReplace;
  final bool showDelete;

  @override
  Widget build(BuildContext context) {
    final items = <_RecordingSlotActionItem>[
      if (artworkAction case final action?)
        _RecordingSlotActionItem(
          action: RecordingSlotAction.artwork,
          icon: action.icon,
          label: action.label,
        ),
      if (showHomePlacement)
        const _RecordingSlotActionItem(
          action: RecordingSlotAction.homePlacement,
          icon: LucideIcons.house,
          label: '홈에 배치',
        ),
      if (showReplace)
        const _RecordingSlotActionItem(
          action: RecordingSlotAction.replace,
          icon: LucideIcons.refreshCw,
          label: '현재 녹음으로 교체',
        ),
      if (showDelete)
        const _RecordingSlotActionItem(
          action: RecordingSlotAction.delete,
          icon: LucideIcons.trash2,
          label: '삭제',
          isDestructive: true,
        ),
    ];

    return SafeArea(
      top: false,
      child: Padding(
        key: ValueKey('recording-library-slot-action-sheet-$slotId'),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _SheetHandle(),
            const SizedBox(height: 12),
            for (var index = 0; index < items.length; index++) ...[
              _ActionRow(slotId: slotId, item: items[index]),
              if (index != items.length - 1) const SizedBox(height: 4),
            ],
          ],
        ),
      ),
    );
  }
}

extension on RecordingSlotArtworkAction {
  String get label => switch (this) {
    RecordingSlotArtworkAction.add => '그림 추가',
    RecordingSlotArtworkAction.edit => '그림 수정',
    RecordingSlotArtworkAction.view => '그림 보기',
  };

  IconData get icon => switch (this) {
    RecordingSlotArtworkAction.add => LucideIcons.paintbrush,
    RecordingSlotArtworkAction.edit => LucideIcons.pencil,
    RecordingSlotArtworkAction.view => LucideIcons.eye,
  };
}

class _RecordingSlotActionItem {
  const _RecordingSlotActionItem({
    required this.action,
    required this.icon,
    required this.label,
    this.isDestructive = false,
  });

  final RecordingSlotAction action;
  final IconData icon;
  final String label;
  final bool isDestructive;
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.slotId, required this.item});

  final String slotId;
  final _RecordingSlotActionItem item;

  @override
  Widget build(BuildContext context) {
    final errorColor = Theme.of(context).colorScheme.error;
    final iconColor = item.isDestructive ? errorColor : AppColors.textMuted;
    final labelColor = item.isDestructive ? errorColor : AppColors.textPrimary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey(
          'recording-library-slot-action-${item.action.name}-$slotId',
        ),
        onTap: () => Navigator.of(context).pop(item.action),
        splashColor: AppColors.settingsPressed,
        highlightColor: AppColors.settingsPressed,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 52,
          child: Row(
            children: [
              const SizedBox(width: 12),
              Icon(item.icon, size: 22, color: iconColor),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  item.label,
                  style: AppTextStyles.homeBody.copyWith(color: labelColor),
                ),
              ),
              const SizedBox(width: 12),
            ],
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
