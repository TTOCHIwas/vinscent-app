import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/core/date/today_controller.dart';
import 'package:vinscent/features/couple/application/couple_controller.dart';
import 'package:vinscent/features/couple/data/couple.dart';
import 'package:vinscent/features/questions/application/question_answer_submit_controller.dart';
import 'package:vinscent/features/questions/data/daily_question.dart';
import 'package:vinscent/features/questions/data/daily_question_answer_failure.dart';
import 'package:vinscent/features/questions/data/daily_question_answer_repository.dart';
import 'package:vinscent/features/questions/data/daily_question_answer_state.dart';
import 'package:vinscent/features/questions/data/daily_question_detail_snapshot.dart';
import 'package:vinscent/features/questions/data/daily_question_read_repository.dart';

import '../../../support/couple_fixtures.dart';
import '../../../support/story_loop_fixtures.dart';

void main() {
  final today = DateTime(2026, 7, 6);

  test(
    'submits the writable daily question without requiring a story loop',
    () async {
      final repository = _FakeDailyQuestionAnswerRepository(_submittedState);
      final container = _container(
        today: today,
        repository: repository,
        detail: _snapshot(today: today, answerState: _emptyState),
      );
      addTearDown(container.dispose);

      final answerState = await container
          .read(questionAnswerSubmitControllerProvider.notifier)
          .submit(targetDate: today, answerText: 'answer');

      expect(answerState, _submittedState);
      expect(repository.submittedQuestionIds, ['daily-question-id']);
      expect(repository.submittedAnswers, ['answer']);
    },
  );

  test('resolves a null target through the current open question', () async {
    final carriedDate = today.subtract(const Duration(days: 3));
    final repository = _FakeDailyQuestionAnswerRepository(_submittedState);
    final readRepository = _FakeDailyQuestionReadRepository(
      _snapshot(today: carriedDate, answerState: _emptyState),
    );
    final container = _container(
      today: today,
      repository: repository,
      readRepository: readRepository,
      detail: _snapshot(today: carriedDate, answerState: _emptyState),
    );
    addTearDown(container.dispose);

    await container
        .read(questionAnswerSubmitControllerProvider.notifier)
        .submit(targetDate: null, answerText: 'carried answer');

    expect(readRepository.requestedDates, [null]);
    expect(repository.submittedQuestionIds, ['daily-question-id']);
  });

  test('rejects submission when the daily question is not writable', () async {
    final repository = _FakeDailyQuestionAnswerRepository(_submittedState);
    final container = _container(
      today: today,
      repository: repository,
      detail: _snapshot(
        today: today,
        answerState: _emptyState,
        canAnswerQuestion: false,
      ),
    );
    addTearDown(container.dispose);

    await expectLater(
      container
          .read(questionAnswerSubmitControllerProvider.notifier)
          .submit(targetDate: today, answerText: 'answer'),
      throwsA(
        isA<DailyQuestionAnswerRepositoryException>().having(
          (error) => error.reason,
          'reason',
          DailyQuestionAnswerFailureReason.questionNotReady,
        ),
      ),
    );

    expect(repository.submittedQuestionIds, isEmpty);
  });

  test('rejects submission after both partners have answered', () async {
    final repository = _FakeDailyQuestionAnswerRepository(_submittedState);
    final container = _container(
      today: today,
      repository: repository,
      detail: _snapshot(
        today: today,
        answerState: _completedState,
        questionStatus: DailyQuestionStatus.completed,
      ),
    );
    addTearDown(container.dispose);

    await expectLater(
      container
          .read(questionAnswerSubmitControllerProvider.notifier)
          .submit(targetDate: today, answerText: 'edited answer'),
      throwsA(
        isA<DailyQuestionAnswerRepositoryException>().having(
          (error) => error.reason,
          'reason',
          DailyQuestionAnswerFailureReason.questionNotReady,
        ),
      ),
    );

    expect(repository.submittedQuestionIds, isEmpty);
    expect(repository.submittedAnswers, isEmpty);
  });
}

ProviderContainer _container({
  required DateTime today,
  required DailyQuestionAnswerRepository repository,
  required DailyQuestionDetailSnapshot detail,
  DailyQuestionReadRepository? readRepository,
}) {
  return ProviderContainer(
    overrides: [
      todayControllerProvider.overrideWithBuild((ref, notifier) => today),
      coupleControllerProvider.overrideWithBuild(
        (ref, notifier) async => activeCouple(currentDate: today),
      ),
      dailyQuestionReadRepositoryProvider.overrideWithValue(
        readRepository ?? _FakeDailyQuestionReadRepository(detail),
      ),
      dailyQuestionAnswerRepositoryProvider.overrideWithValue(repository),
    ],
  );
}

DailyQuestionDetailSnapshot _snapshot({
  required DateTime today,
  required DailyQuestionAnswerState answerState,
  DailyQuestionStatus questionStatus = DailyQuestionStatus.pending,
  bool canAnswerQuestion = true,
}) {
  return DailyQuestionDetailSnapshot(
    coupleId: 'couple-id',
    coupleDate: today,
    accessMode: CoupleAccessMode.active,
    canAnswerQuestion: canAnswerQuestion,
    question: sampleDailyQuestion(assignedDate: today, status: questionStatus),
    answerState: answerState,
  );
}

class _FakeDailyQuestionReadRepository implements DailyQuestionReadRepository {
  _FakeDailyQuestionReadRepository(this.detail);

  final DailyQuestionDetailSnapshot? detail;
  final requestedDates = <DateTime?>[];

  @override
  Future<DailyQuestionDetailSnapshot?> fetchDetail(DateTime? date) async {
    requestedDates.add(date);
    return detail;
  }
}

class _FakeDailyQuestionAnswerRepository
    implements DailyQuestionAnswerRepository {
  _FakeDailyQuestionAnswerRepository(this.submittedState);

  final DailyQuestionAnswerState submittedState;
  final submittedQuestionIds = <String>[];
  final submittedAnswers = <String>[];

  @override
  Future<DailyQuestionAnswerState> submitDailyQuestionAnswer({
    required String dailyQuestionId,
    required String answerText,
  }) async {
    submittedQuestionIds.add(dailyQuestionId);
    submittedAnswers.add(answerText);
    return submittedState;
  }
}

const _submittedState = DailyQuestionAnswerState(
  dailyQuestionId: 'daily-question-id',
  status: DailyQuestionStatus.answeredByOne,
  myAnswerId: 'answer-id',
  myAnswerText: 'answer',
  partnerAnswerExists: false,
  answerCount: 1,
);

const _emptyState = DailyQuestionAnswerState(
  dailyQuestionId: 'daily-question-id',
  status: DailyQuestionStatus.pending,
  partnerAnswerExists: false,
  answerCount: 0,
);

const _completedState = DailyQuestionAnswerState(
  dailyQuestionId: 'daily-question-id',
  status: DailyQuestionStatus.completed,
  myAnswerId: 'my-answer-id',
  myAnswerText: 'my answer',
  partnerAnswerExists: true,
  partnerAnswerId: 'partner-answer-id',
  partnerAnswerText: 'partner answer',
  answerCount: 2,
);
