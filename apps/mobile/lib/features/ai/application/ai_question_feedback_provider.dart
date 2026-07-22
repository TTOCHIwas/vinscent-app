import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ai_learning_controller.dart';
import '../data/ai_learning_dashboard.dart';
import '../data/ai_learning_repository.dart';

const _feedbackPollInterval = Duration(seconds: 10);
const _maximumFeedbackPollAttempts = 36;
const _delayedFeedbackPollAttempt = 12;

sealed class AiQuestionFeedbackState {
  const AiQuestionFeedbackState();
}

final class AiQuestionFeedbackDisabled extends AiQuestionFeedbackState {
  const AiQuestionFeedbackDisabled();
}

final class AiQuestionFeedbackProcessing extends AiQuestionFeedbackState {
  const AiQuestionFeedbackProcessing();
}

final class AiQuestionFeedbackDelayed extends AiQuestionFeedbackState {
  const AiQuestionFeedbackDelayed();
}

final class AiQuestionFeedbackPublished extends AiQuestionFeedbackState {
  const AiQuestionFeedbackPublished(this.feedback);

  final AiQuestionFeedback feedback;
}

final aiQuestionFeedbackProvider = StreamProvider.autoDispose
    .family<AiQuestionFeedbackState, String>((ref, dailyQuestionId) async* {
      final repository = ref.watch(aiLearningRepositoryProvider);
      final dashboard = await ref.watch(aiLearningControllerProvider.future);

      if (!dashboard.progress.isEnabled) {
        yield const AiQuestionFeedbackDisabled();
        return;
      }

      for (var attempt = 0; attempt < _maximumFeedbackPollAttempts; attempt++) {
        final feedback = await repository.fetchQuestionFeedback(
          dailyQuestionId,
        );

        if (feedback != null) {
          yield AiQuestionFeedbackPublished(feedback);
          return;
        }

        yield attempt >= _delayedFeedbackPollAttempt
            ? const AiQuestionFeedbackDelayed()
            : const AiQuestionFeedbackProcessing();

        if (attempt == _maximumFeedbackPollAttempts - 1) {
          return;
        }

        await Future<void>.delayed(_feedbackPollInterval);
      }
    });
