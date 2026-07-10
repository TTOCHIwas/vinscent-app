import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../couple/application/couple_controller.dart';
import '../../profile/application/profile_controller.dart';
import 'story_loop_detail_provider.dart';
import 'story_loop_month_summary_provider.dart';
import 'today_story_loop_summary_provider.dart';
import '../data/editable_story_loop_card.dart';
import '../data/story_card_draft.dart';
import '../data/story_card_scene.dart';
import '../data/story_loop_write_failure.dart';
import '../data/story_loop_write_repository.dart';

final storyCardEditorControllerProvider = AsyncNotifierProvider.autoDispose<
  StoryCardEditorController,
  StoryCardDraft
>(StoryCardEditorController.new);

class StoryCardEditorController extends AsyncNotifier<StoryCardDraft> {
  @override
  Future<StoryCardDraft> build() async {
    final editableCard = await ref
        .watch(storyLoopWriteRepositoryProvider)
        .fetchEditableTodayCard();

    return _draftFromEditableCard(editableCard);
  }

  void updateDraft(StoryCardDraft draft) {
    state = AsyncValue.data(draft);
  }

  Future<StoryLoopCardSaveResult> save(Uint8List previewImageBytes) async {
    final draft = _currentDraft;
    if (draft == null) {
      throw const StoryLoopWriteRepositoryException(
        StoryLoopWriteFailureReason.unknown,
      );
    }

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

  Future<void> delete() async {
    final draft = _currentDraft;
    final expectedRevision = draft?.existingRevision;
    if (expectedRevision == null) {
      throw const StoryLoopWriteRepositoryException(
        StoryLoopWriteFailureReason.cardNotFound,
      );
    }

    final couple = await ref.read(coupleControllerProvider.future);
    if (couple == null || !couple.canEditSharedData) {
      throw const StoryLoopWriteRepositoryException(
        StoryLoopWriteFailureReason.activeCoupleRequired,
      );
    }

    await ref
        .read(storyLoopWriteRepositoryProvider)
        .deleteTodayCard(expectedRevision: expectedRevision);
    state = AsyncValue.data(_emptyDraft());
    _invalidateReadState(couple.effectiveCurrentDate);
  }

  StoryCardDraft _draftFromEditableCard(EditableStoryLoopCard? card) {
    if (card == null) {
      return _emptyDraft();
    }

    return StoryCardDraft(
      scene: card.scene,
      backgroundImageBytes: card.backgroundImageBytes,
      existingRevision: card.revision,
    );
  }

  StoryCardDraft _emptyDraft() {
    return StoryCardDraft(scene: StoryCardScene.empty());
  }

  StoryCardDraft? get _currentDraft {
    return switch (state) {
      AsyncData<StoryCardDraft>(:final value) => value,
      _ => null,
    };
  }

  void _invalidateReadState(DateTime coupleDate) {
    ref.invalidate(todayStoryLoopSummaryProvider);
    ref.invalidate(storyLoopDetailProvider(null));
    ref.invalidate(storyLoopDetailProvider(coupleDate));
    ref.invalidate(
      storyLoopMonthSummaryProvider(DateTime(coupleDate.year, coupleDate.month)),
    );
  }
}
