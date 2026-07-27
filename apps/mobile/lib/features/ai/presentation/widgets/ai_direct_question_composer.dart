import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/presentation/widgets/app_answer_input.dart';
import '../../../../core/presentation/widgets/word_boundary_text.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../application/ai_direct_question_controller.dart';
import '../../data/ai_direct_question_history.dart';
import '../../data/ai_direct_question_repository.dart';
import '../ai_direct_question_composer_controller.dart';
import 'ai_character_speech_row.dart';
import 'ai_direct_question_entry_view.dart';
import 'ai_learning_error_message.dart';

class AiDirectQuestionComposer extends ConsumerWidget {
  const AiDirectQuestionComposer({super.key, required this.controller});

  final AiDirectQuestionComposerController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(aiDirectQuestionControllerProvider);

    return history.when(
      loading: () => const SizedBox(
        height: 180,
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      error: (error, stackTrace) => _ComposerError(
        message: aiLearningErrorMessage(error),
        onRetry: () => ref.invalidate(aiDirectQuestionControllerProvider),
      ),
      data: (value) => ListenableBuilder(
        listenable: controller,
        builder: (context, child) => _DirectQuestionComposerContent(
          history: value,
          controller: controller,
          onRefresh: () =>
              ref.read(aiDirectQuestionControllerProvider.notifier).refresh(),
          onApproveFollowUp: (questionId) => _decideFollowUp(
            context,
            ref,
            questionId,
            AiDirectQuestionFollowUpDecision.approve,
          ),
          onDismissFollowUp: (questionId) => _decideFollowUp(
            context,
            ref,
            questionId,
            AiDirectQuestionFollowUpDecision.dismiss,
          ),
        ),
      ),
    );
  }

  Future<void> _decideFollowUp(
    BuildContext context,
    WidgetRef ref,
    String questionId,
    AiDirectQuestionFollowUpDecision decision,
  ) async {
    try {
      await ref
          .read(aiDirectQuestionControllerProvider.notifier)
          .decideFollowUp(questionId, decision);
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(aiLearningErrorMessage(error))));
    }
  }
}

class _DirectQuestionComposerContent extends StatelessWidget {
  const _DirectQuestionComposerContent({
    required this.history,
    required this.controller,
    required this.onRefresh,
    required this.onApproveFollowUp,
    required this.onDismissFollowUp,
  });

  final AiDirectQuestionHistory history;
  final AiDirectQuestionComposerController controller;
  final RefreshCallback onRefresh;
  final Future<void> Function(String questionId) onApproveFollowUp;
  final Future<void> Function(String questionId) onDismissFollowUp;

  @override
  Widget build(BuildContext context) {
    final latestQuestion = history.questions.firstOrNull;
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Column(
      key: const Key('ai-direct-question-composer'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return RefreshIndicator(
                color: AppColors.textPrimary,
                onRefresh: onRefresh,
                child: ListView(
                  key: const Key('ai-direct-question-conversation'),
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: (constraints.maxHeight - 40).clamp(
                          0,
                          double.infinity,
                        ),
                      ),
                      child: latestQuestion == null
                          ? const Center(child: _DirectQuestionGuide())
                          : Align(
                              alignment: Alignment.topCenter,
                              child: AiDirectQuestionExchange(
                                entry: latestQuestion,
                                questionBubbleKey: const Key(
                                  'ai-direct-latest-question-bubble',
                                ),
                                isLatest: true,
                                usePrimaryAnswerLayout: true,
                                onApproveFollowUp: onApproveFollowUp,
                                onDismissFollowUp: onDismissFollowUp,
                              ),
                            ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        ColoredBox(
          color: AppColors.background,
          child: Padding(
            key: const Key('ai-direct-question-input-dock'),
            padding: EdgeInsets.fromLTRB(24, 8, 24, keyboardVisible ? 8 : 104),
            child: AppAnswerInput(
              key: const Key('ai-direct-question-input'),
              controller: controller.questionController,
              focusNode: controller.focusNode,
              enabled: !controller.isSubmitting && history.remainingCount > 0,
              minLines: 3,
              maxLines: 5,
              maxLength: AiDirectQuestionComposerController.maxQuestionLength,
              hintText: history.remainingCount > 0
                  ? '예: 상대는 지친 날에 어떤 걸 좋아할까?'
                  : '오늘 질문은 모두 사용했어',
            ),
          ),
        ),
      ],
    );
  }
}

class _DirectQuestionGuide extends StatelessWidget {
  const _DirectQuestionGuide();

  @override
  Widget build(BuildContext context) {
    return const AiCharacterSpeechColumn(
      characterKey: Key('ai-direct-guide-character'),
      bubbleKey: Key('ai-direct-guide-prompt'),
      characterSize: 156,
      speechText: '우리 둘에 관해 궁금한 걸 물어봐',
      textAlign: TextAlign.center,
    );
  }
}

class _ComposerError extends StatelessWidget {
  const _ComposerError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Row(
        children: [
          Expanded(
            child: WordBoundaryText(message, style: AppTextStyles.homeBody),
          ),
          IconButton(
            tooltip: '다시 시도',
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }
}
