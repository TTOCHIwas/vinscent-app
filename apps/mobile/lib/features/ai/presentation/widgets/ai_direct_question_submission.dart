import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/ai_direct_question_controller.dart';
import '../ai_direct_question_composer_controller.dart';
import 'ai_learning_error_message.dart';

Future<void> submitAiDirectQuestion({
  required BuildContext context,
  required WidgetRef ref,
  required AiDirectQuestionComposerController controller,
}) async {
  if (controller.isSubmitting || !controller.hasValidQuestion) {
    return;
  }

  controller.setSubmitting(true);
  try {
    await ref
        .read(aiDirectQuestionControllerProvider.notifier)
        .submitQuestion(controller.normalizedQuestion);
    controller.completeSubmission();
  } catch (error) {
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(aiLearningErrorMessage(error))));
  } finally {
    controller.setSubmitting(false);
  }
}
