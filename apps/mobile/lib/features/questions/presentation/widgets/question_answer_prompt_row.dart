import 'package:flutter/material.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../characters/presentation/widgets/couple_character_avatar.dart';
import 'character_speech_prompt.dart';

class QuestionAnswerPromptRow extends StatelessWidget {
  const QuestionAnswerPromptRow({
    super.key,
    required this.questionText,
    this.compact = false,
  });

  final String questionText;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    const characterSize = 96.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(width: 24),
        CoupleCharacterAvatar(
          key: const Key('question-answer-character'),
          size: characterSize,
        ),
        Expanded(
          child: Semantics(
            label: '질문',
            child: CharacterSpeechBubble(
              key: const Key('question-answer-prompt'),
              speechText: questionText,
              maxWidth: double.infinity,
              maxLines: compact ? 2 : 4,
              contentPadding: EdgeInsets.symmetric(
                horizontal: compact ? 14 : 16,
                vertical: compact ? 8 : 12,
              ),
              tailSize: const Size(10, 18),
              tailPosition: SpeechBubbleTailPosition.left,
              textStyle: AppTextStyles.homeQuestionBubble,
            ),
          ),
        ),
      ],
    );
  }
}
