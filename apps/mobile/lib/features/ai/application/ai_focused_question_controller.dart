import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/ai_focused_question_flow.dart';
import '../data/ai_focused_question_history_entry.dart';
import '../data/ai_learning_repository.dart';

final aiFocusedQuestionControllerProvider =
    AsyncNotifierProvider.autoDispose<
      AiFocusedQuestionController,
      AiFocusedQuestionFlow
    >(AiFocusedQuestionController.new, retry: (_, _) => null);

final aiFocusedQuestionHistoryProvider =
    FutureProvider.autoDispose<List<AiFocusedQuestionHistoryEntry>>((ref) {
      return ref
          .read(aiLearningRepositoryProvider)
          .fetchFocusedQuestionHistory();
    }, retry: (_, _) => null);

class AiFocusedQuestionController extends AsyncNotifier<AiFocusedQuestionFlow> {
  @override
  Future<AiFocusedQuestionFlow> build() {
    return ref.read(aiLearningRepositoryProvider).fetchFocusedQuestionFlow();
  }

  Future<void> refresh() async {
    final flow = await ref
        .read(aiLearningRepositoryProvider)
        .fetchFocusedQuestionFlow();
    state = AsyncValue.data(flow);
  }

  Future<void> submitAnswer({
    required String questionId,
    required String answerText,
  }) async {
    final previousState = state;

    try {
      final flow = await ref
          .read(aiLearningRepositoryProvider)
          .submitFocusedQuestionAnswer(
            questionId: questionId,
            answerText: answerText,
          );
      state = AsyncValue.data(flow);
      ref.invalidate(aiFocusedQuestionHistoryProvider);
    } catch (error, stackTrace) {
      state = previousState;
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}
