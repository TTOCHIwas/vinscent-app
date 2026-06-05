import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/date/app_date_policy.dart';
import '../../../core/date/today_controller.dart';
import '../../couple/application/couple_controller.dart';
import '../../couple/data/couple.dart';
import '../data/question_detail_navigation_state.dart';

final questionDetailNavigationProvider = FutureProvider.autoDispose
    .family<QuestionDetailNavigationState, DateTime?>((ref, targetDate) async {
      final today = calendarDateOnly(ref.watch(todayControllerProvider));
      final currentDate = calendarDateOnly(targetDate ?? today);

      final couple = await ref.watch(coupleControllerProvider.future);
      if (couple == null ||
          couple.status != CoupleStatus.active ||
          couple.relationshipStartDate == null) {
        return QuestionDetailNavigationState(currentDate: currentDate);
      }

      final relationshipStartDate = calendarDateOnly(
        couple.relationshipStartDate!,
      );
      final isWithinRange =
          !currentDate.isBefore(relationshipStartDate) &&
          !currentDate.isAfter(today);

      if (!isWithinRange) {
        return QuestionDetailNavigationState(currentDate: currentDate);
      }

      return QuestionDetailNavigationState(
        currentDate: currentDate,
        previousDate: currentDate.isAfter(relationshipStartDate)
            ? currentDate.subtract(const Duration(days: 1))
            : null,
        nextDate: currentDate.isBefore(today)
            ? currentDate.add(const Duration(days: 1))
            : null,
      );
    }, retry: (_, _) => null);
