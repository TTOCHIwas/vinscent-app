import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/core/presentation/widgets/character_speech_bubble.dart';
import 'package:vinscent/core/presentation/widgets/character_speech_message.dart';
import 'package:vinscent/features/questions/presentation/widgets/character_speech_prompt.dart';

void main() {
  testWidgets('presents prompt speech without a bubble surface', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: CharacterSpeechPrompt(
              labelText: '질문',
              speechText: '오늘 가장 즐거웠던 순간은 언제야?',
            ),
          ),
        ),
      ),
    );

    expect(find.byType(CharacterSpeechMessage), findsOneWidget);
    expect(find.byType(CharacterSpeechBubble), findsNothing);
  });

  testWidgets('aligns regular speech to the reading direction', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CharacterSpeechBubble(speechText: '여러 줄로 이어지는 캐릭터의 말'),
        ),
      ),
    );

    expect(tester.widget<Text>(find.byType(Text)).textAlign, TextAlign.start);
  });

  testWidgets('allows short speech to remain centered', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CharacterSpeechBubble(
            speechText: '생각 중',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );

    expect(tester.widget<Text>(find.byType(Text)).textAlign, TextAlign.center);
  });

  testWidgets('wraps Korean speech at word boundaries', (tester) async {
    const speechText = '힘든 선택을 할 때 가장 중요하게 생각하는 기준은 뭐야?';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 206,
              child: CharacterSpeechBubble(
                speechText: speechText,
                maxWidth: 206,
                contentPadding: EdgeInsets.symmetric(horizontal: 16),
                tailSize: Size.zero,
                textStyle: TextStyle(fontSize: 20, height: 1),
              ),
            ),
          ),
        ),
      ),
    );

    final text = tester.widget<Text>(find.byType(Text));
    final renderedText = text.data!;
    expect(renderedText.replaceAll('\n', ' '), speechText);
    expect(renderedText, isNot(contains('\u2060')));
    expect(text.semanticsLabel, speechText);
    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(of: find.byType(Text), matching: find.byType(RichText)),
    );

    for (final word in RegExp(r'\S+').allMatches(renderedText)) {
      final wordBoxes = paragraph.getBoxesForSelection(
        TextSelection(baseOffset: word.start, extentOffset: word.end),
      );
      final occupiedLines = wordBoxes.map((box) => box.top.round()).toSet();

      expect(
        occupiedLines,
        hasLength(1),
        reason: '`${word.group(0)}` should not split across lines',
      );
    }
  });

  testWidgets('wraps a word that is wider than the speech bubble', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 80,
              child: CharacterSpeechBubble(
                speechText: '가나다라마바사아자차카타파하',
                maxWidth: 80,
                contentPadding: EdgeInsets.zero,
                tailSize: Size.zero,
                textStyle: TextStyle(fontSize: 20, height: 1),
              ),
            ),
          ),
        ),
      ),
    );

    final text = tester.widget<Text>(find.byType(Text));
    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(of: find.byType(Text), matching: find.byType(RichText)),
    );
    final occupiedLines = paragraph
        .getBoxesForSelection(
          TextSelection(baseOffset: 0, extentOffset: text.data!.length),
        )
        .map((box) => box.top.round())
        .toSet();

    expect(text.data, isNot(contains('\u2060')));
    expect(occupiedLines.length, greaterThan(1));
    expect(paragraph.size.width, lessThanOrEqualTo(80));
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps non-Korean speech source text unchanged', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CharacterSpeechBubble(speechText: 'today question'),
        ),
      ),
    );

    expect(tester.widget<Text>(find.byType(Text)).data, 'today question');
  });

  testWidgets('does not ellipsize speech when system text is enlarged', (
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
            child: CharacterSpeechBubble(
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
