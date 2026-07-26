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
            PopupMenuItem(
              key: ValueKey('calendar-cell-preview-mode-${mode.storageValue}'),
              value: mode,
              child: SizedBox(
                width: 124,
                child: Row(
                  children: [
                    _CalendarCellPreviewModeIcon(mode: mode),
                    const SizedBox(width: 12),
                    Text(_labelFor(mode), style: AppTextStyles.homeBody),
                    const Spacer(),
                    if (mode == selectedMode)
                      Icon(
                        Icons.check_rounded,
                        key: ValueKey(
                          'calendar-cell-preview-selected-'
                          '${mode.storageValue}',
                        ),
                        size: 20,
                        color: AppColors.textPrimary,
                      )
                    else
                      const SizedBox.square(dimension: 20),
                  ],
                ),
              ),
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

class _CalendarCellPreviewModeIcon extends StatelessWidget {
  const _CalendarCellPreviewModeIcon({required this.mode});

  final CalendarCellPreviewMode mode;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      key: ValueKey('calendar-cell-preview-icon-${mode.storageValue}'),
      dimension: 24,
      child: switch (mode) {
        CalendarCellPreviewMode.all => const Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              child: Icon(
                Icons.photo_outlined,
                size: 17,
                color: AppColors.textMuted,
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Icon(
                Icons.sentiment_satisfied_alt_rounded,
                size: 17,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        CalendarCellPreviewMode.cardsOnly => const Icon(
          Icons.photo_outlined,
          size: 22,
          color: AppColors.textPrimary,
        ),
        CalendarCellPreviewMode.eventsOnly => const Icon(
          Icons.sentiment_satisfied_alt_rounded,
          size: 22,
          color: AppColors.textPrimary,
        ),
      },
    );
  }
}
