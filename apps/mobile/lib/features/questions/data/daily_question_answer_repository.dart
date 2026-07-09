import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import 'daily_question_answer_failure.dart';
import 'daily_question_answer_state.dart';

final dailyQuestionAnswerRepositoryProvider =
    Provider<DailyQuestionAnswerRepository>((ref) {
      return const SupabaseDailyQuestionAnswerRepository();
    });

abstract interface class DailyQuestionAnswerRepository {
  Future<DailyQuestionAnswerState> submitStoryLoopAnswer({
    required String dailyQuestionId,
    required String answerText,
  });
}

class SupabaseDailyQuestionAnswerRepository
    implements DailyQuestionAnswerRepository {
  const SupabaseDailyQuestionAnswerRepository();

  @override
  Future<DailyQuestionAnswerState> submitStoryLoopAnswer({
    required String dailyQuestionId,
    required String answerText,
  }) async {
    return _submitAnswer(
      functionName: 'submit_story_loop_question_answer',
      params: {
        'expected_daily_question_id': dailyQuestionId,
        'answer_text': answerText,
      },
    );
  }

  Future<DailyQuestionAnswerState> _submitAnswer({
    required String functionName,
    required Map<String, Object?> params,
  }) async {
    if (!AppConfig.isSupabaseConfigured) {
      throw const DailyQuestionAnswerRepositoryException(
        DailyQuestionAnswerFailureReason.configMissing,
      );
    }

    try {
      final data = await Supabase.instance.client
          .rpc(functionName, params: params)
          .timeout(AppConfig.supabaseRpcTimeout);

      return DailyQuestionAnswerState.fromJson(_asRow(data));
    } on TimeoutException {
      throw const DailyQuestionAnswerRepositoryException(
        DailyQuestionAnswerFailureReason.requestTimeout,
      );
    } on PostgrestException catch (error) {
      throw _mapPostgrestError(error);
    }
  }

  Map<String, dynamic> _asRow(Object? data) {
    if (data is Map<String, dynamic>) {
      return data;
    }

    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }

    if (data is List && data.isNotEmpty) {
      final first = data.first;
      if (first is Map<String, dynamic>) {
        return first;
      }

      if (first is Map) {
        return Map<String, dynamic>.from(first);
      }
    }

    throw const DailyQuestionAnswerRepositoryException(
      DailyQuestionAnswerFailureReason.unknown,
    );
  }

  DailyQuestionAnswerRepositoryException _mapPostgrestError(
    PostgrestException error,
  ) {
    return DailyQuestionAnswerRepositoryException(
      _reasonFromMessage(error.message),
      error.message,
    );
  }

  DailyQuestionAnswerFailureReason _reasonFromMessage(String message) {
    return switch (message) {
      'auth_required' => DailyQuestionAnswerFailureReason.authRequired,
      'active_couple_required' =>
        DailyQuestionAnswerFailureReason.activeCoupleRequired,
      'relationship_date_required' =>
        DailyQuestionAnswerFailureReason.relationshipDateRequired,
      'question_pool_empty' =>
        DailyQuestionAnswerFailureReason.questionPoolEmpty,
      'question_assignment_failed' =>
        DailyQuestionAnswerFailureReason.questionAssignmentFailed,
      'question_not_ready' => DailyQuestionAnswerFailureReason.questionNotReady,
      'answer_required' => DailyQuestionAnswerFailureReason.answerRequired,
      'answer_too_long' => DailyQuestionAnswerFailureReason.answerTooLong,
      _ => DailyQuestionAnswerFailureReason.unknown,
    };
  }
}
