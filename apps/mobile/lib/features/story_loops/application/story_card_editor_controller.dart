import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/date/app_date_policy.dart';
import '../../couple/application/couple_controller.dart';
import '../../profile/application/profile_controller.dart';
import '../../questions/application/daily_question_detail_provider.dart';
import '../data/story_loop_card_save_result.dart';
import 'story_loop_detail_provider.dart';
import 'story_loop_month_summary_provider.dart';
import 'today_story_card_stacks_provider.dart';
import 'today_story_loop_summary_provider.dart';
import '../data/story_card_draft.dart';
import '../data/story_card_scene.dart';
import '../data/story_card_type.dart';
import '../data/story_loop_write_failure.dart';
import '../data/story_loop_write_repository.dart';

final storyCardEditorControllerProvider =
    AsyncNotifierProvider.autoDispose<
      StoryCardEditorController,
      StoryCardDraft
    >(StoryCardEditorController.new);

class StoryCardEditorController extends AsyncNotifier<StoryCardDraft> {
  @override
  Future<StoryCardDraft> build() async {
    return _emptyDraft();
  }

  Future<StoryLoopCardSaveResult> save({
    required StoryCardDraft draft,
    required Uint8List previewImageBytes,
  }) async {
    final couple = await ref.read(coupleControllerProvider.future);
    final profile = await ref.read(profileControllerProvider.future);
    if (couple == null || !couple.canEditSharedData || profile == null) {
      throw const StoryLoopWriteRepositoryException(
        StoryLoopWriteFailureReason.activeCoupleRequired,
      );
    }

    final result = await ref
        .read(storyLoopWriteRepositoryProvider)
        .saveTodayCard(
          coupleId: couple.id,
          coupleDate: couple.effectiveCurrentDate,
          userId: profile.id,
          draft: draft,
          previewImageBytes: previewImageBytes,
        );

    _invalidateReadState(couple.effectiveCurrentDate);
    return result;
  }

  StoryCardDraft _emptyDraft() {
    return StoryCardDraft(
      scene: StoryCardScene.empty(cardType: StoryCardType.fullBleed),
    );
  }

  void _invalidateReadState(DateTime coupleDate) {
    ref.invalidate(todayStoryLoopSummaryProvider);
    ref.invalidate(todayStoryCardStacksProvider);
    ref.invalidate(todayDailyQuestionProvider);
    ref.invalidate(storyLoopDetailProvider(null));
    ref.invalidate(storyLoopDetailProvider(coupleDate));
    ref.invalidate(
      storyLoopMonthSummaryProvider(calendarMonthOnly(coupleDate)),
    );
  }
}
