import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/core/presentation/widgets/word_boundary_text.dart';
import 'package:vinscent/features/ai/data/ai_direct_question_history.dart';
import 'package:vinscent/features/ai/data/ai_direct_question_repository.dart';
import 'package:vinscent/features/ai/presentation/ai_direct_question_screen.dart';

void main() {
  testWidgets('shows every question as collapsed history without an input', (
    tester,
  ) async {
    await _pump(
      tester,
      _FakeDirectQuestionRepository(
        history: _history(questions: [_latestQuestion, _pastQuestion]),
      ),
    );

    expect(find.text('지난 질문'), findsOneWidget);
    expect(find.byKey(const Key('ai-direct-question-input')), findsNothing);
    expect(
      find.byKey(const Key('ai-direct-history-question-latest-question')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('ai-direct-history-question-past-question')),
      findsOneWidget,
    );
    expect(_wordBoundaryText('최근 답변'), findsNothing);
    expect(_wordBoundaryText('지난 답변'), findsNothing);
  });

  testWidgets('expands the selected question answer', (tester) async {
    await _pump(
      tester,
      _FakeDirectQuestionRepository(
        history: _history(questions: [_latestQuestion, _pastQuestion]),
      ),
    );

    final pastQuestion = find.byKey(
      const Key('ai-direct-history-question-past-question'),
    );
    await tester.tap(pastQuestion);
    await tester.pump();

    expect(_wordBoundaryText('지난 답변'), findsOneWidget);
    expect(_wordBoundaryText('최근 답변'), findsNothing);
  });

  testWidgets('keeps the expanded row transparent with content spacing', (
    tester,
  ) async {
    await _pump(
      tester,
      _FakeDirectQuestionRepository(
        history: _history(questions: [_latestQuestion]),
      ),
    );

    const questionId = 'latest-question';
    final header = find.byKey(
      const Key('ai-direct-history-header-$questionId'),
    );
    final question = find.byKey(
      const Key('ai-direct-history-question-$questionId'),
    );
    final content = find.byKey(
      const Key('ai-direct-history-question-content-$questionId'),
    );
    final answerContent = find.byKey(
      const Key('ai-direct-history-answer-content-$questionId'),
    );
    final deleteAction = find.byKey(
      const Key('ai-direct-history-delete-$questionId'),
    );

    expect(header, findsOneWidget);
    expect(find.byIcon(Icons.more_horiz_rounded), findsNothing);
    expect(deleteAction, findsNothing);

    await tester.tap(question);
    await tester.pump();

    final material = tester.widget<Material>(header);
    final questionInkWell = tester.widget<InkWell>(question);
    final padding = tester.widget<Padding>(content);
    final answerPadding = tester.widget<Padding>(answerContent);
    expect(material.color, Colors.transparent);
    expect(material.borderRadius, isNull);
    expect(questionInkWell.splashColor, Colors.transparent);
    expect(questionInkWell.highlightColor, Colors.transparent);
    expect(
      padding.padding,
      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
    expect(answerPadding.padding, const EdgeInsets.only(top: 16, bottom: 18));
    expect(deleteAction, findsOneWidget);
  });

  testWidgets('confirms deletion from the expanded answer action', (
    tester,
  ) async {
    final repository = _FakeDirectQuestionRepository(
      history: _history(questions: [_latestQuestion]),
    );
    await _pump(tester, repository);

    await tester.tap(
      find.byKey(const Key('ai-direct-history-question-latest-question')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const Key('ai-direct-history-delete-latest-question')),
    );
    await tester.pumpAndSettle();

    expect(find.text('질문을 삭제할까요?'), findsOneWidget);
    expect(repository.deletedQuestionIds, isEmpty);

    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(repository.deletedQuestionIds, isEmpty);

    await tester.tap(
      find.byKey(const Key('ai-direct-history-delete-latest-question')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제'));
    await tester.pump();
    await tester.pump();

    expect(repository.deletedQuestionIds, ['latest-question']);
    expect(
      find.byKey(const Key('ai-direct-history-question-latest-question')),
      findsNothing,
    );
  });

  testWidgets('opens the delete confirmation by long pressing a question', (
    tester,
  ) async {
    await _pump(
      tester,
      _FakeDirectQuestionRepository(
        history: _history(questions: [_latestQuestion]),
      ),
    );

    await tester.longPress(
      find.byKey(const Key('ai-direct-history-question-latest-question')),
    );
    await tester.pumpAndSettle();

    expect(find.text('질문을 삭제할까요?'), findsOneWidget);
    expect(find.text('취소'), findsOneWidget);
    expect(find.text('삭제'), findsOneWidget);
  });

  testWidgets('shows an empty state when there is no question history', (
    tester,
  ) async {
    await _pump(tester, _FakeDirectQuestionRepository(history: _history()));

    expect(_wordBoundaryText('아직 지난 질문은 없어'), findsOneWidget);
  });

  testWidgets('wraps history without overflow at a large text size', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pump(
      tester,
      _FakeDirectQuestionRepository(
        history: _history(questions: [_latestQuestion, _pastQuestion]),
      ),
      textScaleFactor: 1.8,
    );

    expect(tester.takeException(), isNull);
  });
}

Finder _wordBoundaryText(String text) {
  return find.byWidgetPredicate(
    (widget) => widget is WordBoundaryText && widget.text == text,
  );
}

Future<void> _pump(
  WidgetTester tester,
  AiDirectQuestionRepository repository, {
  double textScaleFactor = 1,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        aiDirectQuestionRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScaleFactor)),
          child: child!,
        ),
        home: const Scaffold(body: AiDirectQuestionScreen()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

AiDirectQuestionHistory _history({
  List<AiDirectQuestionEntry> questions = const [],
}) {
  return AiDirectQuestionHistory(
    dailyLimit: 3,
    remainingCount: 2,
    questions: questions,
  );
}

final _latestQuestion = AiDirectQuestionEntry(
  id: 'latest-question',
  questionText: '최근 질문',
  status: AiDirectQuestionStatus.completed,
  answerText: '최근 답변',
  failureCode: null,
  createdAt: DateTime.utc(2026, 7, 24),
  answeredAt: DateTime.utc(2026, 7, 24, 0, 1),
);

final _pastQuestion = AiDirectQuestionEntry(
  id: 'past-question',
  questionText: '지난 질문 내용',
  status: AiDirectQuestionStatus.completed,
  answerText: '지난 답변',
  failureCode: null,
  createdAt: DateTime.utc(2026, 7, 23),
  answeredAt: DateTime.utc(2026, 7, 23, 0, 1),
);

class _FakeDirectQuestionRepository implements AiDirectQuestionRepository {
  _FakeDirectQuestionRepository({required this.history});

  AiDirectQuestionHistory history;
  final List<String> deletedQuestionIds = [];

  @override
  Future<void> deleteQuestion(String questionId) async {
    deletedQuestionIds.add(questionId);
    history = AiDirectQuestionHistory(
      dailyLimit: history.dailyLimit,
      remainingCount: history.remainingCount,
      questions: history.questions
          .where((question) => question.id != questionId)
          .toList(growable: false),
    );
  }

  @override
  Future<AiDirectQuestionHistory> fetchHistory() async => history;

  @override
  Future<void> submitQuestion(String questionText) async {}
}
