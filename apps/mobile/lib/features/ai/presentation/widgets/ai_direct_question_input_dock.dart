import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/presentation/widgets/app_answer_input.dart';
import '../../../../core/theme/app_colors.dart';
import '../ai_direct_question_composer_controller.dart';
import 'ai_direct_question_submission.dart';

class AiDirectQuestionInputDock extends ConsumerWidget {
  const AiDirectQuestionInputDock({
    super.key,
    required this.controller,
    required this.remainingCount,
    required this.keyboardVisible,
    required this.bottomNavigationClearance,
  });

  final AiDirectQuestionComposerController controller;
  final int remainingCount;
  final bool keyboardVisible;
  final double bottomNavigationClearance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canAsk = remainingCount > 0;
    final canSubmit =
        canAsk && !controller.isSubmitting && controller.hasValidQuestion;

    return ColoredBox(
      color: AppColors.background,
      child: Padding(
        key: const Key('ai-direct-question-input-dock'),
        padding: EdgeInsets.fromLTRB(
          24,
          8,
          24,
          keyboardVisible ? 8 : 14 + bottomNavigationClearance,
        ),
        child: TextFieldTapRegion(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: AppAnswerInput(
                  key: const Key('ai-direct-question-input'),
                  controller: controller.questionController,
                  focusNode: controller.focusNode,
                  enabled: canAsk && !controller.isSubmitting,
                  minLines: 1,
                  maxLines: keyboardVisible ? 3 : 2,
                  maxLength:
                      AiDirectQuestionComposerController.maxQuestionLength,
                  hintText: canAsk ? '우리 둘에 관해 궁금한 걸 물어봐' : '오늘 질문은 모두 사용했어',
                ),
              ),
              if (!keyboardVisible) ...[
                const SizedBox(width: 10),
                _InlineSubmitAction(
                  enabled: canSubmit,
                  isLoading: controller.isSubmitting,
                  onPressed: () => submitAiDirectQuestion(
                    context: context,
                    ref: ref,
                    controller: controller,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineSubmitAction extends StatelessWidget {
  const _InlineSubmitAction({
    required this.enabled,
    required this.isLoading,
    required this.onPressed,
  });

  final bool enabled;
  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = enabled || isLoading
        ? AppColors.brandAction
        : AppColors.actionDisabled;
    final contentColor = enabled || isLoading
        ? AppColors.onBrandAction
        : AppColors.actionDisabledContent;

    return Semantics(
      button: true,
      enabled: enabled,
      label: isLoading ? '질문 보내는 중' : '물어보기',
      excludeSemantics: true,
      child: IconButton(
        key: const Key('ai-direct-inline-submit'),
        tooltip: '물어보기',
        onPressed: enabled && !isLoading ? onPressed : null,
        style:
            IconButton.styleFrom(
              minimumSize: const Size.square(52),
              maximumSize: const Size.square(52),
              backgroundColor: backgroundColor,
              foregroundColor: contentColor,
              disabledBackgroundColor: backgroundColor,
              disabledForegroundColor: contentColor,
              shape: const CircleBorder(),
            ).copyWith(
              overlayColor: const WidgetStatePropertyAll(
                AppColors.brandPressed,
              ),
            ),
        icon: isLoading
            ? SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(
                  color: contentColor,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.arrow_upward_rounded, size: 24),
      ),
    );
  }
}
