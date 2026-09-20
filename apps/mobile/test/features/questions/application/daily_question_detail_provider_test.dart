import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/questions/application/daily_question_detail_provider.dart';
import 'package:vinscent/features/questions/data/daily_question_detail_snapshot.dart';
import 'package:vinscent/features/questions/data/daily_question_history_failure.dart';
import 'package:vinscent/features/questions/data/daily_question_read_repository.dart';

void main() {
  test('temporarily failed question reads retry and recover', () async {
    final repository = _FlakyDailyQuestionReadRepository(
      failuresBeforeSuccess: 2,
    );
    final container = ProviderContainer(
      overrides: [
        dailyQuestionReadRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      todayDailyQuestionProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    expect(await container.read(todayDailyQuestionProvider.future), isNull);
    expect(repository.callCount, 3);
  });

  test('non-recoverable question read failures do not retry', () async {
    final repository = _FlakyDailyQuestionReadRepository(
      failure: const DailyQuestionHistoryRepositoryException(
        DailyQuestionHistoryFailureReason.authRequired,
      ),
    );
    final container = ProviderContainer(
      overrides: [
        dailyQuestionReadRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      todayDailyQuestionProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    await expectLater(
      container.read(todayDailyQuestionProvider.future),
      throwsA(isA<DailyQuestionHistoryRepositoryException>()),
    );
    expect(repository.callCount, 1);
  });
}

class _FlakyDailyQuestionReadRepository implements DailyQuestionReadRepository {
  _FlakyDailyQuestionReadRepository({
    this.failuresBeforeSuccess = 0,
    this.failure = const DailyQuestionHistoryRepositoryException(
      DailyQuestionHistoryFailureReason.requestTimeout,
    ),
  });

  final int failuresBeforeSuccess;
  final Object failure;
  int callCount = 0;

  @override
  Future<DailyQuestionDetailSnapshot?> fetchDetail(DateTime? date) async {
    callCount += 1;
    if (callCount <= failuresBeforeSuccess || failuresBeforeSuccess == 0) {
      throw failure;
    }
    return null;
  }
}
