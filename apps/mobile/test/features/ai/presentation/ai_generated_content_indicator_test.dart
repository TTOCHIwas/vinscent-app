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
    expect(find.byIcon(Icons.info_rounded), findsOneWidget);
    expect(find.text('AI 생성'), findsNothing);
    expect(find.byTooltip('AI가 만든 내용 안내'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('ai-generated-content-indicator'))),
      const Size.square(44),
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

  for (final scale in [1.0, 2.0]) {
    testWidgets('keeps the icon above wrapped content at text scale $scale', (
      tester,
    ) async {
      const contentKey = Key('generated-body');
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: const Scaffold(
              body: SingleChildScrollView(
                child: SizedBox(
                  width: 180,
                  child: AiGeneratedContent(
                    child: Text(
                      '긴 문장이 여러 줄로 표시되어도 생성 표기는 본문과 겹치지 않아야 해요.',
                      key: contentKey,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final icon = tester.getRect(
        find.byKey(const Key('ai-generated-content-badge')),
      );
      final body = tester.getRect(find.byKey(contentKey));
      expect(icon.left, body.left);
      expect(body.top - icon.bottom, closeTo(8, 0.01));
      expect(find.text('AI 생성'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('does not reserve indicator space for non-generated content', (
    tester,
  ) async {
    const contentKey = Key('original-body');
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AiGeneratedContent(
            showIndicator: false,
            child: SizedBox(key: contentKey, width: 180, height: 24),
          ),
        ),
      ),
    );
    expect(
      tester.getSize(find.byType(AiGeneratedContent)),
      const Size(180, 24),
    );
    expect(find.byType(AiGeneratedContentIndicator), findsNothing);
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
