import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/daily_question_answer_repository.dart';
import '../data/daily_question_answer_state.dart';
import 'today_question_controller.dart';

final todayAnswerControllerProvider =
    AsyncNotifierProvider<TodayAnswerController, DailyQuestionAnswerState?>(
      TodayAnswerController.new,
      retry: (_, _) => null,
    );

class TodayAnswerController extends AsyncNotifier<DailyQuestionAnswerState?> {
  @override
  Future<DailyQuestionAnswerState?> build() {
    return _load(watchDependencies: true);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _load(watchDependencies: false));
  }

  Future<DailyQuestionAnswerState?> submit(String answerText) async {
    final previousState = state;

    try {
      final question = await ref.read(todayQuestionControllerProvider.future);
      if (question == null) {
        return null;
      }

      final repository = ref.read(dailyQuestionAnswerRepositoryProvider);
      final answerState = await repository.submitTodayAnswer(answerText);
      state = AsyncValue.data(answerState);
      ref.invalidate(todayQuestionControllerProvider);

      return answerState;
    } catch (error, stackTrace) {
      state = previousState;
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<DailyQuestionAnswerState?> _load({
    required bool watchDependencies,
  }) async {
    final question = watchDependencies
        ? await ref.watch(todayQuestionControllerProvider.future)
        : await ref.read(todayQuestionControllerProvider.future);

    if (question == null) {
      return null;
    }

    final repository = watchDependencies
        ? ref.watch(dailyQuestionAnswerRepositoryProvider)
        : ref.read(dailyQuestionAnswerRepositoryProvider);

    return repository.fetchTodayAnswerState();
  }
}
