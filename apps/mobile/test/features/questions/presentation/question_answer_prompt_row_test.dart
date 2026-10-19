import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/core/presentation/widgets/character_speech_bubble.dart';
import 'package:vinscent/core/presentation/widgets/character_speech_message.dart';
import 'package:vinscent/features/characters/application/couple_character_controller.dart';
import 'package:vinscent/features/questions/presentation/widgets/question_answer_prompt_row.dart';
import 'package:vinscent/features/ai/presentation/widgets/ai_generated_content_indicator.dart';

void main() {
  testWidgets('centers the character and speech message on phone and tablet', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final (width, showIndicator) in [
      (360.0, false),
      (360.0, true),
      (1024.0, false),
      (1024.0, true),
    ]) {
      tester.view.physicalSize = Size(width, 700);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            coupleCharacterControllerProvider.overrideWithBuild(
              (ref, notifier) async => null,
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: QuestionAnswerPromptRow(
                questionText: '오늘 서로에게 가장 고마웠던 순간은 언제야?',
                showGeneratedIndicator: showIndicator,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final character = find.byKey(const Key('question-answer-character'));
      final message = find.byKey(const Key('question-answer-prompt'));
      final characterRect = tester.getRect(character);
      final messageRect = tester.getRect(message);
      final area = tester.getRect(
        find.byKey(const Key('character-speech-message-area')),
      );
      final group = tester.getRect(find.byType(AiGeneratedContent));
      final visualCenter = (characterRect.left + area.right) / 2;
      expect(group.center.dx, closeTo(area.center.dx, 0.01));
      expect(characterRect.center.dy, closeTo(messageRect.center.dy, 0.01));

      expect(
        visualCenter,
        closeTo(width / 2, 0.5),
        reason: 'prompt should remain centered at width $width',
      );
      expect(
        messageRect.right - characterRect.left,
        lessThanOrEqualTo(360),
        reason: 'prompt should keep the shared readable maximum width',
      );
      expect(find.byType(CharacterSpeechMessage), findsOneWidget);
      expect(find.byType(CharacterSpeechBubble), findsNothing);
    }
  });
}
