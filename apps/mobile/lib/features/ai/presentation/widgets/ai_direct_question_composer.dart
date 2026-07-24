import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/presentation/widgets/app_answer_input.dart';
import '../../../../core/presentation/widgets/word_boundary_text.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../application/ai_direct_question_controller.dart';
import '../../data/ai_direct_question_history.dart';
import '../ai_direct_question_composer_controller.dart';
import 'ai_character_speech_row.dart';
import 'ai_direct_question_entry_view.dart';
import 'ai_learning_error_message.dart';

class AiDirectQuestionComposer extends ConsumerWidget {
  const AiDirectQuestionComposer({
    super.key,
    required this.controller,
    required this.onHistoryPressed,
  });

  final AiDirectQuestionComposerController controller;
  final VoidCallback onHistoryPressed;

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
          onHistoryPressed: onHistoryPressed,
        ),
      ),
    );
  }
}

class _DirectQuestionComposerContent extends StatelessWidget {
  const _DirectQuestionComposerContent({
    required this.history,
    required this.controller,
    required this.onHistoryPressed,
  });

  final AiDirectQuestionHistory history;
  final AiDirectQuestionComposerController controller;
  final VoidCallback onHistoryPressed;

  @override
  Widget build(BuildContext context) {
    final latestQuestion = history.questions.firstOrNull;

    return Column(
      key: const Key('ai-direct-question-composer'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DirectQuestionGuide(remainingCount: history.remainingCount),
        const SizedBox(height: 20),
        AppAnswerInput(
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
        if (latestQuestion != null) ...[
          const SizedBox(height: 28),
          Text(
            '최근 답변',
            style: AppTextStyles.homeBodyMedium.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 12),
          AiDirectQuestionExchange(
            entry: latestQuestion,
            questionBubbleKey: const Key('ai-direct-latest-question-bubble'),
            isLatest: true,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              key: const Key('ai-direct-history-open'),
              onPressed: onHistoryPressed,
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.chevron_right_rounded, size: 20),
              label: const Text('지난 질문 보기'),
            ),
          ),
        ],
      ],
    );
  }
}

class _DirectQuestionGuide extends StatefulWidget {
  const _DirectQuestionGuide({required this.remainingCount});

  final int remainingCount;

  @override
  State<_DirectQuestionGuide> createState() => _DirectQuestionGuideState();
}

class _DirectQuestionGuideState extends State<_DirectQuestionGuide> {
  static const _switchInterval = Duration(seconds: 4);
  static const _transitionDuration = Duration(milliseconds: 250);

  Timer? _messageTimer;
  var _messageIndex = 0;

  List<String> get _messages => widget.remainingCount > 0
      ? ['나에게 궁금한 걸 물어봐!', '오늘 ${widget.remainingCount}번 더 물어볼 수 있어']
      : const ['오늘 질문은 모두 사용했어! 내일 다시 물어봐!'];

  @override
  void initState() {
    super.initState();
    _restartTimer();
  }

  @override
  void didUpdateWidget(covariant _DirectQuestionGuide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.remainingCount == widget.remainingCount) {
      return;
    }

    _messageIndex = 0;
    _restartTimer();
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    super.dispose();
  }

  void _restartTimer() {
    _messageTimer?.cancel();
    if (_messages.length < 2) {
      return;
    }

    _messageTimer = Timer.periodic(_switchInterval, (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _messageIndex = (_messageIndex + 1) % _messages.length;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final messages = _messages;
    final message = messages[_messageIndex % messages.length];
    final isRemainingCount = widget.remainingCount > 0 && _messageIndex == 1;

    return AiCharacterSpeechColumn.custom(
      characterKey: const Key('ai-direct-guide-character'),
      bubbleKey: const Key('ai-direct-guide-prompt'),
      characterSize: 156,
      semanticLabel: message,
      child: AnimatedSize(
        duration: _transitionDuration,
        curve: Curves.easeOutCubic,
        child: AnimatedSwitcher(
          duration: _transitionDuration,
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: WordBoundaryText(
            message,
            key: isRemainingCount
                ? const Key('ai-direct-remaining-count')
                : ValueKey(message),
            textAlign: TextAlign.center,
            style: AppTextStyles.homeQuestionBubble,
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
