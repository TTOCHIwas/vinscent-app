import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/date/app_date_policy.dart';
import '../../../core/date/today_controller.dart';
import '../../couple/application/couple_controller.dart';
import '../../couple/data/couple.dart';
import '../data/story_loop_read_repository.dart';
import '../data/today_story_loop_summary.dart';
import '../data/today_story_loop_summary_state.dart';

final todayStoryLoopSummaryProvider =
    FutureProvider.autoDispose<TodayStoryLoopSummaryState>((ref) async {
      final fallbackToday = calendarDateOnly(ref.watch(todayControllerProvider));
      final couple = await ref.watch(coupleControllerProvider.future);
      final currentDate = calendarDateOnly(
        couple?.effectiveCurrentDate ?? fallbackToday,
      );

      if (couple == null ||
          !couple.canReadSharedData ||
          !couple.hasRelationshipStartDate) {
        return const UnavailableTodayStoryLoopSummaryState(
          reason: TodayStoryLoopSummaryUnavailableReason.unavailable,
        );
      }

      final relationshipStartDate = calendarDateOnly(
        couple.relationshipStartDate!,
      );
      final repository = ref.watch(storyLoopReadRepositoryProvider);
      final summary = await repository.fetchTodaySummary();
      final resolvedSummary =
          summary ??
          _buildEmptySummary(
            coupleId: couple.id,
            coupleDate: currentDate,
            accessMode: couple.accessMode,
            canEditStory:
                couple.canEditSharedData &&
                !currentDate.isBefore(relationshipStartDate),
          );

      if (resolvedSummary.isEmpty) {
        return EmptyTodayStoryLoopSummaryState(summary: resolvedSummary);
      }

      return LoadedTodayStoryLoopSummaryState(summary: resolvedSummary);
    }, retry: (_, _) => null);

TodayStoryLoopSummary _buildEmptySummary({
  required String coupleId,
  required DateTime coupleDate,
  required CoupleAccessMode accessMode,
  required bool canEditStory,
}) {
  return TodayStoryLoopSummary(
    coupleId: coupleId,
    coupleDate: coupleDate,
    accessMode: accessMode,
    loopId: null,
    loopStatus: null,
    storyEditLocked: false,
    canEditStory: canEditStory,
    canAnswerQuestion: false,
    cardCount: 0,
    cards: const [],
    question: null,
  );
}
