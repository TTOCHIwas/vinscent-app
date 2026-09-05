import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/date/app_date_policy.dart';
import '../../story_loops/application/story_loop_month_summary_provider.dart';
import '../data/calendar_cell_preview_mode.dart';
import 'couple_calendar_event_provider.dart';

typedef CalendarAdjacentMonthPrefetchRequest = ({
  DateTime visibleMonth,
  DateTime relationshipStartDate,
  CalendarCellPreviewMode previewMode,
});

final calendarAdjacentMonthPrefetchProvider = Provider.autoDispose
    .family<void, CalendarAdjacentMonthPrefetchRequest>((ref, request) {
      final firstMonth = calendarMonthOnly(request.relationshipStartDate);
      final lastMonth = calendarMonthOnly(appCalendarLastSupportedDate);
      final visibleMonth = calendarMonthOnly(request.visibleMonth);
      final prefetchMonths = [
        visibleMonth,
        DateTime(visibleMonth.year, visibleMonth.month - 1),
        DateTime(visibleMonth.year, visibleMonth.month + 1),
      ];

      for (final month in prefetchMonths) {
        if (month.isBefore(firstMonth) || month.isAfter(lastMonth)) {
          continue;
        }
        if (request.previewMode.includesCards) {
          ref.watch(storyLoopMonthSummaryByDateProvider(month));
        }
        if (request.previewMode.includesEvents) {
          ref.watch(coupleCalendarEventsByDateProvider(month));
        }
      }
    });
