import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/date/app_date_policy.dart';
import '../../../core/date/today_controller.dart';
import '../../couple/application/couple_controller.dart';
import '../data/question_detail_state.dart';
import 'daily_question_history_provider.dart';
import 'today_answer_controller.dart';
import 'today_question_controller.dart';

final questionDetailProvider = FutureProvider.autoDispose
    .family<QuestionDetailState, DateTime?>((ref, targetDate) async {
      final fallbackToday = calendarDateOnly(ref.watch(todayControllerProvider));
      final couple = await ref.watch(coupleControllerProvider.future);
      final currentDate = calendarDateOnly(
        couple?.effectiveCurrentDate ?? fallbackToday,
      );
      final normalizedTargetDate = calendarDateOnly(targetDate ?? currentDate);

      if (couple == null ||
          !couple.canReadSharedData ||
          !couple.hasRelationshipStartDate) {
        return UnavailableQuestionDetailState(
          reason: QuestionDetailUnavailableReason.unavailable,
          targetDate: normalizedTargetDate,
        );
      }

      final relationshipStartDate = calendarDateOnly(
        couple.relationshipStartDate!,
      );
      if (normalizedTargetDate.isBefore(relationshipStartDate)) {
        return UnavailableQuestionDetailState(
          reason: QuestionDetailUnavailableReason.beforeRelationshipStartDate,
          targetDate: normalizedTargetDate,
        );
      }

      if (normalizedTargetDate.isAfter(currentDate)) {
        return UnavailableQuestionDetailState(
          reason: QuestionDetailUnavailableReason.futureDate,
          targetDate: normalizedTargetDate,
        );
      }

      final isEditableToday =
          couple.canEditSharedData &&
          _isSameCalendarDate(normalizedTargetDate, currentDate);

      if (isEditableToday) {
        final question = await ref.watch(todayQuestionControllerProvider.future);
        if (question == null) {
          return UnavailableQuestionDetailState(
            reason: QuestionDetailUnavailableReason.noQuestion,
            targetDate: normalizedTargetDate,
          );
        }

        final answerState = await ref.watch(
          todayAnswerControllerProvider.future,
        );
        return LoadedQuestionDetailState(
          question: question,
          answerState: answerState,
          canEdit: true,
        );
      }

      final historyEntry = await ref.watch(
        dailyQuestionHistoryProvider(normalizedTargetDate).future,
      );
      if (historyEntry == null) {
        return UnavailableQuestionDetailState(
          reason: QuestionDetailUnavailableReason.noQuestion,
          targetDate: normalizedTargetDate,
        );
      }

      return LoadedQuestionDetailState(
        question: historyEntry.question,
        answerState: historyEntry.answerState,
        canEdit: false,
      );
    }, retry: (_, _) => null);

bool _isSameCalendarDate(DateTime first, DateTime second) {
  return first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}
