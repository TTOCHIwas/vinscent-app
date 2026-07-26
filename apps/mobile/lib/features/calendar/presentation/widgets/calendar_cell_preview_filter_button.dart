import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/calendar_cell_preview_mode.dart';
import 'calendar_cell_preview_filter_sheet.dart';

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
      child: IconButton(
        tooltip: '캘린더 표시',
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 40, height: 40),
        onPressed: () => _openFilterSheet(context),
        icon: const Icon(
          Icons.tune_rounded,
          size: 24,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Future<void> _openFilterSheet(BuildContext context) async {
    final mode = await showCalendarCellPreviewFilterSheet(
      context: context,
      selectedMode: selectedMode,
    );

    if (!context.mounted || mode == null || mode == selectedMode) {
      return;
    }
    onSelected(mode);
  }
}
