import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/presentation/widgets/app_keyboard_accessory.dart';
import '../../../../core/presentation/widgets/app_loading_indicator.dart';
import '../../../../core/presentation/widgets/word_boundary_text.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../application/ai_direct_question_controller.dart';
import '../../data/ai_direct_question_history.dart';
import '../../data/ai_direct_question_repository.dart';
import '../ai_direct_question_composer_controller.dart';
import '../../../characters/presentation/widgets/couple_character_avatar.dart';
import '../../../shell/presentation/app_shell.dart';
import 'ai_direct_question_entry_view.dart';
import 'ai_direct_question_input_dock.dart';
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
        child: Center(child: AppLoadingIndicator(strokeWidth: 2)),
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
    final keyboardVisible = AppKeyboardVisibility.of(context);
    final bottomNavigationClearance =
        AppShell.bottomBarHeight + MediaQuery.viewPaddingOf(context).bottom;

    return LayoutBuilder(
      builder: (context, constraints) {
        final guideCharacterSize = _guideCharacterSizeFor(
          constraints.maxHeight,
        );
        final answerCharacterSize = _answerCharacterSizeFor(
          constraints.maxHeight,
        );

        return TextFieldTapRegion(
          child: Column(
            key: const Key('ai-direct-question-composer'),
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, conversationConstraints) {
                    return RefreshIndicator(
                      color: AppColors.textMuted,
                      onRefresh: onRefresh,
                      child: ListView(
                        key: const Key('ai-direct-question-conversation'),
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.manual,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.zero,
                        children: [
                          GestureDetector(
                            key: const Key('ai-direct-question-content'),
                            behavior: HitTestBehavior.translucent,
                            onTap: controller.focusNode.unfocus,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: conversationConstraints.maxHeight,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  24,
                                  16,
                                  24,
                                  24,
                                ),
                                child: latestQuestion == null
                                    ? Center(
                                        child: _DirectQuestionGuide(
                                          characterSize: guideCharacterSize,
                                          canAsk: history.remainingCount > 0,
                                          onSuggestionPressed:
                                              controller.useStarterQuestion,
                                        ),
                                      )
                                    : Align(
                                        alignment: Alignment.topCenter,
                                        child: AiDirectQuestionExchange(
                                          entry: latestQuestion,
                                          questionBubbleKey: const Key(
                                            'ai-direct-latest-question-bubble',
                                          ),
                                          isLatest: true,
                                          usePrimaryAnswerLayout: true,
                                          primaryCharacterSize:
                                              answerCharacterSize,
                                          onApproveFollowUp: onApproveFollowUp,
                                          onDismissFollowUp: onDismissFollowUp,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              AiDirectQuestionInputDock(
                controller: controller,
                remainingCount: history.remainingCount,
                keyboardVisible: keyboardVisible,
                bottomNavigationClearance: bottomNavigationClearance,
              ),
            ],
          ),
        );
      },
    );
  }

  double _guideCharacterSizeFor(double availableHeight) {
    return (availableHeight * 0.36).clamp(132.0, 220.0).toDouble();
  }

  double _answerCharacterSizeFor(double availableHeight) {
    return (availableHeight * 0.2).clamp(96.0, 120.0).toDouble();
  }
}

class _DirectQuestionGuide extends StatelessWidget {
  const _DirectQuestionGuide({
    required this.characterSize,
    required this.canAsk,
    required this.onSuggestionPressed,
  });

  final double characterSize;
  final bool canAsk;
  final ValueChanged<String> onSuggestionPressed;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CoupleCharacterAvatar(
            key: const Key('ai-direct-guide-character'),
            size: characterSize,
          ),
          const SizedBox(height: 12),
          WordBoundaryText(
            canAsk ? '우리 둘에 관해 궁금한 걸 물어봐' : '오늘은 여기까지 물어봤어',
            key: const Key('ai-direct-guide-prompt'),
            textAlign: TextAlign.center,
            style: AppTextStyles.homeQuestionBubble,
          ),
          if (canAsk) ...[
            const SizedBox(height: 22),
            _StarterQuestionOption(
              optionKey: const Key('ai-direct-suggestion-partner-rest'),
              question: '상대는 지친 날에 어떤 걸 좋아할까?',
              onPressed: onSuggestionPressed,
            ),
            const SizedBox(height: 8),
            _StarterQuestionOption(
              optionKey: const Key('ai-direct-suggestion-weekend'),
              question: '우리 둘에게 잘 맞는 주말은 어떤 모습일까?',
              onPressed: onSuggestionPressed,
            ),
          ],
        ],
      ),
    );
  }
}

class _StarterQuestionOption extends StatelessWidget {
  const _StarterQuestionOption({
    required this.optionKey,
    required this.question,
    required this.onPressed,
  });

  final Key optionKey;
  final String question;
  final ValueChanged<String> onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: optionKey,
      color: AppColors.formSurface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () => onPressed(question),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: WordBoundaryText(
                  question,
                  style: AppTextStyles.homeBodyMedium,
                ),
              ),
              const SizedBox(width: 12),
              const Icon(
                Icons.arrow_forward_rounded,
                size: 20,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
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
