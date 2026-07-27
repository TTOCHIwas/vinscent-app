import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/core/presentation/widgets/word_boundary_text.dart';
import 'package:vinscent/features/questions/presentation/widgets/question_detail_title.dart';

void main() {
  testWidgets('wraps a Korean question title at word boundaries', (
    tester,
  ) async {
    const question = '가나다라 마바사아';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 90,
            child: QuestionDetailTitle(questionText: question),
          ),
        ),
      ),
    );

    final boundaryText = find.descendant(
      of: find.byType(QuestionDetailTitle),
      matching: find.byType(WordBoundaryText),
    );
    expect(boundaryText, findsOneWidget);

    final renderedText = tester.widget<Text>(
      find.descendant(of: boundaryText, matching: find.byType(Text)),
    );
    expect(renderedText.data, '가나다라\n마바사아');
    expect(renderedText.semanticsLabel, question);
  });
}
