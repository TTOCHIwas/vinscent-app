import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/ai/presentation/widgets/ai_character_speech_row.dart';
import 'package:vinscent/features/characters/application/couple_character_controller.dart';

void main() {
  testWidgets('does not label static character speech as AI-generated', (
    tester,
  ) async {
    await _pump(
      tester,
      const MaterialApp(
        home: Scaffold(body: AiCharacterSpeechRow(speechText: '답을 생각하는 중')),
      ),
    );

    expect(
      find.byKey(const Key('ai-generated-content-indicator')),
      findsNothing,
    );
  });

  testWidgets('labels generated character speech only when requested', (
    tester,
  ) async {
    await _pump(
      tester,
      const MaterialApp(
        home: Scaffold(
          body: AiCharacterSpeechRow(
            speechText: '둘의 답변을 바탕으로 만든 한마디',
            showGeneratedIndicator: true,
          ),
        ),
      ),
    );

    expect(
      find.byKey(const Key('ai-generated-content-indicator')),
      findsOneWidget,
    );
  });

  testWidgets('keeps generated speech padding compact', (tester) async {
    const bubbleKey = Key('ai-character-speech-bubble');
    const speechText = '둘의 답변을 바탕으로 만든 한마디';

    await _pump(
      tester,
      const MaterialApp(
        home: Scaffold(
          body: AiCharacterSpeechRow(
            bubbleKey: bubbleKey,
            speechText: speechText,
          ),
        ),
      ),
    );
    final regularSize = tester.getSize(find.byKey(bubbleKey));

    await _pump(
      tester,
      const MaterialApp(
        home: Scaffold(
          body: AiCharacterSpeechRow(
            bubbleKey: bubbleKey,
            speechText: speechText,
            showGeneratedIndicator: true,
          ),
        ),
      ),
    );
    final generatedSize = tester.getSize(find.byKey(bubbleKey));
    final generatedRect = tester.getRect(find.byKey(bubbleKey));
    final badgeRect = tester.getRect(
      find.byKey(const Key('ai-generated-content-badge')),
    );

    expect(generatedSize.width - regularSize.width, closeTo(0, 0.1));
    expect(generatedSize.height - regularSize.height, closeTo(6, 0.1));
    expect(badgeRect.right, lessThanOrEqualTo(generatedRect.right));
    expect(badgeRect.bottom, lessThanOrEqualTo(generatedRect.bottom));
  });

  testWidgets('labels generated custom speech content', (tester) async {
    await _pump(
      tester,
      const MaterialApp(
        home: Scaffold(
          body: AiCharacterSpeechColumn.custom(
            semanticLabel: '생성된 답변과 후속 질문',
            showGeneratedIndicator: true,
            child: Text('생성된 답변'),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const Key('ai-generated-content-indicator')),
      findsOneWidget,
    );
  });

  testWidgets('uses the width provided to primary speech content', (
    tester,
  ) async {
    const bubbleKey = Key('ai-primary-speech-bubble');

    await _pump(
      tester,
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 640,
            child: AiCharacterSpeechColumn.custom(
              bubbleKey: bubbleKey,
              semanticLabel: '넓은 AI 답변',
              child: SizedBox(width: double.infinity, child: Text('넓은 AI 답변')),
            ),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byKey(bubbleKey)).width, 640);
  });
}

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        coupleCharacterControllerProvider.overrideWithBuild(
          (ref, notifier) async => null,
        ),
      ],
      child: child,
    ),
  );
}
