import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import 'ai_direct_question_history.dart';
import 'ai_learning_failure.dart';

final aiDirectQuestionRepositoryProvider = Provider<AiDirectQuestionRepository>(
  (ref) => const SupabaseAiDirectQuestionRepository(),
);

abstract interface class AiDirectQuestionRepository {
  Future<AiDirectQuestionHistory> fetchHistory();

  Future<void> submitQuestion(String questionText);

  Future<void> deleteQuestion(String questionId);
}

class SupabaseAiDirectQuestionRepository implements AiDirectQuestionRepository {
  const SupabaseAiDirectQuestionRepository();

  @override
  Future<AiDirectQuestionHistory> fetchHistory() async {
    final data = await _rpc('get_my_ai_user_questions');
    return _parseHistory(data);
  }

  @override
  Future<void> submitQuestion(String questionText) async {
    await _rpc(
      'submit_ai_user_question',
      params: {'requested_question_text': questionText},
    );
  }

  @override
  Future<void> deleteQuestion(String questionId) async {
    await _rpc(
      'delete_my_ai_user_question',
      params: {'requested_question_id': questionId},
    );
  }

  Future<Object?> _rpc(
    String functionName, {
    Map<String, Object?>? params,
  }) async {
    if (!AppConfig.isSupabaseConfigured) {
      throw const AiLearningRepositoryException(
        AiLearningFailureReason.configMissing,
      );
    }

    try {
      return await Supabase.instance.client
          .rpc(functionName, params: params)
          .timeout(AppConfig.supabaseRpcTimeout);
    } on TimeoutException {
      throw const AiLearningRepositoryException(
        AiLearningFailureReason.requestTimeout,
      );
    } on PostgrestException catch (error) {
      throw AiLearningRepositoryException(
        _reasonFromMessage(error.message),
        error.message,
      );
    }
  }

  AiDirectQuestionHistory _parseHistory(Object? data) {
    try {
      if (data is Map<String, dynamic>) {
        return AiDirectQuestionHistory.fromJson(data);
      }
      if (data is Map) {
        return AiDirectQuestionHistory.fromJson(
          Map<String, dynamic>.from(data),
        );
      }
      throw const FormatException('Invalid direct question history');
    } on FormatException catch (error) {
      throw AiLearningRepositoryException(
        AiLearningFailureReason.invalidResponse,
        error.message,
      );
    }
  }

  AiLearningFailureReason _reasonFromMessage(String message) {
    return switch (message) {
      'auth_required' => AiLearningFailureReason.authRequired,
      'active_couple_required' => AiLearningFailureReason.activeCoupleRequired,
      'ai_personalization_not_ready' =>
        AiLearningFailureReason.personalizationNotReady,
      'question_required' => AiLearningFailureReason.questionRequired,
      'question_too_long' => AiLearningFailureReason.questionTooLong,
      'ai_daily_question_limit_reached' =>
        AiLearningFailureReason.dailyQuestionLimitReached,
      'ai_sensitive_question_not_available' =>
        AiLearningFailureReason.sensitiveQuestionNotAvailable,
      'invalid_ai_user_question' => AiLearningFailureReason.invalidUserQuestion,
      _ => AiLearningFailureReason.unknown,
    };
  }
}
