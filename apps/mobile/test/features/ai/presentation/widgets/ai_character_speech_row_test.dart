import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/ai/presentation/widgets/ai_character_speech_row.dart';

void main() {
  testWidgets('does not label static character speech as AI-generated', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AiCharacterSpeechRow(speechText: '답을 생각하는 중'),
        ),
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
    await tester.pumpWidget(
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

  testWidgets('labels generated custom speech content', (tester) async {
    await tester.pumpWidget(
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
}
