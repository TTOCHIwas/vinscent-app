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
    expect(find.byTooltip('AI 생성 내용 안내'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('ai-generated-content-indicator'))),
      const Size.square(32),
    );
    expect(
      tester.getSize(find.byKey(const Key('ai-generated-content-badge'))),
      const Size.square(15),
    );
    expect(
      tester.widget<Icon>(find.byIcon(Icons.auto_awesome_rounded)).size,
      15,
    );
  });

  testWidgets('shows a labelled attribution for generated speech', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AiGeneratedContentAttribution())),
    );

    expect(
      find.byKey(const Key('ai-generated-content-attribution')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('ai-generated-content-label')), findsOneWidget);
    expect(find.text('AI 생성'), findsOneWidget);
    expect(find.byTooltip('AI 생성 내용 안내'), findsOneWidget);
  });

  testWidgets('opens information from the labelled attribution', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AiGeneratedContentAttribution())),
    );

    await tester.tap(find.byKey(const Key('ai-generated-content-attribution')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('ai-generated-content-info-sheet')),
      findsOneWidget,
    );
  });

  testWidgets(
    'opens AI-generated content information without a report action',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: AiGeneratedContentIndicator())),
      );

      await tester.tap(find.byKey(const Key('ai-generated-content-indicator')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('ai-generated-content-info-sheet')),
        findsOneWidget,
      );
      expect(find.text('AI가 만든 내용이에요'), findsOneWidget);
      expect(
        find.byKey(const Key('ai-generated-content-report')),
        findsNothing,
      );
    },
  );

  testWidgets('forwards a report action from the information sheet', (
    tester,
  ) async {
    var pressed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AiGeneratedContentIndicator(
            onReportPressed: () {
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
