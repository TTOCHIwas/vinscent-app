import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/ai/application/ai_focused_question_controller.dart';
import 'package:vinscent/features/ai/data/ai_focused_question_flow.dart';
import 'package:vinscent/features/ai/data/ai_focused_question_history_entry.dart';
import 'package:vinscent/features/ai/presentation/ai_focused_question_screen.dart';

void main() {
  testWidgets('shows one question and separate progress values', (
    tester,
  ) async {
    await _pump(tester, _flow());

    expect(find.byKey(const Key('ai-focused-question-text')), findsOneWidget);
    expect(find.byKey(const Key('ai-focused-my-progress')), findsOneWidget);
    expect(find.byKey(const Key('ai-focused-couple-progress')), findsOneWidget);
    expect(find.byKey(const Key('ai-focused-answer-input')), findsOneWidget);
    expect(find.byKey(const Key('ai-focused-submit')), findsOneWidget);
  });

  testWidgets('wraps a long question at a large system text size', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pump(
      tester,
      _flow(questionText: '서로에게 가장 편안하게 마음을 보여줄 수 있었던 순간은 언제였는지 천천히 떠올려볼까?'),
      textScaleFactor: 2,
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('shows both answers in completed focused history', (
    tester,
  ) async {
    await _pump(tester, _flow(), history: const [_historyEntry]);

    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('ai-focused-history-question-history-id')),
    );
    await tester.pumpAndSettle();

    expect(find.text('내 답변'), findsOneWidget);
    expect(find.bySemanticsLabel('함께 보내는 시간이야'), findsOneWidget);
    expect(find.text('상대방 답변'), findsOneWidget);
    expect(find.bySemanticsLabel('평온한 일상이야'), findsOneWidget);
  });
}

Future<void> _pump(
  WidgetTester tester,
  AiFocusedQuestionFlow flow, {
  double textScaleFactor = 1,
  List<AiFocusedQuestionHistoryEntry> history = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        aiFocusedQuestionControllerProvider.overrideWithBuild(
          (ref, notifier) async => flow,
        ),
        aiFocusedQuestionHistoryProvider.overrideWith((ref) async => history),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScaleFactor)),
          child: child!,
        ),
        home: const Scaffold(body: AiFocusedQuestionScreen()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

const _historyEntry = AiFocusedQuestionHistoryEntry(
  questionId: 'question-history-id',
  questionKey: 'question_history',
  questionText: '서로에게 가장 편안한 순간은 언제야?',
  learningDomain: 'daily_life',
  depth: 'light',
  curriculumPosition: 1,
  myAnswerText: '함께 보내는 시간이야',
  partnerAnswerText: '평온한 일상이야',
);

AiFocusedQuestionFlow _flow({String questionText = '요즘 가장 기대되는 건 뭐야?'}) {
  return AiFocusedQuestionFlow(
    status: AiFocusedQuestionStatus.answering,
    progress: const AiFocusedQuestionProgress(
      curriculumVersion: 1,
      myAnsweredCount: 4,
      partnerAnsweredCount: 3,
      coupleCompletedCount: 3,
      totalCount: 24,
    ),
    question: AiFocusedQuestion(
      id: 'question-id',
      key: 'question-key',
      text: questionText,
      learningDomain: 'daily_life',
      depth: 'exploratory',
      curriculumPosition: 5,
      partnerAnswered: false,
    ),
  );
}
