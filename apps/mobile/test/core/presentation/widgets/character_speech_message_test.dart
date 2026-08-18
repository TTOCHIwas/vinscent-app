import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/core/presentation/widgets/character_speech_message.dart';

void main() {
  testWidgets('presents character speech without a bubble surface or tail', (
    tester,
  ) async {
    const messageKey = Key('character-speech-message');

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CharacterSpeechMessage(
            key: messageKey,
            speechText: '오늘은 같이 걷기 좋은 날이야!',
          ),
        ),
      ),
    );

    final message = find.byKey(messageKey);

    expect(
      find.descendant(of: message, matching: find.byType(CustomPaint)),
      findsNothing,
    );
    expect(
      find.descendant(of: message, matching: find.byType(DecoratedBox)),
      findsNothing,
    );
    expect(find.text('오늘은 같이 걷기 좋은 날이야!'), findsOneWidget);
  });

  testWidgets('keeps all speech visible when system text is enlarged', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: const Scaffold(
          body: SizedBox(
            width: 180,
            child: CharacterSpeechMessage(
              speechText: '서로 좋아하는 시간을 천천히 이야기해 보자',
              maxLines: 2,
            ),
          ),
        ),
      ),
    );

    final text = tester.widget<Text>(find.byType(Text));

    expect(text.maxLines, isNull);
    expect(text.overflow, isNull);
    expect(tester.takeException(), isNull);
  });
}
