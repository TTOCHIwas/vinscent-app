import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/ai_learning_dashboard.dart';
import '../data/ai_learning_repository.dart';

final aiLearningControllerProvider =
    AsyncNotifierProvider.autoDispose<
      AiLearningController,
      AiLearningDashboard
    >(AiLearningController.new, retry: (_, _) => null);

class AiLearningController extends AsyncNotifier<AiLearningDashboard> {
  @override
  Future<AiLearningDashboard> build() {
    return ref.read(aiLearningRepositoryProvider).fetchDashboard();
  }

  Future<void> refresh() async {
    await _runAndReload(() async {});
  }

  Future<void> setConsent({required bool granted}) async {
    await _runAndReload(() {
      return ref
          .read(aiLearningRepositoryProvider)
          .setMyConsent(granted: granted);
    });
  }

  Future<void> confirmMemory({
    required String memoryId,
    required AiMemoryDecision decision,
  }) async {
    await _runAndReload(() {
      return ref
          .read(aiLearningRepositoryProvider)
          .confirmMemory(memoryId: memoryId, decision: decision);
    });
  }

  Future<void> _runAndReload(Future<void> Function() command) async {
    final previousState = state;
    state = const AsyncValue.loading();

    try {
      await command();
      final dashboard = await ref
          .read(aiLearningRepositoryProvider)
          .fetchDashboard();
      state = AsyncValue.data(dashboard);
    } catch (error, stackTrace) {
      state = previousState;
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}
