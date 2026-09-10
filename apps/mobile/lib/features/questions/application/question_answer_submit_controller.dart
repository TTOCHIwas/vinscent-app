import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/date/app_date_policy.dart';
import '../../story_loops/application/story_loop_detail_provider.dart';
import '../../story_loops/application/story_loop_month_summary_provider.dart';
import '../../story_loops/application/today_story_loop_summary_provider.dart';
import '../data/daily_question_answer_failure.dart';
import '../data/daily_question_answer_repository.dart';
import '../data/daily_question_answer_state.dart';
import '../data/question_detail_state.dart';
import 'daily_question_detail_provider.dart';
import 'question_detail_provider.dart';

final questionAnswerSubmitControllerProvider =
    AsyncNotifierProvider<
      QuestionAnswerSubmitController,
      DailyQuestionAnswerState?
    >(QuestionAnswerSubmitController.new, retry: (_, _) => null);

class QuestionAnswerSubmitController
    extends AsyncNotifier<DailyQuestionAnswerState?> {
  @override
  Future<DailyQuestionAnswerState?> build() async {
    return null;
  }

  Future<DailyQuestionAnswerState> submit({
    required DateTime? targetDate,
    required String answerText,
  }) async {
    final previousState = state;
    state = const AsyncValue.loading();

    try {
      final questionState = await ref.read(
        questionDetailProvider(targetDate).future,
      );
      final detail = switch (questionState) {
        LoadedQuestionDetailState() => questionState,
        UnavailableQuestionDetailState() => null,
      };

      if (detail == null || !detail.canEdit) {
        throw const DailyQuestionAnswerRepositoryException(
          DailyQuestionAnswerFailureReason.questionNotReady,
        );
      }

      if (detail.answerState?.hasBothAnswers ?? false) {
        throw const DailyQuestionAnswerRepositoryException(
          DailyQuestionAnswerFailureReason.questionNotReady,
        );
      }

      final answerState = await ref
          .read(dailyQuestionAnswerRepositoryProvider)
          .submitDailyQuestionAnswer(
            dailyQuestionId: detail.question.dailyQuestionId,
            answerText: answerText,
          );

      ref.invalidate(dailyQuestionDetailProvider);
      ref.invalidate(questionDetailProvider);
      ref.invalidate(storyLoopDetailProvider(targetDate));
      ref.invalidate(storyLoopDetailProvider(null));
      ref.invalidate(todayStoryLoopSummaryProvider);
      ref.invalidate(
        storyLoopMonthSummaryProvider(
          calendarMonthOnly(detail.question.assignedDate),
        ),
      );
      state = AsyncValue.data(answerState);
      return answerState;
    } catch (error, stackTrace) {
      state = previousState;
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}
