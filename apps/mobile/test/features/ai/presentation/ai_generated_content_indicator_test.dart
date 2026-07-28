import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/ai/presentation/widgets/ai_generated_content_indicator.dart';

void main() {
  testWidgets('shows a compact marker for AI-generated content', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AiGeneratedContentIndicator())),
    );

    expect(
      find.byKey(const Key('ai-generated-content-indicator')),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
    expect(find.bySemanticsLabel('AI 생성'), findsOneWidget);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.auto_awesome_rounded)).size,
      15,
    );
  });

  testWidgets('forwards an optional report action', (tester) async {
    var pressed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AiGeneratedContentIndicator(
            onPressed: () {
              pressed = true;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('ai-generated-content-indicator')));

    expect(pressed, isTrue);
    expect(find.byTooltip('AI 생성 내용'), findsOneWidget);
  });
}
