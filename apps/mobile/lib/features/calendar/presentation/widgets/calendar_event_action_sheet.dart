import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

enum CalendarEventAction { edit, delete }

Future<CalendarEventAction?> showCalendarEventActionSheet({
  required BuildContext context,
  required String eventId,
}) {
  return showModalBottomSheet<CalendarEventAction>(
    context: context,
    useRootNavigator: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    clipBehavior: Clip.antiAlias,
    builder: (context) => CalendarEventActionSheet(eventId: eventId),
  );
}

class CalendarEventActionSheet extends StatelessWidget {
  const CalendarEventActionSheet({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        key: ValueKey('calendar-event-action-sheet-$eventId'),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _SheetHandle(),
            const SizedBox(height: 12),
            _ActionRow(
              actionKey: ValueKey('calendar-event-action-edit-$eventId'),
              icon: Icons.edit_outlined,
              label: '수정',
              onPressed: () =>
                  Navigator.of(context).pop(CalendarEventAction.edit),
            ),
            const SizedBox(height: 4),
            _ActionRow(
              actionKey: ValueKey('calendar-event-action-delete-$eventId'),
              icon: Icons.delete_outline_rounded,
              label: '삭제',
              color: Theme.of(context).colorScheme.error,
              onPressed: () =>
                  Navigator.of(context).pop(CalendarEventAction.delete),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.actionKey,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color,
  });

  final Key actionKey;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final foregroundColor = color ?? AppColors.textPrimary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: actionKey,
        onTap: onPressed,
        splashColor: AppColors.settingsPressed,
        highlightColor: AppColors.settingsPressed,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 52,
          child: Row(
            children: [
              const SizedBox(width: 12),
              Icon(icon, size: 22, color: foregroundColor),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
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
