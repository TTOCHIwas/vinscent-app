import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/calendar_cell_preview_mode.dart';
import 'calendar_cell_preview_mode_thumbnail.dart';

Future<CalendarCellPreviewMode?> showCalendarCellPreviewFilterSheet({
  required BuildContext context,
  required CalendarCellPreviewMode selectedMode,
}) {
  return showModalBottomSheet<CalendarCellPreviewMode>(
    context: context,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    clipBehavior: Clip.antiAlias,
    builder: (context) =>
        CalendarCellPreviewFilterSheet(selectedMode: selectedMode),
  );
}

class CalendarCellPreviewFilterSheet extends StatelessWidget {
  const CalendarCellPreviewFilterSheet({super.key, required this.selectedMode});

  final CalendarCellPreviewMode selectedMode;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        key: const Key('calendar-cell-preview-filter-sheet'),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Center(child: _SheetHandle()),
            const SizedBox(height: 20),
            const Text('캘린더에 표시', style: AppTextStyles.sectionTitle),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (
                  var index = 0;
                  index < CalendarCellPreviewMode.values.length;
                  index++
                ) ...[
                  Expanded(
                    child: _PreviewModeOption(
                      mode: CalendarCellPreviewMode.values[index],
                      isSelected:
                          CalendarCellPreviewMode.values[index] == selectedMode,
                      onTap: () => Navigator.of(
                        context,
                      ).pop(CalendarCellPreviewMode.values[index]),
                    ),
                  ),
                  if (index < CalendarCellPreviewMode.values.length - 1)
                    const SizedBox(width: 8),
                ],
              ],
            ),
          ],
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

class _PreviewModeOption extends StatelessWidget {
  const _PreviewModeOption({
    required this.mode,
    required this.isSelected,
    required this.onTap,
  });

  final CalendarCellPreviewMode mode;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('calendar-cell-preview-mode-${mode.storageValue}'),
          onTap: onTap,
          splashColor: AppColors.settingsPressed,
          highlightColor: AppColors.settingsPressed,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CalendarCellPreviewModeThumbnail(mode: mode),
                const SizedBox(height: 10),
                Container(
                  key: isSelected
                      ? ValueKey(
                          'calendar-cell-preview-selected-${mode.storageValue}',
                        )
                      : null,
                  constraints: const BoxConstraints(minHeight: 30),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  alignment: Alignment.center,
                  decoration: isSelected
                      ? BoxDecoration(
                          color: AppColors.settingsIconBackground,
                          borderRadius: BorderRadius.circular(15),
                        )
                      : null,
                  child: Text(
                    _labelFor(mode),
                    maxLines: 1,
                    style: AppTextStyles.homeCharacterLabel.copyWith(
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
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

String _labelFor(CalendarCellPreviewMode mode) {
  return switch (mode) {
    CalendarCellPreviewMode.all => '모두',
    CalendarCellPreviewMode.cardsOnly => '카드만',
    CalendarCellPreviewMode.eventsOnly => '일정만',
  };
}
