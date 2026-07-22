import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/date/app_date_policy.dart';
import '../../../core/date/today_controller.dart';
import '../../couple/application/couple_controller.dart';
import '../../couple/data/couple.dart';
import '../data/story_loop_detail.dart';
import '../data/story_loop_detail_state.dart';
import '../data/story_loop_read_repository.dart';
import 'story_loop_realtime_controller.dart';

final storyLoopDetailProvider = FutureProvider.autoDispose
    .family<StoryLoopDetailState, DateTime?>((ref, targetDate) async {
      ref.watch(storyLoopReadRevisionProvider);
      final fallbackToday = calendarDateOnly(
        ref.watch(todayControllerProvider),
      );
      final couple = await ref.watch(coupleControllerProvider.future);
      final currentDate = calendarDateOnly(
        couple?.effectiveCurrentDate ?? fallbackToday,
      );
      final normalizedTargetDate = calendarDateOnly(targetDate ?? currentDate);

      if (couple == null ||
          !couple.canReadSharedData ||
          !couple.hasRelationshipStartDate) {
        return UnavailableStoryLoopDetailState(
          reason: StoryLoopDetailUnavailableReason.unavailable,
          targetDate: normalizedTargetDate,
        );
      }

      final relationshipStartDate = calendarDateOnly(
        couple.relationshipStartDate!,
      );

      if (normalizedTargetDate.isBefore(relationshipStartDate)) {
        return UnavailableStoryLoopDetailState(
          reason: StoryLoopDetailUnavailableReason.beforeRelationshipStartDate,
          targetDate: normalizedTargetDate,
        );
      }

      if (normalizedTargetDate.isAfter(currentDate)) {
        return UnavailableStoryLoopDetailState(
          reason: StoryLoopDetailUnavailableReason.futureDate,
          targetDate: normalizedTargetDate,
        );
      }

      final repository = ref.watch(storyLoopReadRepositoryProvider);
      final detail = await repository.fetchDetail(normalizedTargetDate);
      final resolvedDetail =
          detail ??
          _buildEmptyDetail(
            coupleId: couple.id,
            coupleDate: normalizedTargetDate,
            accessMode: couple.accessMode,
            canEditStory:
                couple.canEditSharedData &&
                _isSameCalendarDate(normalizedTargetDate, currentDate),
          );

      if (resolvedDetail.isEmpty) {
        return EmptyStoryLoopDetailState(
          targetDate: normalizedTargetDate,
          detail: resolvedDetail,
        );
      }

      return LoadedStoryLoopDetailState(
        targetDate: normalizedTargetDate,
        detail: resolvedDetail,
      );
    }, retry: (_, _) => null);

StoryLoopDetail _buildEmptyDetail({
  required String coupleId,
  required DateTime coupleDate,
  required CoupleAccessMode accessMode,
  required bool canEditStory,
}) {
  return StoryLoopDetail(
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

bool _isSameCalendarDate(DateTime first, DateTime second) {
  return first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}
