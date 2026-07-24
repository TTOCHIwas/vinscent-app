import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/characters/application/couple_character_controller.dart';
import 'package:vinscent/features/questions/presentation/widgets/question_answer_prompt_row.dart';

void main() {
  testWidgets('centers the character and speech bubble on phone and tablet', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final width in [360.0, 1024.0]) {
      tester.view.physicalSize = Size(width, 700);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            coupleCharacterControllerProvider.overrideWithBuild(
              (ref, notifier) async => null,
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: QuestionAnswerPromptRow(
                questionText: '오늘 서로에게 가장 고마웠던 순간은 언제야?',
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final character = find.byKey(const Key('question-answer-character'));
      final bubble = find.byKey(const Key('question-answer-prompt'));
      final characterRect = tester.getRect(character);
      final bubbleRect = tester.getRect(bubble);
      final visualCenter = (characterRect.left + bubbleRect.right) / 2;

      expect(
        visualCenter,
        closeTo(width / 2, 0.5),
        reason: 'prompt should remain centered at width $width',
      );
      expect(
        bubbleRect.right - characterRect.left,
        lessThanOrEqualTo(360),
        reason: 'prompt should keep the shared readable maximum width',
      );
    }
  });
}
