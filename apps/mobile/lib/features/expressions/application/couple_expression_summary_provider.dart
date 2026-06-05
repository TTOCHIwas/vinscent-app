import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/date/app_date_policy.dart';
import '../data/couple_expression_repository.dart';
import '../data/couple_expression_summary.dart';

final coupleExpressionSummaryProvider = FutureProvider.autoDispose
    .family<List<CoupleExpressionSummary>, DateTime>((ref, date) {
      final repository = ref.watch(coupleExpressionRepositoryProvider);
      return repository.fetchSummaryByDate(calendarDateOnly(date));
    }, retry: (_, _) => null);
