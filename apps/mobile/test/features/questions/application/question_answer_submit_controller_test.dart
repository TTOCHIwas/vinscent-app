import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/core/date/today_controller.dart';
import 'package:vinscent/features/couple/application/couple_controller.dart';
import 'package:vinscent/features/questions/application/question_answer_submit_controller.dart';
import 'package:vinscent/features/questions/data/daily_question.dart';
import 'package:vinscent/features/questions/data/daily_question_answer_failure.dart';
import 'package:vinscent/features/questions/data/daily_question_answer_repository.dart';
import 'package:vinscent/features/questions/data/daily_question_answer_state.dart';
import 'package:vinscent/features/story_loops/data/story_loop_detail.dart';
import 'package:vinscent/features/story_loops/data/story_loop_read_repository.dart';

import '../../../support/couple_fixtures.dart';
import '../../../support/story_loop_fixtures.dart';

void main() {
  final today = DateTime(2026, 7, 6);

  test('submits the daily question linked to the writable story loop', () async {
    final repository = _FakeDailyQuestionAnswerRepository(_submittedState);
    final container = _container(
      today: today,
      repository: repository,
      detail: sampleStoryLoopDetail(coupleDate: today),
    );
    addTearDown(container.dispose);

    final answerState = await container
        .read(questionAnswerSubmitControllerProvider.notifier)
        .submit(targetDate: today, answerText: 'answer');

    expect(answerState, _submittedState);
    expect(repository.submittedQuestionIds, ['daily-question-id']);
    expect(repository.submittedAnswers, ['answer']);
  });

  test('rejects submission when the story loop question is not writable', () async {
    final repository = _FakeDailyQuestionAnswerRepository(_submittedState);
    final container = _container(
      today: today,
      repository: repository,
      detail: sampleStoryLoopDetail(
        coupleDate: today,
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
}

ProviderContainer _container({
  required DateTime today,
  required DailyQuestionAnswerRepository repository,
  required StoryLoopDetail detail,
}) {
  return ProviderContainer(
    overrides: [
      todayControllerProvider.overrideWithBuild((ref, notifier) => today),
      coupleControllerProvider.overrideWithBuild(
        (ref, notifier) async => activeCouple(currentDate: today),
      ),
      storyLoopReadRepositoryProvider.overrideWithValue(
        FakeStoryLoopReadRepository(details: {today: detail}),
      ),
      dailyQuestionAnswerRepositoryProvider.overrideWithValue(repository),
    ],
  );
}

class _FakeDailyQuestionAnswerRepository
    implements DailyQuestionAnswerRepository {
  _FakeDailyQuestionAnswerRepository(this.submittedState);

  final DailyQuestionAnswerState submittedState;
  final submittedQuestionIds = <String>[];
  final submittedAnswers = <String>[];

  @override
  Future<DailyQuestionAnswerState> submitStoryLoopAnswer({
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
