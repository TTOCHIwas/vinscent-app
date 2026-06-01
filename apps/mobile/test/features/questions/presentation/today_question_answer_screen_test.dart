import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/questions/application/today_question_controller.dart';
import 'package:vinscent/features/questions/data/daily_question.dart';
import 'package:vinscent/features/questions/data/daily_question_answer_repository.dart';
import 'package:vinscent/features/questions/data/daily_question_answer_state.dart';
import 'package:vinscent/features/questions/presentation/today_question_answer_screen.dart';

void main() {
  testWidgets('shows question and disables submit for blank answer', (
    tester,
  ) async {
    final repository = _FakeDailyQuestionAnswerRepository(_emptyAnswerState);

    await _pumpScreen(tester, repository: repository);

    expect(find.text('today question'), findsOneWidget);
    expect(find.text('아직 답변하지 않았어요'), findsOneWidget);
    expect(find.text('0 / 500'), findsOneWidget);

    await tester.tap(find.text('답변 저장'));
    await tester.pump();

    expect(repository.submitCallCount, 0);
  });

  testWidgets('submits valid answer', (tester) async {
    final repository = _FakeDailyQuestionAnswerRepository(
      _emptyAnswerState,
      submittedState: _submittedAnswerState,
    );

    await _pumpScreen(tester, repository: repository);

    await tester.enterText(find.byType(TextField), 'hello');
    await tester.pump();

    expect(find.text('5 / 500'), findsOneWidget);

    await tester.tap(find.text('답변 저장'));
    await tester.pumpAndSettle();

    expect(repository.submitCallCount, 1);
    expect(repository.submittedAnswers, ['hello']);
    expect(find.text('내 답변이 저장됐어요. 상대방을 기다리는 중이에요'), findsOneWidget);
  });

  testWidgets('keeps draft and shows inline error when submit fails', (
    tester,
  ) async {
    final repository = _FakeDailyQuestionAnswerRepository(
      _emptyAnswerState,
      submittedState: _submittedAnswerState,
      submitFailuresBeforeSuccess: 1,
    );

    await _pumpScreen(tester, repository: repository);

    await tester.enterText(find.byType(TextField), 'hello');
    await tester.pump();

    await tester.tap(find.text('답변 저장'));
    await tester.pumpAndSettle();

    expect(repository.submitCallCount, 1);
    expect(repository.submittedAnswers, ['hello']);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      'hello',
    );
    expect(find.text('답변을 저장하지 못했어요. 잠시 후 다시 시도해 주세요.'), findsOneWidget);

    await tester.tap(find.text('답변 저장'));
    await tester.pumpAndSettle();

    expect(repository.submitCallCount, 2);
    expect(repository.submittedAnswers, ['hello', 'hello']);
    expect(find.text('답변을 저장하지 못했어요. 잠시 후 다시 시도해 주세요.'), findsNothing);
    expect(find.text('내 답변이 저장됐어요. 상대방을 기다리는 중이에요'), findsOneWidget);
  });

  testWidgets('disables submit when answer is too long', (tester) async {
    final repository = _FakeDailyQuestionAnswerRepository(_emptyAnswerState);

    await _pumpScreen(tester, repository: repository);

    await tester.enterText(find.byType(TextField), 'a' * 501);
    await tester.pump();

    expect(find.text('501 / 500'), findsOneWidget);

    await tester.tap(find.text('답변 저장'));
    await tester.pump();

    expect(repository.submitCallCount, 0);
  });

  testWidgets('shows existing answer as editable', (tester) async {
    final repository = _FakeDailyQuestionAnswerRepository(
      _submittedAnswerState,
    );

    await _pumpScreen(tester, repository: repository);

    expect(find.text('hello'), findsOneWidget);
    expect(find.text('답변 수정'), findsOneWidget);
  });
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required DailyQuestionAnswerRepository repository,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        todayQuestionControllerProvider.overrideWithBuild(
          (ref, notifier) async => _dailyQuestion,
        ),
        dailyQuestionAnswerRepositoryProvider.overrideWithValue(repository),
      ],
      child: const MaterialApp(
        home: Scaffold(body: TodayQuestionAnswerScreen()),
      ),
    ),
  );

  await tester.pumpAndSettle();
}

class _FakeDailyQuestionAnswerRepository
    implements DailyQuestionAnswerRepository {
  _FakeDailyQuestionAnswerRepository(
    this.initialState, {
    DailyQuestionAnswerState? submittedState,
    this.submitFailuresBeforeSuccess = 0,
  }) : submittedState = submittedState ?? initialState,
       currentState = initialState;

  final DailyQuestionAnswerState initialState;
  final DailyQuestionAnswerState submittedState;
  int submitFailuresBeforeSuccess;
  DailyQuestionAnswerState currentState;
  final submittedAnswers = <String>[];
  var submitCallCount = 0;

  @override
  Future<DailyQuestionAnswerState> fetchTodayAnswerState() async {
    return currentState;
  }

  @override
  Future<DailyQuestionAnswerState> submitTodayAnswer(String answerText) async {
    submitCallCount += 1;
    submittedAnswers.add(answerText);
    if (submitFailuresBeforeSuccess > 0) {
      submitFailuresBeforeSuccess -= 1;
      throw Exception('submit failed');
    }

    currentState = submittedState;
    return submittedState;
  }
}

final _dailyQuestion = DailyQuestion(
  dailyQuestionId: 'daily-question-id',
  coupleId: 'couple-id',
  questionId: 'question-id',
  questionText: 'today question',
  questionSource: QuestionSource.curated,
  questionCategory: 'daily',
  questionMood: 'warm',
  assignedDate: DateTime(2026, 5, 31),
  status: DailyQuestionStatus.pending,
);

const _emptyAnswerState = DailyQuestionAnswerState(
  dailyQuestionId: 'daily-question-id',
  status: DailyQuestionStatus.pending,
  partnerAnswerExists: false,
  answerCount: 0,
);

const _submittedAnswerState = DailyQuestionAnswerState(
  dailyQuestionId: 'daily-question-id',
  status: DailyQuestionStatus.answeredByOne,
  myAnswerId: 'answer-id',
  myAnswerText: 'hello',
  partnerAnswerExists: false,
  answerCount: 1,
);
