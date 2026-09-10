import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../story_loops/application/story_loop_realtime_controller.dart';
import '../data/daily_question_detail_snapshot.dart';
import '../data/daily_question_read_repository.dart';

final dailyQuestionDetailProvider = FutureProvider.autoDispose
    .family<DailyQuestionDetailSnapshot?, DateTime?>((ref, date) async {
      ref.watch(dailyQuestionReadRevisionProvider);
      return ref.watch(dailyQuestionReadRepositoryProvider).fetchDetail(date);
    }, retry: (_, _) => null);

final todayDailyQuestionProvider =
    FutureProvider.autoDispose<DailyQuestionDetailSnapshot?>((ref) async {
      return ref.watch(dailyQuestionDetailProvider(null).future);
    }, retry: (_, _) => null);
