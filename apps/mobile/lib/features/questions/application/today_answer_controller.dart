import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/daily_question_answer_repository.dart';
import '../data/daily_question_answer_state.dart';
import 'today_question_controller.dart';

final todayAnswerControllerProvider =
    AsyncNotifierProvider<TodayAnswerController, DailyQuestionAnswerState?>(
      TodayAnswerController.new,
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

  Future<void> submit(String answerText) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final question = await ref.read(todayQuestionControllerProvider.future);
      if (question == null) {
        return null;
      }

      final repository = ref.read(dailyQuestionAnswerRepositoryProvider);
      final answerState = await repository.submitTodayAnswer(answerText);
      ref.invalidate(todayQuestionControllerProvider);

      return answerState;
    });
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
