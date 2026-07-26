import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/calendar_cell_preview_mode.dart';

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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(child: _SheetHandle()),
            const SizedBox(height: 20),
            const Text('캘린더에 표시', style: AppTextStyles.sectionTitle),
            const SizedBox(height: 12),
            for (
              var index = 0;
              index < CalendarCellPreviewMode.values.length;
              index++
            ) ...[
              _PreviewModeRow(
                mode: CalendarCellPreviewMode.values[index],
                isSelected:
                    CalendarCellPreviewMode.values[index] == selectedMode,
                onTap: () => Navigator.of(
                  context,
                ).pop(CalendarCellPreviewMode.values[index]),
              ),
              if (index < CalendarCellPreviewMode.values.length - 1)
                const SizedBox(height: 4),
            ],
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

class _PreviewModeRow extends StatelessWidget {
  const _PreviewModeRow({
    required this.mode,
    required this.isSelected,
    required this.onTap,
  });

  static const _selectedColor = Color(0xFFF4F4F4);

  final CalendarCellPreviewMode mode;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      child: Material(
        color: isSelected ? _selectedColor : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          key: ValueKey('calendar-cell-preview-mode-${mode.storageValue}'),
          onTap: onTap,
          splashColor: AppColors.settingsPressed,
          highlightColor: AppColors.settingsPressed,
          borderRadius: BorderRadius.circular(6),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 60),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  _PreviewModeIcon(mode: mode),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _labelFor(mode),
                      style: isSelected
                          ? AppTextStyles.homeBodyMedium
                          : AppTextStyles.homeBody,
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (isSelected)
                    Icon(
                      Icons.check_rounded,
                      key: ValueKey(
                        'calendar-cell-preview-selected-${mode.storageValue}',
                      ),
                      size: 22,
                      color: AppColors.textPrimary,
                    )
                  else
                    const SizedBox.square(dimension: 22),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviewModeIcon extends StatelessWidget {
  const _PreviewModeIcon({required this.mode});

  final CalendarCellPreviewMode mode;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('calendar-cell-preview-icon-${mode.storageValue}'),
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.settingsIconBackground,
        borderRadius: BorderRadius.circular(6),
      ),
      child: switch (mode) {
        CalendarCellPreviewMode.all => const SizedBox.square(
          dimension: 25,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                child: Icon(
                  Icons.photo_outlined,
                  size: 18,
                  color: AppColors.textPrimary,
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.settingsIconBackground,
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(1),
                    child: Icon(
                      Icons.sentiment_satisfied_outlined,
                      size: 17,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        CalendarCellPreviewMode.cardsOnly => const Icon(
          Icons.photo_outlined,
          size: 21,
          color: AppColors.textPrimary,
        ),
        CalendarCellPreviewMode.eventsOnly => const Icon(
          Icons.sentiment_satisfied_outlined,
          size: 21,
          color: AppColors.textPrimary,
        ),
      },
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
