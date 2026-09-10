import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/date/app_date_policy.dart';
import '../../couple/application/couple_controller.dart';
import '../data/story_card_stack_read_repository.dart';
import '../data/today_story_card_stacks.dart';
import 'story_loop_realtime_controller.dart';

final todayStoryCardStacksProvider =
    FutureProvider.autoDispose<TodayStoryCardStacks?>((ref) async {
      ref.watch(storyCardReadRevisionProvider);
      final couple = await ref.watch(coupleControllerProvider.future);
      if (couple == null ||
          !couple.canReadSharedData ||
          !couple.hasRelationshipStartDate) {
        return null;
      }

      final coupleDate = calendarDateOnly(couple.effectiveCurrentDate);
      final relationshipStartDate = calendarDateOnly(
        couple.relationshipStartDate!,
      );
      if (coupleDate.isBefore(relationshipStartDate)) {
        return TodayStoryCardStacks(
          coupleId: couple.id,
          coupleDate: coupleDate,
          accessMode: couple.accessMode,
          canCreateCard: false,
          stacks: const [],
        );
      }

      final stacks = await ref
          .watch(storyCardStackReadRepositoryProvider)
          .fetchTodayStacks();
      return TodayStoryCardStacks(
        coupleId: couple.id,
        coupleDate: coupleDate,
        accessMode: couple.accessMode,
        canCreateCard: couple.canEditSharedData,
        stacks: stacks,
      );
    }, retry: (_, _) => null);

class StoryCardStackRequest {
  const StoryCardStackRequest({required this.date, required this.authorUserId});

  final DateTime date;
  final String authorUserId;

  @override
  bool operator ==(Object other) {
    return other is StoryCardStackRequest &&
        calendarDateOnly(other.date) == calendarDateOnly(date) &&
        other.authorUserId == authorUserId;
  }

  @override
  int get hashCode => Object.hash(calendarDateOnly(date), authorUserId);
}

final storyCardStackProvider = FutureProvider.autoDispose.family((
  ref,
  StoryCardStackRequest request,
) async {
  ref.watch(storyCardReadRevisionProvider);
  return ref
      .watch(storyCardStackReadRepositoryProvider)
      .fetchStack(date: request.date, authorUserId: request.authorUserId);
}, retry: (_, _) => null);
