import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/ai_learning_dashboard.dart';
import '../data/ai_learning_repository.dart';

const _feedbackPollInterval = Duration(seconds: 10);
const _maximumFeedbackPollAttempts = 36;

final aiQuestionFeedbackProvider = StreamProvider.autoDispose
    .family<AiQuestionFeedback?, String>((ref, dailyQuestionId) async* {
      final repository = ref.watch(aiLearningRepositoryProvider);

      for (var attempt = 0; attempt < _maximumFeedbackPollAttempts; attempt++) {
        final feedback = await repository.fetchQuestionFeedback(
          dailyQuestionId,
        );
        yield feedback;

        if (feedback != null || attempt == _maximumFeedbackPollAttempts - 1) {
          return;
        }

        await Future<void>.delayed(_feedbackPollInterval);
      }
    });
