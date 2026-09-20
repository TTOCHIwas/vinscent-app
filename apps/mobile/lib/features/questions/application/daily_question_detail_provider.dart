import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../story_loops/application/story_loop_realtime_controller.dart';
import '../data/daily_question_detail_snapshot.dart';
import '../data/daily_question_history_failure.dart';
import '../data/daily_question_read_repository.dart';

const _dailyQuestionReadMaxRetries = 3;

Duration? _dailyQuestionReadRetryDelay(int retryCount, Object error) {
  if (retryCount >= _dailyQuestionReadMaxRetries || error is Error) {
    return null;
  }
  if (error is DailyQuestionHistoryRepositoryException &&
      error.reason != DailyQuestionHistoryFailureReason.requestTimeout &&
      error.reason != DailyQuestionHistoryFailureReason.unknown) {
    return null;
  }

  return Duration(milliseconds: 200 * (1 << retryCount));
}

final dailyQuestionDetailProvider = FutureProvider.autoDispose
    .family<DailyQuestionDetailSnapshot?, DateTime?>((ref, date) async {
      ref.watch(dailyQuestionReadRevisionProvider);
      return ref.watch(dailyQuestionReadRepositoryProvider).fetchDetail(date);
    }, retry: (_, _) => null);

final todayDailyQuestionProvider =
    FutureProvider.autoDispose<DailyQuestionDetailSnapshot?>((ref) async {
      ref.watch(dailyQuestionReadRevisionProvider);
      return ref.watch(dailyQuestionReadRepositoryProvider).fetchDetail(null);
    }, retry: _dailyQuestionReadRetryDelay);
