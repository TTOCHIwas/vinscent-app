import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/date/app_date_policy.dart';
import '../../../core/date/today_controller.dart';
import '../../couple/application/couple_controller.dart';
import '../data/story_loop_detail_navigation_state.dart';

final storyLoopDetailNavigationProvider = FutureProvider.autoDispose
    .family<StoryLoopDetailNavigationState, DateTime?>((ref, targetDate) async {
      final fallbackToday = calendarDateOnly(ref.watch(todayControllerProvider));
      final couple = await ref.watch(coupleControllerProvider.future);
      final currentDate = calendarDateOnly(
        couple?.effectiveCurrentDate ?? fallbackToday,
      );
      final requestedDate = calendarDateOnly(targetDate ?? currentDate);

      if (couple == null ||
          !couple.canReadSharedData ||
          !couple.hasRelationshipStartDate) {
        return StoryLoopDetailNavigationState(currentDate: requestedDate);
      }

      final relationshipStartDate = calendarDateOnly(
        couple.relationshipStartDate!,
      );
      final isWithinRange =
          !requestedDate.isBefore(relationshipStartDate) &&
          !requestedDate.isAfter(currentDate);

      if (!isWithinRange) {
        return StoryLoopDetailNavigationState(currentDate: requestedDate);
      }

      return StoryLoopDetailNavigationState(
        currentDate: requestedDate,
        previousDate: requestedDate.isAfter(relationshipStartDate)
            ? requestedDate.subtract(const Duration(days: 1))
            : null,
        nextDate: requestedDate.isBefore(currentDate)
            ? requestedDate.add(const Duration(days: 1))
            : null,
      );
    }, retry: (_, _) => null);
