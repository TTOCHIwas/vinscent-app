import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/date/app_date_policy.dart';
import '../../couple/application/couple_controller.dart';
import '../data/story_loop_month_summary_day.dart';
import '../data/story_loop_read_repository.dart';
import 'story_loop_realtime_controller.dart';

final storyLoopMonthSummaryProvider = FutureProvider.autoDispose
    .family<List<StoryLoopMonthSummaryDay>, DateTime>((ref, month) async {
      ref.watch(storyLoopReadRevisionProvider);
      final couple = await ref.watch(coupleControllerProvider.future);
      if (couple == null ||
          !couple.canReadSharedData ||
          !couple.hasRelationshipStartDate) {
        return const [];
      }

      final currentDate = calendarDateOnly(couple.effectiveCurrentDate);
      final relationshipStartDate = calendarDateOnly(
        couple.relationshipStartDate!,
      );
      final normalizedMonth = calendarMonthOnly(month);
      final currentMonth = calendarMonthOnly(currentDate);
      final relationshipStartMonth = calendarMonthOnly(relationshipStartDate);

      if (normalizedMonth.isAfter(currentMonth) ||
          normalizedMonth.isBefore(relationshipStartMonth)) {
        return const [];
      }

      final repository = ref.watch(storyLoopReadRepositoryProvider);
      return repository.fetchMonthSummary(normalizedMonth);
    }, retry: (_, _) => null);

final storyLoopMonthSummaryByDateProvider = FutureProvider.autoDispose
    .family<Map<DateTime, StoryLoopMonthSummaryDay>, DateTime>((
      ref,
      month,
    ) async {
      final entries = await ref.watch(
        storyLoopMonthSummaryProvider(calendarMonthOnly(month)).future,
      );
      return Map<DateTime, StoryLoopMonthSummaryDay>.unmodifiable({
        for (final entry in entries) calendarDateOnly(entry.coupleDate): entry,
      });
    }, retry: (_, _) => null);
