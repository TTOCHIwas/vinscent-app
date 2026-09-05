import 'package:flutter/material.dart';

import '../../../../core/date/app_date_policy.dart';
import '../../../../core/presentation/widgets/app_action_button.dart';
import '../../../../core/presentation/widgets/app_horizontal_page_transition.dart';
import '../../../../core/presentation/widgets/app_horizontal_swipe_region.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

Future<DateTime?> showCalendarEventDatePickerSheet({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime minDate,
  required DateTime maxDate,
}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => CalendarEventDatePickerSheet(
      initialDate: initialDate,
      minDate: minDate,
      maxDate: maxDate,
    ),
  );
}

class CalendarEventDatePickerSheet extends StatefulWidget {
  const CalendarEventDatePickerSheet({
    super.key,
    required this.initialDate,
    required this.minDate,
    required this.maxDate,
  });

  final DateTime initialDate;
  final DateTime minDate;
  final DateTime maxDate;

  @override
  State<CalendarEventDatePickerSheet> createState() =>
      _CalendarEventDatePickerSheetState();
}

class _CalendarEventDatePickerSheetState
    extends State<CalendarEventDatePickerSheet> {
  static const _weekdayLabels = ['일', '월', '화', '수', '목', '금', '토'];
  static const _gridHeight = 264.0;

  late final DateTime _minDate;
  late final DateTime _maxDate;
  late DateTime _selectedDate;
  late DateTime _visibleMonth;
  AppHorizontalPageDirection _transitionDirection =
      AppHorizontalPageDirection.next;

  @override
  void initState() {
    super.initState();
    _minDate = calendarDateOnly(widget.minDate);
    _maxDate = calendarDateOnly(widget.maxDate);
    assert(!_minDate.isAfter(_maxDate));
    _selectedDate = _clampDate(widget.initialDate);
    _visibleMonth = calendarMonthOnly(_selectedDate);
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          key: const Key('calendar-event-date-picker-sheet'),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: _SheetHandle()),
              const SizedBox(height: 20),
              const Text('날짜 선택', style: AppTextStyles.sectionTitle),
              const SizedBox(height: 12),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    children: [
                      _MonthHeader(
                        visibleMonth: _visibleMonth,
                        canMovePrevious: _canMoveMonth(-1),
                        canMoveNext: _canMoveMonth(1),
                        onPreviousPressed: () => _moveMonth(-1),
                        onNextPressed: () => _moveMonth(1),
                      ),
                      const SizedBox(height: 8),
                      const _WeekdayHeader(labels: _weekdayLabels),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: _gridHeight,
                        child: AppHorizontalSwipeRegion(
                          key: const Key(
                            'calendar-event-date-picker-swipe-region',
                          ),
                          minimumDistance: 48,
                          onSwipeRight: _canMoveMonth(-1)
                              ? () => _moveMonth(-1)
                              : null,
                          onSwipeLeft: _canMoveMonth(1)
                              ? () => _moveMonth(1)
                              : null,
                          child: AppHorizontalPageTransition(
                            transitionKey: _visibleMonth,
                            direction: _transitionDirection,
                            child: _DateGrid(
                              visibleMonth: _visibleMonth,
                              selectedDate: _selectedDate,
                              minDate: _minDate,
                              maxDate: _maxDate,
                              onDateSelected: _selectDate,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              AppActionButton(
                key: const Key('calendar-event-date-picker-complete'),
                label: '완료',
                enabled: true,
                onPressed: () => Navigator.of(context).pop(_selectedDate),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _canMoveMonth(int offset) {
    final target = DateTime(_visibleMonth.year, _visibleMonth.month + offset);
    return !target.isBefore(calendarMonthOnly(_minDate)) &&
        !target.isAfter(calendarMonthOnly(_maxDate));
  }

  void _moveMonth(int offset) {
    if (!_canMoveMonth(offset)) {
      return;
    }
    setState(() {
      _transitionDirection = offset > 0
          ? AppHorizontalPageDirection.next
          : AppHorizontalPageDirection.previous;
      _visibleMonth = DateTime(
        _visibleMonth.year,
        _visibleMonth.month + offset,
      );
    });
  }

  void _selectDate(DateTime date) {
    setState(() {
      _selectedDate = calendarDateOnly(date);
    });
  }

  DateTime _clampDate(DateTime value) {
    final date = calendarDateOnly(value);
    if (date.isBefore(_minDate)) {
      return _minDate;
    }
    if (date.isAfter(_maxDate)) {
      return _maxDate;
    }
    return date;
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.visibleMonth,
    required this.canMovePrevious,
    required this.canMoveNext,
    required this.onPreviousPressed,
    required this.onNextPressed,
  });

  final DateTime visibleMonth;
  final bool canMovePrevious;
  final bool canMoveNext;
  final VoidCallback onPreviousPressed;
  final VoidCallback onNextPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          IconButton(
            key: const Key('calendar-event-date-picker-previous-month'),
            tooltip: '이전 달',
            onPressed: canMovePrevious ? onPreviousPressed : null,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Expanded(
            child: Text(
              '${visibleMonth.year}년 ${visibleMonth.month}월',
              key: const Key('calendar-event-date-picker-month-label'),
              textAlign: TextAlign.center,
              style: AppTextStyles.homeBodyMedium,
            ),
          ),
          IconButton(
            key: const Key('calendar-event-date-picker-next-month'),
            tooltip: '다음 달',
            onPressed: canMoveNext ? onNextPressed : null,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader({required this.labels});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      child: Row(
        children: [
          for (var index = 0; index < labels.length; index++)
            Expanded(
              child: Center(
                child: Text(
                  labels[index],
                  key: Key('calendar-event-date-picker-weekday-$index'),
                  style: AppTextStyles.homeCharacterLabel.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DateGrid extends StatelessWidget {
  const _DateGrid({
    required this.visibleMonth,
    required this.selectedDate,
    required this.minDate,
    required this.maxDate,
    required this.onDateSelected,
  });

  final DateTime visibleMonth;
  final DateTime selectedDate;
  final DateTime minDate;
  final DateTime maxDate;
  final ValueChanged<DateTime> onDateSelected;

  @override
  Widget build(BuildContext context) {
    final days = _calendarDays(visibleMonth);
    return GridView.builder(
      key: ValueKey(visibleMonth),
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: DateTime.daysPerWeek,
        mainAxisExtent: 44,
      ),
      itemCount: days.length,
      itemBuilder: (context, index) {
        final date = days[index];
        final isCurrentMonth = isSameCalendarMonth(date, visibleMonth);
        final isEnabled =
            isCurrentMonth && !date.isBefore(minDate) && !date.isAfter(maxDate);
        return _DateCell(
          date: date,
          isEnabled: isEnabled,
          isSelected: isEnabled && isSameCalendarDate(date, selectedDate),
          onPressed: () => onDateSelected(date),
        );
      },
    );
  }
}

class _DateCell extends StatelessWidget {
  const _DateCell({
    required this.date,
    required this.isEnabled,
    required this.isSelected,
    required this.onPressed,
  });

  final DateTime date;
  final bool isEnabled;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final textColor = isSelected
        ? AppColors.onSelection
        : isEnabled
        ? AppColors.textPrimary
        : AppColors.textPlaceholder;

    return Semantics(
      button: true,
      enabled: isEnabled,
      selected: isSelected,
      label: '${date.year}년 ${date.month}월 ${date.day}일',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: Key('calendar-event-date-${formatCalendarDate(date)}'),
          onTap: isEnabled ? onPressed : null,
          borderRadius: BorderRadius.circular(20),
          splashColor: AppColors.settingsPressed,
          highlightColor: AppColors.settingsPressed,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOutCubic,
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.actionPrimary
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Text(
                '${date.day}',
                style: AppTextStyles.homeBodyMedium.copyWith(color: textColor),
              ),
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

List<DateTime> _calendarDays(DateTime visibleMonth) {
  final firstDay = calendarMonthOnly(visibleMonth);
  final sundayOffset = firstDay.weekday % DateTime.daysPerWeek;
  final startDate = firstDay.subtract(Duration(days: sundayOffset));
  return [
    for (var index = 0; index < 42; index++)
      startDate.add(Duration(days: index)),
  ];
}
