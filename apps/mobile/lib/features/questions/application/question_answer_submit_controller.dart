import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../story_loops/application/story_loop_detail_provider.dart';
import '../../story_loops/application/story_loop_month_summary_provider.dart';
import '../../story_loops/application/today_story_loop_summary_provider.dart';
import '../../story_loops/data/story_loop_detail_state.dart';
import '../data/daily_question_answer_failure.dart';
import '../data/daily_question_answer_repository.dart';
import '../data/daily_question_answer_state.dart';

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
      final detailState = await ref.read(
        storyLoopDetailProvider(targetDate).future,
      );
      final detail = switch (detailState) {
        LoadedStoryLoopDetailState(:final detail) => detail,
        _ => null,
      };

      if (detail == null || !detail.canAnswerQuestion) {
        throw const DailyQuestionAnswerRepositoryException(
          DailyQuestionAnswerFailureReason.questionNotReady,
        );
      }

      final question = detail.question;
      if (question == null) {
        throw const DailyQuestionAnswerRepositoryException(
          DailyQuestionAnswerFailureReason.questionNotReady,
        );
      }

      final answerState = await ref
          .read(dailyQuestionAnswerRepositoryProvider)
          .submitStoryLoopAnswer(
            dailyQuestionId: question.question.dailyQuestionId,
            answerText: answerText,
          );

      ref.invalidate(storyLoopDetailProvider(targetDate));
      ref.invalidate(storyLoopDetailProvider(null));
      ref.invalidate(todayStoryLoopSummaryProvider);
      ref.invalidate(
        storyLoopMonthSummaryProvider(
          DateTime(detail.coupleDate.year, detail.coupleDate.month),
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
