import 'package:flutter/material.dart';

import '../../../../core/presentation/widgets/app_action_button.dart';
import '../../../../core/presentation/widgets/word_boundary_text.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/ai_direct_question_history.dart';
import 'ai_character_speech_row.dart';

class AiDirectQuestionFollowUpView extends StatefulWidget {
  const AiDirectQuestionFollowUpView({
    super.key,
    required this.questionId,
    required this.answerText,
    required this.followUp,
    required this.onApprove,
    required this.onDismiss,
    this.usePrimaryLayout = false,
  });

  final String questionId;
  final String answerText;
  final AiDirectQuestionFollowUp followUp;
  final Future<void> Function() onApprove;
  final Future<void> Function() onDismiss;
  final bool usePrimaryLayout;

  @override
  State<AiDirectQuestionFollowUpView> createState() =>
      _AiDirectQuestionFollowUpViewState();
}

class _AiDirectQuestionFollowUpViewState
    extends State<AiDirectQuestionFollowUpView> {
  _FollowUpAction? _activeAction;

  @override
  Widget build(BuildContext context) {
    final followUp = widget.followUp;
    final isPending = followUp.status == AiDirectQuestionFollowUpStatus.pending;
    final semanticLabel = isPending
        ? '${widget.answerText} 둘이 답할 질문으로 알아볼까? ${followUp.questionText}'
        : '${widget.answerText} 둘이 답할 질문으로 남겨뒀어 ${followUp.questionText}';

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WordBoundaryText(
          widget.answerText,
          style: AppTextStyles.homeQuestionBubble,
        ),
        const SizedBox(height: 14),
        WordBoundaryText(
          isPending ? '둘이 답할 질문으로 알아볼까?' : '둘이 답할 질문으로 남겨뒀어',
          style: AppTextStyles.homeBody.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: 6),
        WordBoundaryText(
          followUp.questionText,
          key: Key('ai-direct-follow-up-question-${widget.questionId}'),
          style: AppTextStyles.homeBodyMedium,
        ),
        if (isPending) ...[
          const SizedBox(height: 16),
          AppActionButton(
            key: Key('ai-direct-follow-up-approve-${widget.questionId}'),
            label: '질문으로 남기기',
            enabled: _activeAction == null,
            isLoading: _activeAction == _FollowUpAction.approve,
            onPressed: () => _submit(_FollowUpAction.approve, widget.onApprove),
          ),
          const SizedBox(height: 10),
          AppActionButton(
            key: Key('ai-direct-follow-up-dismiss-${widget.questionId}'),
            label: '괜찮아',
            enabled: _activeAction == null,
            isLoading: _activeAction == _FollowUpAction.dismiss,
            isSecondary: true,
            onPressed: () => _submit(_FollowUpAction.dismiss, widget.onDismiss),
          ),
        ],
      ],
    );

    if (widget.usePrimaryLayout) {
      return AiCharacterSpeechColumn.custom(
        key: Key('ai-direct-answer-completed-${widget.questionId}'),
        characterKey: Key('ai-direct-answer-character-${widget.questionId}'),
        bubbleKey: Key('ai-direct-answer-bubble-${widget.questionId}'),
        characterSize: 156,
        semanticLabel: semanticLabel,
        child: content,
      );
    }

    return AiCharacterSpeechRow.custom(
      key: Key('ai-direct-answer-completed-${widget.questionId}'),
      characterKey: Key('ai-direct-answer-character-${widget.questionId}'),
      bubbleKey: Key('ai-direct-answer-bubble-${widget.questionId}'),
      characterSize: 76,
      semanticLabel: semanticLabel,
      child: content,
    );
  }

  Future<void> _submit(
    _FollowUpAction action,
    Future<void> Function() submit,
  ) async {
    if (_activeAction != null) {
      return;
    }
    setState(() {
      _activeAction = action;
    });
    try {
      await submit();
    } finally {
      if (mounted) {
        setState(() {
          _activeAction = null;
        });
      }
    }
  }
}

enum _FollowUpAction { approve, dismiss }
