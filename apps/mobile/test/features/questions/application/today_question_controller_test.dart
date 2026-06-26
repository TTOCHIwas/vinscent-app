import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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

  test('does not fetch question without relationship start date', () async {
    final repository = _FakeDailyQuestionRepository(_dailyQuestion);
    final container = _container(
      couple: _activeCoupleWithoutDate,
      repository: repository,
    );
    addTearDown(container.dispose);

    final question = await container.read(
      todayQuestionControllerProvider.future,
    );

    expect(question, isNull);
    expect(repository.callCount, 0);
  });

  test('does not fetch question for archived read only couple', () async {
    final repository = _FakeDailyQuestionRepository(_dailyQuestion);
    final container = _container(
      couple: _archivedReadOnlyCouple,
      repository: repository,
    );
    addTearDown(container.dispose);

    final question = await container.read(
      todayQuestionControllerProvider.future,
    );

    expect(question, isNull);
    expect(repository.callCount, 0);
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
}) {
  return ProviderContainer(
    overrides: [
      coupleControllerProvider.overrideWithBuild(
        (ref, notifier) async => couple,
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

final _activeCoupleWithoutDate = activeCoupleWithoutDate();

final _archivedReadOnlyCouple = archivedReadOnlyCouple();

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
