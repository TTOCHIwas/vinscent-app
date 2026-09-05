import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

const calendarEventReminderOffsets = [0, 1, 3, 7];

Future<int?> showCalendarEventReminderOffsetSheet({
  required BuildContext context,
  required int selectedOffsetDays,
}) {
  return showModalBottomSheet<int>(
    context: context,
    useRootNavigator: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    clipBehavior: Clip.antiAlias,
    builder: (context) => CalendarEventReminderOffsetSheet(
      selectedOffsetDays: selectedOffsetDays,
    ),
  );
}

class CalendarEventReminderOffsetSheet extends StatelessWidget {
  const CalendarEventReminderOffsetSheet({
    super.key,
    required this.selectedOffsetDays,
  });

  final int selectedOffsetDays;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        key: const Key('calendar-event-reminder-offset-sheet'),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: _SheetHandle()),
            const SizedBox(height: 20),
            const Text('알림 날짜', style: AppTextStyles.sectionTitle),
            const SizedBox(height: 12),
            for (final offsetDays in calendarEventReminderOffsets)
              _ReminderOffsetOption(
                offsetDays: offsetDays,
                isSelected: offsetDays == selectedOffsetDays,
                onTap: () => Navigator.of(context).pop(offsetDays),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReminderOffsetOption extends StatelessWidget {
  const _ReminderOffsetOption({
    required this.offsetDays,
    required this.isSelected,
    required this.onTap,
  });

  final int offsetDays;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foregroundColor = isSelected
        ? AppColors.selection
        : AppColors.textPrimary;

    return Semantics(
      button: true,
      selected: isSelected,
      child: Material(
        color: isSelected ? AppColors.selectionSurface : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          key: Key('calendar-event-reminder-offset-$offsetDays'),
          onTap: onTap,
          splashColor: AppColors.settingsPressed,
          highlightColor: AppColors.settingsPressed,
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 52,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      calendarEventReminderOffsetLabel(offsetDays),
                      style: AppTextStyles.homeBodyMedium.copyWith(
                        color: foregroundColor,
                      ),
                    ),
                  ),
                  if (isSelected)
                    const Icon(
                      Icons.check_rounded,
                      size: 20,
                      color: AppColors.selection,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String calendarEventReminderOffsetLabel(int offsetDays) {
  return offsetDays == 0 ? '당일' : '$offsetDays일 전';
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
