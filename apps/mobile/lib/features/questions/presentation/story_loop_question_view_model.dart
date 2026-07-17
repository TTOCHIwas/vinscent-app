import '../../story_loops/data/story_loop_detail_state.dart';
import '../data/question_detail_state.dart';

QuestionDetailState toQuestionDetailState(StoryLoopDetailState state) {
  return switch (state) {
    LoadedStoryLoopDetailState(
      targetDate: final targetDate,
      detail: final detail,
    ) =>
      detail.question == null
          ? UnavailableQuestionDetailState(
              reason: QuestionDetailUnavailableReason.noQuestion,
              targetDate: targetDate,
            )
          : LoadedQuestionDetailState(
              question: detail.question!.question,
              answerState: detail.question!.answerState,
              canEdit:
                  detail.canAnswerQuestion &&
                  !detail.question!.answerState.hasBothAnswers,
            ),
    EmptyStoryLoopDetailState(targetDate: final targetDate) =>
      UnavailableQuestionDetailState(
        reason: QuestionDetailUnavailableReason.noQuestion,
        targetDate: targetDate,
      ),
    UnavailableStoryLoopDetailState(
      targetDate: final targetDate,
      reason: final reason,
    ) =>
      UnavailableQuestionDetailState(
        reason: _mapUnavailableReason(reason),
        targetDate: targetDate,
      ),
  };
}

QuestionDetailUnavailableReason _mapUnavailableReason(
  StoryLoopDetailUnavailableReason reason,
) {
  return switch (reason) {
    StoryLoopDetailUnavailableReason.unavailable =>
      QuestionDetailUnavailableReason.unavailable,
    StoryLoopDetailUnavailableReason.beforeRelationshipStartDate =>
      QuestionDetailUnavailableReason.beforeRelationshipStartDate,
    StoryLoopDetailUnavailableReason.futureDate =>
      QuestionDetailUnavailableReason.futureDate,
  };
}
