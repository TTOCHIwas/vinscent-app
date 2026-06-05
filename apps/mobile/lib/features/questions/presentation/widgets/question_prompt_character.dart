import 'package:flutter/material.dart';

import 'character_speech_prompt.dart';

class QuestionPromptCharacter extends StatelessWidget {
  const QuestionPromptCharacter({
    super.key,
    required this.questionText,
  });

  final String questionText;

  @override
  Widget build(BuildContext context) {
    return CharacterSpeechPrompt(
      labelText: '질문',
      speechText: questionText,
    );
  }
}
