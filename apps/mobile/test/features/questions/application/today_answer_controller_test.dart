import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/questions/application/today_answer_controller.dart';
import 'package:vinscent/features/questions/application/today_question_controller.dart';
import 'package:vinscent/features/questions/data/daily_question.dart';
import 'package:vinscent/features/questions/data/daily_question_answer_repository.dart';
import 'package:vinscent/features/questions/data/daily_question_answer_state.dart';

void main() {
  test('does not fetch answer state before today question is ready', () async {
    final repository = _FakeDailyQuestionAnswerRepository(_answerState);
    final container = _container(question: null, repository: repository);
    addTearDown(container.dispose);

    final answerState = await container.read(
      todayAnswerControllerProvider.future,
    );

    expect(answerState, isNull);
    expect(repository.fetchCallCount, 0);
  });

  test('fetches answer state when today question is ready', () async {
    final repository = _FakeDailyQuestionAnswerRepository(_answerState);
    final container = _container(
      question: _dailyQuestion,
      repository: repository,
    );
    addTearDown(container.dispose);

    final answerState = await container.read(
      todayAnswerControllerProvider.future,
    );

    expect(answerState, _answerState);
    expect(repository.fetchCallCount, 1);
  });

  test('does not submit before today question is ready', () async {
    final repository = _FakeDailyQuestionAnswerRepository(_answerState);
    final container = _container(question: null, repository: repository);
    addTearDown(container.dispose);

    await container
        .read(todayAnswerControllerProvider.notifier)
        .submit('answer');

    expect(repository.submitCallCount, 0);
    expect(container.read(todayAnswerControllerProvider).value, isNull);
  });

  test('submits answer and updates state', () async {
    final repository = _FakeDailyQuestionAnswerRepository(_submittedState);
    final container = _container(
      question: _dailyQuestion,
      repository: repository,
    );
    addTearDown(container.dispose);

    await container
        .read(todayAnswerControllerProvider.notifier)
        .submit('answer');

    final state = container.read(todayAnswerControllerProvider).value;
    expect(repository.submitCallCount, 1);
    expect(repository.submittedAnswers, ['answer']);
    expect(state, _submittedState);
  });
}

ProviderContainer _container({
  required DailyQuestion? question,
  required DailyQuestionAnswerRepository repository,
}) {
  return ProviderContainer(
    overrides: [
      todayQuestionControllerProvider.overrideWithBuild(
        (ref, notifier) async => question,
      ),
      dailyQuestionAnswerRepositoryProvider.overrideWithValue(repository),
    ],
  );
}

class _FakeDailyQuestionAnswerRepository
    implements DailyQuestionAnswerRepository {
  _FakeDailyQuestionAnswerRepository(this.state);

  final DailyQuestionAnswerState state;
  final submittedAnswers = <String>[];
  var fetchCallCount = 0;
  var submitCallCount = 0;

  @override
  Future<DailyQuestionAnswerState> fetchTodayAnswerState() async {
    fetchCallCount += 1;
    return state;
  }

  @override
  Future<DailyQuestionAnswerState> submitTodayAnswer(String answerText) async {
    submitCallCount += 1;
    submittedAnswers.add(answerText);
    return state;
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

const _answerState = DailyQuestionAnswerState(
  dailyQuestionId: 'daily-question-id',
  status: DailyQuestionStatus.pending,
  partnerAnswerExists: false,
  answerCount: 0,
);

const _submittedState = DailyQuestionAnswerState(
  dailyQuestionId: 'daily-question-id',
  status: DailyQuestionStatus.answeredByOne,
  myAnswerId: 'answer-id',
  myAnswerText: 'answer',
  partnerAnswerExists: false,
  answerCount: 1,
);
