import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/core/date/today_controller.dart';
import 'package:vinscent/features/couple/application/couple_controller.dart';
import 'package:vinscent/features/couple/data/couple.dart';
import 'package:vinscent/features/questions/application/today_question_controller.dart';
import 'package:vinscent/features/questions/data/daily_question.dart';
import 'package:vinscent/features/questions/data/daily_question_repository.dart';

import '../../../support/couple_fixtures.dart';

void main() {
  test('does not fetch question before active couple is ready', () async {
    final repository = _FakeDailyQuestionRepository(_dailyQuestion);
    final container = _container(
      couple: _pendingCouple,
      repository: repository,
    );
    addTearDown(container.dispose);

    final question = await container.read(
      todayQuestionControllerProvider.future,
    );

    expect(question, isNull);
    expect(repository.callCount, 0);
  });

  test(
    'fetches question for active couple with relationship start date',
    () async {
      final repository = _FakeDailyQuestionRepository(_dailyQuestion);
      final container = _container(
        couple: _activeCouple,
        repository: repository,
      );
      addTearDown(container.dispose);

      final question = await container.read(
        todayQuestionControllerProvider.future,
      );

      expect(question, _dailyQuestion);
      expect(repository.callCount, 1);
    },
  );

  test('refetches when app date changes', () async {
    var today = DateTime(2026, 5, 31);
    final repository = _FakeDailyQuestionRepository(_dailyQuestion);
    final container = _container(
      couple: _activeCouple,
      repository: repository,
      todayProvider: (ref, notifier) => today,
    );
    addTearDown(container.dispose);

    await container.read(todayQuestionControllerProvider.future);
    expect(repository.callCount, 1);

    today = DateTime(2026, 6, 1);
    container.invalidate(todayControllerProvider);

    await container.read(todayQuestionControllerProvider.future);
    expect(repository.callCount, 2);
  });

  test('refresh reloads today question', () async {
    final repository = _FakeDailyQuestionRepository(_dailyQuestion);
    final container = _container(couple: _activeCouple, repository: repository);
    addTearDown(container.dispose);

    await container.read(todayQuestionControllerProvider.future);
    await container.read(todayQuestionControllerProvider.notifier).refresh();

    expect(repository.callCount, 2);
  });
}

ProviderContainer _container({
  required Couple? couple,
  required DailyQuestionRepository repository,
  DateTime Function(Ref ref, TodayController notifier)? todayProvider,
}) {
  return ProviderContainer(
    overrides: [
      coupleControllerProvider.overrideWithBuild(
        (ref, notifier) async => couple,
      ),
      todayControllerProvider.overrideWithBuild(
        todayProvider ?? (ref, notifier) => DateTime(2026, 5, 31),
      ),
      dailyQuestionRepositoryProvider.overrideWithValue(repository),
    ],
  );
}

class _FakeDailyQuestionRepository implements DailyQuestionRepository {
  _FakeDailyQuestionRepository(this.question);

  final DailyQuestion question;
  var callCount = 0;

  @override
  Future<DailyQuestion> fetchTodayQuestion() async {
    callCount += 1;
    return question;
  }
}

final _pendingCouple = pendingCouple();

final _activeCouple = activeCouple();

final _dailyQuestion = DailyQuestion(
  dailyQuestionId: 'daily-question-id',
  coupleId: 'couple-id',
  questionId: 'question-id',
  questionText: '오늘의 질문',
  questionSource: QuestionSource.curated,
  questionCategory: 'daily',
  questionMood: 'warm',
  assignedDate: DateTime(2026, 5, 31),
  status: DailyQuestionStatus.pending,
);
