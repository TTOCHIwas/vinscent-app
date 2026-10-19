import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/core/presentation/widgets/character_speech_bubble.dart';
import 'package:vinscent/core/presentation/widgets/character_speech_message.dart';
import 'package:vinscent/features/ai/presentation/widgets/ai_character_speech_row.dart';
import 'package:vinscent/features/ai/presentation/widgets/ai_generated_content_indicator.dart';
import 'package:vinscent/features/characters/application/couple_character_controller.dart';
import 'package:vinscent/features/characters/presentation/widgets/couple_character_avatar.dart';

void main() {
  for (final width in [272.0, 342.0, 552.0]) {
    for (final textScale in [1.0, 1.6]) {
      testWidgets('speech columns align at width $width and scale $textScale', (
        tester,
      ) async {
        await _pump(
          tester,
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: SizedBox(
                    width: width,
                    child: const Column(
                      children: [
                        AiCharacterSpeechRow(speechText: '고마워'),
                        AiCharacterSpeechRow(
                          speechText:
                              '함께 남긴 이야기를 천천히 돌아보며 다음 달에도 함께하고 싶은 순간을 생각해 봐.',
                          showGeneratedIndicator: true,
                        ),
                        AiCharacterSpeechRow.custom(
                          semanticLabel: '다음 달에는?',
                          showGeneratedIndicator: true,
                          child: Text('다음 달에는?'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final avatars = find.byType(CoupleCharacterAvatar);
        final messages = find.byType(CharacterSpeechMessage);
        final areas = find.byKey(const Key('character-speech-message-area'));
        final groups = find.byType(AiGeneratedContent);
        final firstAvatar = tester.getRect(avatars.first);
        final firstMessage = tester.getRect(messages.first);
        expect(firstAvatar.center.dy, closeTo(firstMessage.center.dy, 0.01));
        final contentWidth = width < 360 ? width : 360.0;
        expect(firstAvatar.width, 96);
        expect(firstAvatar.left, closeTo((width - contentWidth) / 2, 0.01));
        expect(
          tester.getRect(areas.first).left - firstAvatar.right,
          closeTo(12, 0.01),
        );
        expect(
          tester.getRect(areas.first).width,
          closeTo(contentWidth - 108, 0.01),
        );
        for (var index = 0; index < 3; index++) {
          final avatar = tester.getRect(avatars.at(index));
          expect(avatar.left, firstAvatar.left);
          final message = tester.getRect(messages.at(index));
          final area = tester.getRect(areas.at(index));
          final group = tester.getRect(groups.at(index));
          expect(group.center.dx, closeTo(area.center.dx, 0.01));
          expect(message.left, greaterThanOrEqualTo(area.left));
          expect(message.right, lessThanOrEqualTo(area.right));
          expect(avatar.center.dy, closeTo(message.center.dy, 0.01));
        }
        final indicator = tester.getRect(
          find.byKey(const Key('ai-generated-content-indicator')).first,
        );
        expect(
          indicator.left,
          greaterThanOrEqualTo(tester.getRect(groups.at(1)).left),
        );
        expect(indicator.bottom + 8, tester.getRect(messages.at(1)).top);
        expect(tester.takeException(), isNull);
      });
    }
  }

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
            showGeneratedIndicator: true,
          ),
        ),
      ),
    );

    expect(
      find.byKey(const Key('ai-generated-content-indicator')),
      findsOneWidget,
    );
    expect(find.text('AI 생성'), findsNothing);
  });

  testWidgets('places generated indicator above the speech content', (
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
            showGeneratedIndicator: true,
          ),
        ),
      ),
    );
    final generatedMessageSize = tester.getSize(find.byKey(bubbleKey));
    final generatedMessageRect = tester.getRect(find.byKey(bubbleKey));
    final indicatorRect = tester.getRect(
      find.byKey(const Key('ai-generated-content-indicator')),
    );

    expect(generatedMessageSize, regularMessageSize);
    expect(generatedMessageRect.top - indicatorRect.bottom, closeTo(8, 0.01));
    expect(indicatorRect.right, lessThanOrEqualTo(generatedMessageRect.right));
    expect(indicatorRect.left, greaterThanOrEqualTo(generatedMessageRect.left));
  });

  testWidgets('labels generated custom speech content', (tester) async {
    await _pump(
      tester,
      const MaterialApp(
        home: Scaffold(
          body: AiCharacterSpeechRow.custom(
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

  testWidgets(
    'keeps the full indicator touch target inside a short speech row',
    (tester) async {
      await _pump(
        tester,
        const MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: AiCharacterSpeechRow(
                speechText: '고마워',
                showGeneratedIndicator: true,
              ),
            ),
          ),
        ),
      );
      final row = tester.getRect(
        find
            .descendant(
              of: find.byType(AiCharacterSpeechRow),
              matching: find.byType(Row),
            )
            .first,
      );
      final indicator = tester.getRect(
        find.byKey(const Key('ai-generated-content-indicator')),
      );
      final avatar = tester.getRect(find.byType(CoupleCharacterAvatar));
      final message = tester.getRect(find.byType(CharacterSpeechMessage));
      final area = tester.getRect(
        find.byKey(const Key('character-speech-message-area')),
      );
      expect(indicator.size, const Size.square(44));
      expect(row.contains(indicator.topLeft), isTrue);
      expect(avatar.center.dy, closeTo(message.center.dy, 0.01));
      expect(message.center.dx, closeTo(area.center.dx, 0.01));
      expect(row.height - avatar.height, lessThan(23));
      await tester.tapAt(indicator.topLeft + const Offset(38, 4));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('ai-generated-content-info-sheet')),
        findsOneWidget,
      );
    },
  );

  testWidgets('keeps generated indicator separate at large text scale', (
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
              showGeneratedIndicator: true,
            ),
          ),
        ),
      ),
    );

    final messageRect = tester.getRect(find.byKey(bubbleKey));
    final indicatorRect = tester.getRect(
      find.byKey(const Key('ai-generated-content-indicator')),
    );
    expect(messageRect.top - indicatorRect.bottom, closeTo(8, 0.01));
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
