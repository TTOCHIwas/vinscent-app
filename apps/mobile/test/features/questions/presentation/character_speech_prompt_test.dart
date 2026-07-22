import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/questions/presentation/widgets/character_speech_prompt.dart';

void main() {
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
    expect(renderedText.replaceAll('\u2060', ''), speechText);
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
