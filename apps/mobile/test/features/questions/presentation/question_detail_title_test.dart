import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/core/presentation/widgets/word_boundary_text.dart';
import 'package:vinscent/features/ai/presentation/widgets/ai_generated_content_indicator.dart';
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
    expect(
      find.byKey(const Key('ai-generated-content-indicator')),
      findsNothing,
    );
  });

  testWidgets('marks an AI-generated question title when requested', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: QuestionDetailTitle(
            questionText: 'AI가 만든 질문',
            showGeneratedIndicator: true,
          ),
        ),
      ),
    );

    expect(
      find.descendant(
        of: find.byType(QuestionDetailTitle),
        matching: find.byKey(const Key('ai-generated-content-indicator')),
      ),
      findsOneWidget,
    );
    expect(find.byType(AiGeneratedContentBadgeOverlay), findsNothing);

    final titleRect = tester.getRect(
      find.byKey(const Key('question-detail-title')),
    );
    final badgeRect = tester.getRect(
      find.byKey(const Key('ai-generated-content-badge')),
    );
    expect(
      badgeRect.center.dy,
      inInclusiveRange(titleRect.top, titleRect.bottom),
    );
  });

  testWidgets('forwards generated indicator presses', (tester) async {
    var pressed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuestionDetailTitle(
            questionText: 'AI가 만든 질문',
            showGeneratedIndicator: true,
            onGeneratedIndicatorPressed: () {
              pressed = true;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('ai-generated-content-indicator')));
    await tester.pumpAndSettle();

    expect(pressed, isFalse);
    await tester.tap(find.byKey(const Key('ai-generated-content-report')));
    await tester.pumpAndSettle();
    expect(pressed, isTrue);
  });
}
