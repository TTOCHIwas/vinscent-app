import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/date/app_date_policy.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../story_loops/application/story_loop_month_summary_provider.dart';
import '../../../story_loops/data/story_loop_month_summary_day.dart';
import '../../application/couple_anniversary_resolver.dart';
import '../../application/couple_calendar_event_provider.dart';
import '../../data/couple_calendar_event.dart';
import '../calendar_month_layout_metrics.dart';
import 'calendar_month_story_cell.dart';

class CalendarResponsiveMonth extends ConsumerWidget {
  const CalendarResponsiveMonth({
    super.key,
    required this.visibleMonth,
    required this.relationshipStartDate,
    required this.selectedDate,
    required this.onDatePressed,
  });

  final DateTime visibleMonth;
  final DateTime relationshipStartDate;
  final DateTime? selectedDate;
  final ValueChanged<DateTime> onDatePressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monthSummary = ref.watch(storyLoopMonthSummaryProvider(visibleMonth));
    final calendarEvents = ref.watch(
      coupleCalendarEventMonthProvider(visibleMonth),
    );
    final summaryByDate = monthSummary.maybeWhen(
      data: (entries) => {
        for (final entry in entries) calendarDateOnly(entry.coupleDate): entry,
      },
      orElse: () => const <DateTime, StoryLoopMonthSummaryDay>{},
    );
    final eventsByDate = <DateTime, List<CoupleCalendarEvent>>{};
    for (final event
        in calendarEvents.asData?.value ?? const <CoupleCalendarEvent>[]) {
      eventsByDate
          .putIfAbsent(calendarDateOnly(event.occurrenceDate), () => [])
          .add(event);
    }
    final anniversaryLabels = <DateTime, String>{};
    const anniversaryResolver = CoupleAnniversaryResolver();
    for (final date in _calendarDays(visibleMonth)) {
      final occurrences = anniversaryResolver.resolve(
        startDate: relationshipStartDate,
        date: date,
      );
      if (occurrences.isNotEmpty) {
        anniversaryLabels[calendarDateOnly(date)] = occurrences.first.label;
      }
    }

    return SliverPersistentHeader(
      pinned: true,
      delegate: _CalendarMonthDelegate(
        visibleMonth: visibleMonth,
        relationshipStartDate: relationshipStartDate,
        selectedDate: selectedDate,
        summaryByDate: summaryByDate,
        eventsByDate: eventsByDate,
        anniversaryLabels: anniversaryLabels,
        onDatePressed: onDatePressed,
      ),
    );
  }
}

class _CalendarMonthDelegate extends SliverPersistentHeaderDelegate {
  _CalendarMonthDelegate({
    required this.visibleMonth,
    required this.relationshipStartDate,
    required this.selectedDate,
    required this.summaryByDate,
    required this.eventsByDate,
    required this.anniversaryLabels,
    required this.onDatePressed,
  });

  static const _weekdayLabels = ['일', '월', '화', '수', '목', '금', '토'];
  static const _topPadding = 8.0;
  static const _weekdayHeight = 20.0;
  static const _weekdayGridGap = 8.0;
  static const _columnGap = 4.0;

  final DateTime visibleMonth;
  final DateTime relationshipStartDate;
  final DateTime? selectedDate;
  final Map<DateTime, StoryLoopMonthSummaryDay> summaryByDate;
  final Map<DateTime, List<CoupleCalendarEvent>> eventsByDate;
  final Map<DateTime, String> anniversaryLabels;
  final ValueChanged<DateTime> onDatePressed;

  @override
  double get maxExtent => CalendarMonthLayoutMetrics.expandedExtent;

  @override
  double get minExtent => CalendarMonthLayoutMetrics.collapsedExtent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final values = CalendarMonthLayoutMetrics.resolve(shrinkOffset);
    final days = _calendarDays(visibleMonth);
    final selectedRow = _selectedRow(days);
    final rowPitch = values.rowHeight + values.rowGap;
    final gridTranslation = -(selectedRow * rowPitch * values.collapseProgress);

    return ColoredBox(
      color: AppColors.background,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth =
              constraints.maxWidth - (values.horizontalPadding * 2);
          final cellWidth =
              (availableWidth - (_columnGap * 6)) / DateTime.daysPerWeek;
          final gridTop = _topPadding + _weekdayHeight + _weekdayGridGap;

          return ClipRect(
            child: Stack(
              children: [
                for (var index = 0; index < DateTime.daysPerWeek; index++)
                  Positioned(
                    left:
                        values.horizontalPadding +
                        (index * (cellWidth + _columnGap)),
                    top: _topPadding,
                    width: cellWidth,
                    height: _weekdayHeight,
                    child: _WeekdayCell(label: _weekdayLabels[index]),
                  ),
                for (var index = 0; index < days.length; index++)
                  Positioned(
                    left:
                        values.horizontalPadding +
                        ((index % DateTime.daysPerWeek) *
                            (cellWidth + _columnGap)),
                    top:
                        gridTop +
                        ((index ~/ DateTime.daysPerWeek) * rowPitch) +
                        gridTranslation,
                    width: cellWidth,
                    height: values.rowHeight,
                    child: _DateCell(
                      date: days[index],
                      isCurrentMonth: _isSameMonth(days[index], visibleMonth),
                      isEnabled: _isEnabled(days[index]),
                      isSelected:
                          selectedDate != null &&
                          _isSameDate(days[index], selectedDate!),
                      summary: summaryByDate[calendarDateOnly(days[index])],
                      events:
                          eventsByDate[calendarDateOnly(days[index])] ??
                          const [],
                      anniversaryLabel:
                          anniversaryLabels[calendarDateOnly(days[index])],
                      eventIndicatorLimit: values.eventIndicatorLimit,
                      onPressed: () => onDatePressed(days[index]),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  int _selectedRow(List<DateTime> days) {
    final selected = selectedDate;
    if (selected != null && _isSameMonth(selected, visibleMonth)) {
      final index = days.indexWhere((date) => _isSameDate(date, selected));
      if (index >= 0) {
        return index ~/ DateTime.daysPerWeek;
      }
    }

    final monthStartIndex = days.indexWhere(
      (date) =>
          _isSameDate(date, DateTime(visibleMonth.year, visibleMonth.month)),
    );
    return monthStartIndex < 0 ? 0 : monthStartIndex ~/ DateTime.daysPerWeek;
  }

  bool _isEnabled(DateTime date) {
    if (!_isSameMonth(date, visibleMonth)) {
      return false;
    }
    return !calendarDateOnly(
      date,
    ).isBefore(calendarDateOnly(relationshipStartDate));
  }

  @override
  bool shouldRebuild(covariant _CalendarMonthDelegate oldDelegate) {
    return visibleMonth != oldDelegate.visibleMonth ||
        relationshipStartDate != oldDelegate.relationshipStartDate ||
        selectedDate != oldDelegate.selectedDate ||
        summaryByDate != oldDelegate.summaryByDate ||
        eventsByDate != oldDelegate.eventsByDate ||
        anniversaryLabels != oldDelegate.anniversaryLabels;
  }
}

class _WeekdayCell extends StatelessWidget {
  const _WeekdayCell({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        label,
        style: AppTypography.applyToStyle(
          AppTextStyles.homeCharacterLabel.copyWith(
            color: const Color(0xFF8C8C8C),
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _DateCell extends StatelessWidget {
  const _DateCell({
    required this.date,
    required this.isCurrentMonth,
    required this.isEnabled,
    required this.isSelected,
    required this.summary,
    required this.events,
    required this.anniversaryLabel,
    required this.eventIndicatorLimit,
    required this.onPressed,
  });

  final DateTime date;
  final bool isCurrentMonth;
  final bool isEnabled;
  final bool isSelected;
  final StoryLoopMonthSummaryDay? summary;
  final List<CoupleCalendarEvent> events;
  final String? anniversaryLabel;
  final int eventIndicatorLimit;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: isEnabled,
      selected: isSelected,
      label: [
        '${date.day}일',
        ?anniversaryLabel,
        if (events.isNotEmpty) '일정 ${events.length}개',
      ].join(', '),
      child: InkWell(
        onTap: isEnabled ? onPressed : null,
        borderRadius: BorderRadius.circular(4),
        child: CalendarMonthStoryCell(
          date: date,
          textColor: _textColor,
          isSelected: isSelected,
          summary: isCurrentMonth ? summary : null,
          events: isCurrentMonth ? events : const [],
          anniversaryLabel: isCurrentMonth ? anniversaryLabel : null,
          eventIndicatorLimit: eventIndicatorLimit,
        ),
      ),
    );
  }

  Color get _textColor {
    if (!isCurrentMonth || !isEnabled) {
      return const Color(0xFFC7C7C7);
    }
    return const Color(0xFF171717);
  }
}

DateTime _monthOnly(DateTime date) {
  return DateTime(date.year, date.month);
}

List<DateTime> _calendarDays(DateTime visibleMonth) {
  final firstDay = _monthOnly(visibleMonth);
  final sundayOffset = firstDay.weekday % DateTime.daysPerWeek;
  final startDate = firstDay.subtract(Duration(days: sundayOffset));
  return [
    for (var index = 0; index < 42; index++)
      startDate.add(Duration(days: index)),
  ];
}

bool _isSameDate(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

bool _isSameMonth(DateTime left, DateTime right) {
  return left.year == right.year && left.month == right.month;
}
