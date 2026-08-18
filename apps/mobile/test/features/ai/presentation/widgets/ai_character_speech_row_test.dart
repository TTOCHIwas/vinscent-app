import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/core/presentation/widgets/character_speech_bubble.dart';
import 'package:vinscent/core/presentation/widgets/character_speech_message.dart';
import 'package:vinscent/features/ai/presentation/widgets/ai_character_speech_row.dart';
import 'package:vinscent/features/ai/presentation/widgets/ai_generated_content_indicator.dart';
import 'package:vinscent/features/characters/application/couple_character_controller.dart';

void main() {
  testWidgets('presents character speech without a bubble surface', (
    tester,
  ) async {
    await _pump(
      tester,
      const MaterialApp(
        home: Scaffold(body: AiCharacterSpeechRow(speechText: '오늘의 한마디')),
      ),
    );

    expect(find.byType(CharacterSpeechMessage), findsOneWidget);
    expect(find.byType(CharacterSpeechBubble), findsNothing);
  });

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
            showGeneratedAttribution: true,
          ),
        ),
      ),
    );

    expect(
      find.byKey(const Key('ai-generated-content-attribution')),
      findsOneWidget,
    );
  });

  testWidgets('places generated attribution below the speech content', (
    tester,
  ) async {
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
    final regularMessageSize = tester.getSize(find.byKey(bubbleKey));
    await _pump(
      tester,
      const MaterialApp(
        home: Scaffold(
          body: AiCharacterSpeechRow(
            bubbleKey: bubbleKey,
            speechText: speechText,
            showGeneratedAttribution: true,
          ),
        ),
      ),
    );
    final generatedMessageSize = tester.getSize(find.byKey(bubbleKey));
    final generatedMessageRect = tester.getRect(find.byKey(bubbleKey));
    final attributionRect = tester.getRect(
      find.byKey(const Key('ai-generated-content-attribution')),
    );

    expect(generatedMessageSize, regularMessageSize);
    expect(find.byType(AiGeneratedContentBadgeOverlay), findsNothing);
    expect(find.text('AI 생성'), findsOneWidget);
    expect(
      attributionRect.top,
      greaterThanOrEqualTo(generatedMessageRect.bottom),
    );
    expect(
      attributionRect.right,
      lessThanOrEqualTo(generatedMessageRect.right),
    );
    expect(
      attributionRect.left,
      greaterThanOrEqualTo(generatedMessageRect.left),
    );
  });

  testWidgets('labels generated custom speech content', (tester) async {
    await _pump(
      tester,
      const MaterialApp(
        home: Scaffold(
          body: AiCharacterSpeechRow.custom(
            semanticLabel: '생성된 답변과 후속 질문',
            showGeneratedAttribution: true,
            child: Text('생성된 답변'),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const Key('ai-generated-content-attribution')),
      findsOneWidget,
    );
  });

  testWidgets('keeps generated attribution separate at large text scale', (
    tester,
  ) async {
    const bubbleKey = Key('ai-scaled-speech-message');

    await _pump(
      tester,
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
          child: const Scaffold(
            body: AiCharacterSpeechRow(
              bubbleKey: bubbleKey,
              speechText: '화면 글자가 커져도 AI 생성 표시는 답변과 겹치지 않아',
              showGeneratedAttribution: true,
            ),
          ),
        ),
      ),
    );

    final messageRect = tester.getRect(find.byKey(bubbleKey));
    final attributionRect = tester.getRect(
      find.byKey(const Key('ai-generated-content-attribution')),
    );
    expect(attributionRect.top, greaterThanOrEqualTo(messageRect.bottom));
    expect(tester.takeException(), isNull);
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
