import 'package:flutter/material.dart';

import '../../../../core/presentation/widgets/character_speech_bubble.dart';
import '../../../../core/presentation/widgets/word_boundary_text.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/ai_direct_question_history.dart';
import 'ai_character_speech_row.dart';

class AiDirectQuestionExchange extends StatelessWidget {
  const AiDirectQuestionExchange({
    super.key,
    required this.entry,
    required this.questionBubbleKey,
    this.isLatest = false,
  });

  final AiDirectQuestionEntry entry;
  final Key questionBubbleKey;
  final bool isLatest;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _UserQuestionBubble(
          bubbleKey: questionBubbleKey,
          questionText: entry.questionText,
        ),
        const SizedBox(height: 16),
        AiDirectQuestionAnswerView(entry: entry, isLatest: isLatest),
      ],
    );
  }
}

class AiDirectQuestionHistoryEntry extends StatefulWidget {
  const AiDirectQuestionHistoryEntry({
    super.key,
    required this.entry,
    required this.onDelete,
  });

  final AiDirectQuestionEntry entry;
  final VoidCallback onDelete;

  @override
  State<AiDirectQuestionHistoryEntry> createState() =>
      _AiDirectQuestionHistoryEntryState();
}

class _AiDirectQuestionHistoryEntryState
    extends State<AiDirectQuestionHistoryEntry> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          Material(
            key: Key('ai-direct-history-header-${entry.id}'),
            color: Colors.transparent,
            child: InkWell(
              key: Key('ai-direct-history-question-${entry.id}'),
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              onTap: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
              onLongPress: _confirmDelete,
              child: Padding(
                key: Key('ai-direct-history-question-content-${entry.id}'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: WordBoundaryText(
                        entry.questionText,
                        maxLines: _isExpanded ? null : 2,
                        overflow: _isExpanded ? null : TextOverflow.ellipsis,
                        style: AppTextStyles.homeBodyMedium,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      _isExpanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: AppColors.textMuted,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_isExpanded)
            Padding(
              key: Key('ai-direct-history-answer-content-${entry.id}'),
              padding: const EdgeInsets.only(top: 16, bottom: 18),
              child: Column(
                children: [
                  AiDirectQuestionAnswerView(entry: entry),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      key: Key('ai-direct-history-delete-${entry.id}'),
                      tooltip: '질문 삭제',
                      onPressed: _confirmDelete,
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        size: 22,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('질문을 삭제할까요?'),
        content: const Text('질문과 답변이 함께 삭제되고 복구할 수 없어요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (!mounted || shouldDelete != true) {
      return;
    }
    widget.onDelete();
  }
}

class AiDirectQuestionAnswerView extends StatelessWidget {
  const AiDirectQuestionAnswerView({
    super.key,
    required this.entry,
    this.isLatest = false,
  });

  final AiDirectQuestionEntry entry;
  final bool isLatest;

  @override
  Widget build(BuildContext context) {
    return switch (entry.status) {
      AiDirectQuestionStatus.queued ||
      AiDirectQuestionStatus.processing => AiCharacterThinkingSpeechRow(
        key: Key('ai-direct-answer-pending-${entry.id}'),
        characterKey: Key('ai-direct-answer-character-${entry.id}'),
        bubbleKey: Key('ai-direct-answer-bubble-${entry.id}'),
        thinkingDotsKey: Key(
          isLatest
              ? 'ai-direct-answer-thinking-dots'
              : 'ai-direct-answer-thinking-dots-${entry.id}',
        ),
        characterSize: 76,
        message: '답을 생각하는 중',
      ),
      AiDirectQuestionStatus.completed => AiCharacterSpeechRow(
        key: Key('ai-direct-answer-completed-${entry.id}'),
        characterKey: Key('ai-direct-answer-character-${entry.id}'),
        bubbleKey: Key('ai-direct-answer-bubble-${entry.id}'),
        characterSize: 76,
        speechText: entry.answerText!,
        semanticLabel: '캐릭터의 답변: ${entry.answerText!}',
      ),
      AiDirectQuestionStatus.failed => AiCharacterSpeechRow(
        key: Key('ai-direct-answer-failed-${entry.id}'),
        characterKey: Key('ai-direct-answer-character-${entry.id}'),
        bubbleKey: Key('ai-direct-answer-bubble-${entry.id}'),
        characterSize: 76,
        speechText: '이번에는 답을 만들지 못했어',
      ),
    };
  }
}

class _UserQuestionBubble extends StatelessWidget {
  const _UserQuestionBubble({
    required this.questionText,
    required this.bubbleKey,
  });

  final String questionText;
  final Key bubbleKey;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Align(
          alignment: Alignment.centerRight,
          child: Semantics(
            label: '내 질문: $questionText',
            excludeSemantics: true,
            child: CharacterSpeechBubble(
              key: bubbleKey,
              speechText: questionText,
              maxWidth: constraints.maxWidth * 0.86,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              tailSize: const Size(10, 18),
              tailPosition: SpeechBubbleTailPosition.right,
              bubbleColor: AppColors.textPrimary,
              textStyle: AppTextStyles.homeBodyMedium.copyWith(
                color: AppColors.textInverse,
              ),
            ),
          ),
        );
      },
    );
  }
}
