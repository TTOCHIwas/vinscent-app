import 'package:flutter/material.dart';

import '../../../../core/presentation/widgets/character_speech_message.dart';
import '../../../../core/presentation/widgets/character_speech_row.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../ai/presentation/widgets/ai_generated_content_indicator.dart';
import '../../../characters/presentation/widgets/couple_character_avatar.dart';

class QuestionAnswerPromptRow extends StatelessWidget {
  const QuestionAnswerPromptRow({
    super.key,
    required this.questionText,
    this.compact = false,
    this.showGeneratedIndicator = false,
    this.onGeneratedIndicatorPressed,
  });

  final String questionText;
  final bool compact;
  final bool showGeneratedIndicator;
  final VoidCallback? onGeneratedIndicatorPressed;

  @override
  Widget build(BuildContext context) {
    const characterSize = 96.0;

    return CharacterSpeechRow(
      character: const CoupleCharacterAvatar(
        key: Key('question-answer-character'),
        size: characterSize,
      ),
      message: AiGeneratedContentBadgeOverlay(
        showIndicator: showGeneratedIndicator,
        onReportPressed: onGeneratedIndicatorPressed,
        reserveIndicatorSpace: true,
        child: Semantics(
          label: showGeneratedIndicator
              ? 'AI 생성 질문: $questionText'
              : '질문: $questionText',
          excludeSemantics: true,
          child: CharacterSpeechMessage(
            key: const Key('question-answer-prompt'),
            speechText: questionText,
            maxWidth: double.infinity,
            maxLines: compact ? 2 : 4,
            textStyle: AppTextStyles.homeQuestionBubble,
          ),
        ),
      ),
    );
  }
}
