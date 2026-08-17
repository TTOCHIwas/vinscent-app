import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ai_learning_controller.dart';
import '../data/ai_learning_dashboard.dart';
import '../data/ai_learning_repository.dart';
import '../data/ai_question_feedback_snapshot.dart';

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

final class AiQuestionFeedbackFailed extends AiQuestionFeedbackState {
  const AiQuestionFeedbackFailed();
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
        final snapshot = await repository.fetchQuestionFeedbackStatus(
          dailyQuestionId,
        );

        switch (snapshot) {
          case AiQuestionFeedbackSnapshotPublished(feedback: final feedback):
            yield AiQuestionFeedbackPublished(feedback);
            return;
          case AiQuestionFeedbackSnapshotFailed():
            yield const AiQuestionFeedbackFailed();
            return;
          case AiQuestionFeedbackSnapshotProcessing():
            break;
        }

        if (attempt == _maximumFeedbackPollAttempts - 1) {
          yield const AiQuestionFeedbackFailed();
          return;
        }

        yield attempt >= _delayedFeedbackPollAttempt
            ? const AiQuestionFeedbackDelayed()
            : const AiQuestionFeedbackProcessing();

        await Future<void>.delayed(_feedbackPollInterval);
      }
    });
