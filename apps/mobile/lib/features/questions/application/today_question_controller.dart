import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../couple/application/couple_controller.dart';
import '../data/daily_question.dart';
import '../data/daily_question_repository.dart';

final todayQuestionControllerProvider =
    AsyncNotifierProvider<TodayQuestionController, DailyQuestion?>(
      TodayQuestionController.new,
      retry: (_, _) => null,
    );

class TodayQuestionController extends AsyncNotifier<DailyQuestion?> {
  @override
  Future<DailyQuestion?> build() {
    return _load(watchDependencies: true);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _load(watchDependencies: false));
  }

  Future<DailyQuestion?> _load({required bool watchDependencies}) async {
    final couple = watchDependencies
        ? await ref.watch(coupleControllerProvider.future)
        : await ref.read(coupleControllerProvider.future);

    if (couple == null ||
        !couple.canEditSharedData ||
        !couple.hasRelationshipStartDate) {
      return null;
    }

    final repository = watchDependencies
        ? ref.watch(dailyQuestionRepositoryProvider)
        : ref.read(dailyQuestionRepositoryProvider);

    return repository.fetchTodayQuestion();
  }
}
