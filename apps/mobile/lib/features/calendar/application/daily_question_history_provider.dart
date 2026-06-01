import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/date/app_date_policy.dart';
import '../data/daily_question_history_entry.dart';
import '../data/daily_question_history_repository.dart';

final dailyQuestionHistoryProvider =
    FutureProvider.family<DailyQuestionHistoryEntry?, DateTime>((ref, date) {
      final repository = ref.watch(dailyQuestionHistoryRepositoryProvider);
      return repository.fetchByDate(calendarDateOnly(date));
    });
