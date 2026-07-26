import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/calendar_cell_preview_mode.dart';

class CalendarCellPreviewFilterButton extends StatelessWidget {
  const CalendarCellPreviewFilterButton({
    super.key,
    required this.selectedMode,
    required this.onSelected,
  });

  final CalendarCellPreviewMode selectedMode;
  final ValueChanged<CalendarCellPreviewMode> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 40,
      child: PopupMenuButton<CalendarCellPreviewMode>(
        tooltip: '캘린더 표시',
        initialValue: selectedMode,
        position: PopupMenuPosition.under,
        offset: const Offset(0, 4),
        color: AppColors.settingsSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        onSelected: onSelected,
        itemBuilder: (context) => [
          for (final mode in CalendarCellPreviewMode.values)
            CheckedPopupMenuItem(
              key: ValueKey('calendar-cell-preview-mode-${mode.storageValue}'),
              value: mode,
              checked: mode == selectedMode,
              child: Text(_labelFor(mode), style: AppTextStyles.homeBody),
            ),
        ],
        child: const Center(
          child: Icon(
            Icons.tune_rounded,
            size: 24,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  String _labelFor(CalendarCellPreviewMode mode) {
    return switch (mode) {
      CalendarCellPreviewMode.all => '모두',
      CalendarCellPreviewMode.cardsOnly => '카드만',
      CalendarCellPreviewMode.eventsOnly => '일정만',
    };
  }
}
