import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/presentation/widgets/app_keyboard_accessory.dart';
import '../../../../core/presentation/widgets/app_action_tone.dart';
import '../../application/ai_direct_question_controller.dart';
import '../ai_direct_question_composer_controller.dart';
import 'ai_direct_question_submission.dart';

class AiDirectQuestionKeyboardAccessory extends ConsumerWidget {
  const AiDirectQuestionKeyboardAccessory({
    super.key,
    required this.controller,
  });

  final AiDirectQuestionComposerController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(aiDirectQuestionControllerProvider);

    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        final remainingCount = history.value?.remainingCount ?? 0;
        final canSubmit =
            !controller.isSubmitting &&
            remainingCount > 0 &&
            controller.hasValidQuestion;

        return AppTextInputKeyboardAccessory(
          key: const Key('ai-direct-keyboard-accessory'),
          characterCountKey: const Key('ai-direct-character-count'),
          characterCount: controller.characterCount,
          maxLength: AiDirectQuestionComposerController.maxQuestionLength,
          actionKey: const Key('ai-direct-submit'),
          actionLabel: '물어보기',
          loadingLabel: '질문 보내는 중',
          actionIcon: const Icon(Icons.arrow_upward_rounded, size: 24),
          actionTone: AppActionTone.brand,
          enabled: canSubmit,
          isLoading: controller.isSubmitting,
          horizontalPadding: 24,
          onPressed: () => submitAiDirectQuestion(
            context: context,
            ref: ref,
            controller: controller,
          ),
        );
      },
    );
  }
}
