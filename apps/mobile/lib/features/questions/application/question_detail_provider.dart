import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/date/app_date_policy.dart';
import '../../../core/date/today_controller.dart';
import '../../couple/application/couple_controller.dart';
import '../data/question_detail_state.dart';
import 'daily_question_detail_provider.dart';

final questionDetailProvider = FutureProvider.autoDispose
    .family<QuestionDetailState, DateTime?>((ref, targetDate) async {
      final fallbackToday = calendarDateOnly(
        ref.watch(todayControllerProvider),
      );
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

      final snapshot = await ref.watch(
        dailyQuestionDetailProvider(
          targetDate == null ? null : normalizedTargetDate,
        ).future,
      );
      if (snapshot == null) {
        return UnavailableQuestionDetailState(
          reason: QuestionDetailUnavailableReason.noQuestion,
          targetDate: normalizedTargetDate,
        );
      }

      return LoadedQuestionDetailState(
        question: snapshot.question,
        answerState: snapshot.answerState,
        canEdit:
            snapshot.canAnswerQuestion && !snapshot.answerState.hasBothAnswers,
      );
    }, retry: (_, _) => null);
