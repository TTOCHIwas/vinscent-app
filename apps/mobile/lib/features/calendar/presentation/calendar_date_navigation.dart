import 'dart:math' as math;

import '../../../core/date/app_date_policy.dart';

class CalendarDateNavigation {
  const CalendarDateNavigation();

  DateTime? moveByDay({
    required DateTime selectedDate,
    required int dayOffset,
    required DateTime relationshipStartDate,
  }) {
    return _withinSupportedRange(
      calendarDateOnly(selectedDate).add(Duration(days: dayOffset)),
      relationshipStartDate,
    );
  }

  DateTime? moveByWeek({
    required DateTime selectedDate,
    required int weekOffset,
    required DateTime relationshipStartDate,
  }) {
    return _withinSupportedRange(
      calendarDateOnly(selectedDate).add(Duration(days: weekOffset * 7)),
      relationshipStartDate,
    );
  }

  DateTime? moveByMonth({
    required DateTime selectedDate,
    required int monthOffset,
    required DateTime relationshipStartDate,
  }) {
    final selected = calendarDateOnly(selectedDate);
    final targetMonth = DateTime(selected.year, selected.month + monthOffset);
    if (targetMonth.year > appCalendarLastSupportedDate.year) {
      return null;
    }

    final start = calendarDateOnly(relationshipStartDate);
    final startMonth = calendarMonthOnly(start);
    if (targetMonth.isBefore(startMonth)) {
      return null;
    }

    final lastDay = DateTime(targetMonth.year, targetMonth.month + 1, 0).day;
    final target = DateTime(
      targetMonth.year,
      targetMonth.month,
      math.min(selected.day, lastDay),
    );
    if (target.isBefore(start)) {
      return start;
    }
    return target;
  }

  DateTime? _withinSupportedRange(
    DateTime target,
    DateTime relationshipStartDate,
  ) {
    final start = calendarDateOnly(relationshipStartDate);
    if (target.isBefore(start) ||
        target.isAfter(appCalendarLastSupportedDate)) {
      return null;
    }
    return target;
  }
}
