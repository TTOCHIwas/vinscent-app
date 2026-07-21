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
    final paragraph = tester.renderObject<RenderParagraph>(find.byType(Text));

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
}
