import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

enum RecordingSlotAction { artwork, homePlacement, replace, delete }

Future<RecordingSlotAction?> showRecordingSlotActionSheet({
  required BuildContext context,
  required String slotId,
  required String? artworkLabel,
  required IconData? artworkIcon,
  required bool showHomePlacement,
  required bool showReplace,
  required bool showDelete,
}) {
  assert(
    (artworkLabel == null) == (artworkIcon == null),
    'Artwork label and icon must either both be provided or both be omitted.',
  );

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
      artworkLabel: artworkLabel,
      artworkIcon: artworkIcon,
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
    required this.artworkLabel,
    required this.artworkIcon,
    required this.showHomePlacement,
    required this.showReplace,
    required this.showDelete,
  });

  final String slotId;
  final String? artworkLabel;
  final IconData? artworkIcon;
  final bool showHomePlacement;
  final bool showReplace;
  final bool showDelete;

  @override
  Widget build(BuildContext context) {
    final items = <_RecordingSlotActionItem>[
      if (artworkLabel case final label?)
        _RecordingSlotActionItem(
          action: RecordingSlotAction.artwork,
          icon: artworkIcon!,
          label: label,
        ),
      if (showHomePlacement)
        const _RecordingSlotActionItem(
          action: RecordingSlotAction.homePlacement,
          icon: Icons.add_to_home_screen_outlined,
          label: '홈에 배치',
        ),
      if (showReplace)
        const _RecordingSlotActionItem(
          action: RecordingSlotAction.replace,
          icon: Icons.swap_horiz_rounded,
          label: '현재 녹음으로 교체',
        ),
      if (showDelete)
        const _RecordingSlotActionItem(
          action: RecordingSlotAction.delete,
          icon: Icons.delete_outline_rounded,
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
    final foregroundColor = item.isDestructive
        ? Theme.of(context).colorScheme.error
        : AppColors.textPrimary;

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
              Icon(item.icon, size: 22, color: foregroundColor),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  item.label,
                  style: AppTextStyles.homeBodyMedium.copyWith(
                    color: foregroundColor,
                  ),
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
