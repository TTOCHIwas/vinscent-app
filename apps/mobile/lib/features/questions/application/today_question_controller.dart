import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/date/today_controller.dart';
import '../../couple/application/couple_controller.dart';
import '../../couple/data/couple.dart';
import '../data/daily_question.dart';
import '../data/daily_question_repository.dart';

final todayQuestionControllerProvider =
    AsyncNotifierProvider<TodayQuestionController, DailyQuestion?>(
      TodayQuestionController.new,
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
    if (watchDependencies) {
      ref.watch(todayControllerProvider);
    } else {
      ref.read(todayControllerProvider);
    }

    final couple = watchDependencies
        ? await ref.watch(coupleControllerProvider.future)
        : await ref.read(coupleControllerProvider.future);

    if (couple == null ||
        couple.status != CoupleStatus.active ||
        couple.relationshipStartDate == null) {
      return null;
    }

    final repository = watchDependencies
        ? ref.watch(dailyQuestionRepositoryProvider)
        : ref.read(dailyQuestionRepositoryProvider);

    return repository.fetchTodayQuestion();
  }
}
