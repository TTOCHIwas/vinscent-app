import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/presentation/widgets/app_answer_input.dart';
import '../../../core/presentation/widgets/app_header_text_action.dart';
import '../../../core/presentation/widgets/word_boundary_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../settings/presentation/widgets/settings_page_layout.dart';
import '../application/ai_focused_question_controller.dart';
import '../application/ai_learning_controller.dart';
import '../data/ai_focused_question_flow.dart';
import '../data/ai_focused_question_history_entry.dart';
import 'widgets/ai_focused_question_history_section.dart';
import 'widgets/ai_learning_error_message.dart';

class AiFocusedQuestionScreen extends ConsumerStatefulWidget {
  const AiFocusedQuestionScreen({super.key});

  @override
  ConsumerState<AiFocusedQuestionScreen> createState() =>
      _AiFocusedQuestionScreenState();
}

class _AiFocusedQuestionScreenState
    extends ConsumerState<AiFocusedQuestionScreen> {
  final _answerController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _answerController.addListener(_onAnswerChanged);
  }

  @override
  void dispose() {
    _answerController
      ..removeListener(_onAnswerChanged)
      ..dispose();
    super.dispose();
  }

  void _onAnswerChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final flow = ref.watch(aiFocusedQuestionControllerProvider);
    final history = ref.watch(aiFocusedQuestionHistoryProvider);

    return SettingsPageLayout(
      title: '집중 질문',
      action: _buildHeaderAction(flow),
      onBackPressed: () {
        ref.invalidate(aiLearningControllerProvider);
        if (context.canPop()) {
          context.pop();
          return;
        }
        context.go('/ai');
      },
      child: flow.when(
        loading: () => const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.textPrimary,
          ),
        ),
        error: (error, stackTrace) => _FocusedQuestionError(
          message: aiLearningErrorMessage(error),
          onRetry: () => ref.invalidate(aiFocusedQuestionControllerProvider),
        ),
        data: (flow) => _buildFlow(flow, history),
      ),
    );
  }

  Widget? _buildHeaderAction(AsyncValue<AiFocusedQuestionFlow> flow) {
    final value = flow.asData?.value;
    final question = value?.status == AiFocusedQuestionStatus.answering
        ? value?.question
        : null;
    if (question == null) {
      return null;
    }

    final normalizedAnswer = _answerController.text.trim();
    final characterCount = _answerController.text.characters.length;
    final canSubmit =
        !_isSubmitting && normalizedAnswer.isNotEmpty && characterCount <= 500;

    return AppHeaderTextAction(
      key: const Key('ai-focused-submit'),
      label: '다음',
      loadingLabel: '처리 중',
      enabled: canSubmit,
      isLoading: _isSubmitting,
      onPressed: () =>
          _submitAnswer(questionId: question.id, answerText: normalizedAnswer),
    );
  }

  Widget _buildFlow(
    AiFocusedQuestionFlow flow,
    AsyncValue<List<AiFocusedQuestionHistoryEntry>> history,
  ) {
    return switch (flow.status) {
      AiFocusedQuestionStatus.answering => _buildQuestion(flow, history),
      AiFocusedQuestionStatus.waitingPartner => _FocusedQuestionStatusView(
        icon: Icons.hourglass_top_rounded,
        title: '내 질문은 모두 답했어',
        message: '상대방이 남은 질문에 답하면 함께 완료돼',
        progress: flow.progress,
        history: history,
      ),
      AiFocusedQuestionStatus.completed => _FocusedQuestionStatusView(
        icon: Icons.check_circle_outline_rounded,
        title: '24개의 질문을 모두 완료했어',
        message: '둘의 답변을 정리하고 있어',
        progress: flow.progress,
        history: history,
      ),
    };
  }

  Widget _buildQuestion(
    AiFocusedQuestionFlow flow,
    AsyncValue<List<AiFocusedQuestionHistoryEntry>> history,
  ) {
    final question = flow.question!;
    final characterCount = _answerController.text.characters.length;
    final keyboardVisible = View.of(context).viewInsets.bottom > 0;

    final content = ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.only(bottom: keyboardVisible ? 48 : 32),
      children: [
        _FocusedQuestionProgressView(progress: flow.progress),
        const SizedBox(height: 44),
        WordBoundaryText(
          question.text,
          key: const Key('ai-focused-question-text'),
          style: AppTextStyles.homeQuestionBubble.copyWith(
            fontSize: 24,
            height: 1.5,
          ),
        ),
        if (question.partnerAnswered) ...[
          const SizedBox(height: 16),
          Text(
            '상대방은 이미 답했어. 네 답을 남기면 함께 완료돼',
            style: AppTextStyles.homeBody.copyWith(color: AppColors.textMuted),
          ),
        ],
        const SizedBox(height: 32),
        AppAnswerInput(
          key: const Key('ai-focused-answer-input'),
          controller: _answerController,
          enabled: !_isSubmitting,
          minLines: 5,
          maxLines: 8,
          maxLength: 500,
        ),
        if (!keyboardVisible)
          AppAnswerCharacterCount(
            key: const Key('ai-focused-character-count'),
            characterCount: characterCount,
            maxLength: 500,
          ),
        _FocusedQuestionHistory(history: history),
      ],
    );

    return Stack(
      children: [
        Positioned.fill(child: content),
        if (keyboardVisible)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ColoredBox(
              color: AppColors.background,
              child: AppAnswerCharacterCount(
                key: const Key('ai-focused-character-count'),
                characterCount: characterCount,
                maxLength: 500,
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _submitAnswer({
    required String questionId,
    required String answerText,
  }) async {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _isSubmitting = true;
    });

    try {
      await ref
          .read(aiFocusedQuestionControllerProvider.notifier)
          .submitAnswer(questionId: questionId, answerText: answerText);
      _answerController.clear();
      ref.invalidate(aiLearningControllerProvider);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(aiLearningErrorMessage(error))));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
}

class _FocusedQuestionProgressView extends StatelessWidget {
  const _FocusedQuestionProgressView({required this.progress});

  final AiFocusedQuestionProgress progress;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: WordBoundaryText(
                '내 답변 ${progress.myAnsweredCount} / ${progress.totalCount}',
                key: const Key('ai-focused-my-progress'),
                style: AppTextStyles.homeBodyMedium,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: WordBoundaryText(
                '함께 완료 ${progress.coupleCompletedCount} / ${progress.totalCount}',
                key: const Key('ai-focused-couple-progress'),
                textAlign: TextAlign.right,
                style: AppTextStyles.homeBody.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            minHeight: 6,
            value: progress.myCompletionRatio,
            color: AppColors.textPrimary,
            backgroundColor: AppColors.settingsIconBackground,
          ),
        ),
      ],
    );
  }
}

class _FocusedQuestionStatusView extends StatelessWidget {
  const _FocusedQuestionStatusView({
    required this.icon,
    required this.title,
    required this.message,
    required this.progress,
    required this.history,
  });

  final IconData icon;
  final String title;
  final String message;
  final AiFocusedQuestionProgress progress;
  final AsyncValue<List<AiFocusedQuestionHistoryEntry>> history;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        _FocusedQuestionProgressView(progress: progress),
        const SizedBox(height: 72),
        Icon(icon, size: 36, color: AppColors.textPrimary),
        const SizedBox(height: 16),
        WordBoundaryText(
          title,
          textAlign: TextAlign.center,
          style: AppTextStyles.homeBodyMedium,
        ),
        const SizedBox(height: 8),
        WordBoundaryText(
          message,
          textAlign: TextAlign.center,
          style: AppTextStyles.homeBody.copyWith(color: AppColors.textMuted),
        ),
        _FocusedQuestionHistory(history: history),
      ],
    );
  }
}

class _FocusedQuestionHistory extends StatelessWidget {
  const _FocusedQuestionHistory({required this.history});

  final AsyncValue<List<AiFocusedQuestionHistoryEntry>> history;

  @override
  Widget build(BuildContext context) {
    return history.when(
      loading: () => const Padding(
        padding: EdgeInsets.only(top: 40),
        child: Center(
          child: SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.textMuted,
            ),
          ),
        ),
      ),
      error: (error, stackTrace) => const SizedBox.shrink(),
      data: (entries) {
        if (entries.isEmpty) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.only(top: 48),
          child: AiFocusedQuestionHistorySection(entries: entries),
        );
      },
    );
  }
}

class _FocusedQuestionError extends StatelessWidget {
  const _FocusedQuestionError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          WordBoundaryText(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.homeBody,
          ),
          const SizedBox(height: 16),
          IconButton(
            onPressed: onRetry,
            tooltip: '다시 시도',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }
}
