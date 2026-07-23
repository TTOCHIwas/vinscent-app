import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import 'ai_focused_question_flow.dart';
import 'ai_focused_question_history_entry.dart';
import 'ai_learning_dashboard.dart';
import 'ai_learning_failure.dart';

const _aiConsentPolicyVersion = 'ai-learning-v1';

final aiLearningRepositoryProvider = Provider<AiLearningRepository>((ref) {
  return const SupabaseAiLearningRepository();
});

abstract interface class AiLearningRepository {
  Future<AiLearningDashboard> fetchDashboard();

  Future<void> setMyConsent({required bool granted});

  Future<void> confirmMemory({
    required String memoryId,
    required AiMemoryDecision decision,
  });

  Future<AiFocusedQuestionFlow> unlockFocusedQuestions();

  Future<AiFocusedQuestionFlow> fetchFocusedQuestionFlow();

  Future<List<AiFocusedQuestionHistoryEntry>> fetchFocusedQuestionHistory();

  Future<AiFocusedQuestionFlow> submitFocusedQuestionAnswer({
    required String questionId,
    required String answerText,
  });

  Future<AiQuestionFeedback?> fetchQuestionFeedback(String dailyQuestionId);
}

class SupabaseAiLearningRepository implements AiLearningRepository {
  const SupabaseAiLearningRepository();

  @override
  Future<AiLearningDashboard> fetchDashboard() async {
    final data = await _rpc('get_ai_learning_dashboard');

    try {
      return AiLearningDashboard.fromJson(_asRow(data));
    } on FormatException catch (error) {
      throw AiLearningRepositoryException(
        AiLearningFailureReason.invalidResponse,
        error.message,
      );
    }
  }

  @override
  Future<void> setMyConsent({required bool granted}) async {
    await _rpc(
      'set_my_ai_consent',
      params: {
        'requested_granted': granted,
        'requested_policy_version': _aiConsentPolicyVersion,
      },
    );
  }

  @override
  Future<void> confirmMemory({
    required String memoryId,
    required AiMemoryDecision decision,
  }) async {
    await _rpc(
      'confirm_ai_memory',
      params: {
        'requested_memory_id': memoryId,
        'requested_decision': decision.jsonValue,
      },
    );
  }

  @override
  Future<AiFocusedQuestionFlow> unlockFocusedQuestions() {
    return _focusedQuestionRpc('unlock_ai_focused_questions');
  }

  @override
  Future<AiFocusedQuestionFlow> fetchFocusedQuestionFlow() {
    return _focusedQuestionRpc('get_ai_focused_question_flow');
  }

  @override
  Future<List<AiFocusedQuestionHistoryEntry>>
  fetchFocusedQuestionHistory() async {
    final data = await _rpc('get_ai_focused_question_history');

    if (data is! List) {
      throw const AiLearningRepositoryException(
        AiLearningFailureReason.invalidResponse,
      );
    }

    try {
      return data
          .map(
            (entry) =>
                AiFocusedQuestionHistoryEntry.fromJson(_asHistoryRow(entry)),
          )
          .toList(growable: false);
    } on FormatException catch (error) {
      throw AiLearningRepositoryException(
        AiLearningFailureReason.invalidResponse,
        error.message,
      );
    }
  }

  @override
  Future<AiFocusedQuestionFlow> submitFocusedQuestionAnswer({
    required String questionId,
    required String answerText,
  }) {
    return _focusedQuestionRpc(
      'submit_ai_focused_question_answer',
      params: {
        'requested_question_id': questionId,
        'requested_answer_text': answerText,
      },
    );
  }

  @override
  Future<AiQuestionFeedback?> fetchQuestionFeedback(
    String dailyQuestionId,
  ) async {
    final data = await _rpc(
      'get_ai_question_feedback',
      params: {'requested_daily_question_id': dailyQuestionId},
    );

    if (data == null) {
      return null;
    }

    try {
      return AiQuestionFeedback.fromJson(_asRow(data));
    } on FormatException catch (error) {
      throw AiLearningRepositoryException(
        AiLearningFailureReason.invalidResponse,
        error.message,
      );
    }
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

  Future<AiFocusedQuestionFlow> _focusedQuestionRpc(
    String functionName, {
    Map<String, Object?>? params,
  }) async {
    final data = await _rpc(functionName, params: params);

    try {
      return AiFocusedQuestionFlow.fromJson(_asRow(data));
    } on FormatException catch (error) {
      throw AiLearningRepositoryException(
        AiLearningFailureReason.invalidResponse,
        error.message,
      );
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

    throw const AiLearningRepositoryException(
      AiLearningFailureReason.invalidResponse,
    );
  }

  Map<String, dynamic> _asHistoryRow(Object? data) {
    if (data is Map<String, dynamic>) {
      return data;
    }

    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }

    throw const FormatException('Invalid focused question history entry');
  }

  AiLearningFailureReason _reasonFromMessage(String message) {
    return switch (message) {
      'auth_required' => AiLearningFailureReason.authRequired,
      'active_couple_required' => AiLearningFailureReason.activeCoupleRequired,
      'ai_consent_required' => AiLearningFailureReason.consentRequired,
      'ai_memory_not_found' => AiLearningFailureReason.memoryNotFound,
      'ai_memory_confirmation_forbidden' =>
        AiLearningFailureReason.memoryConfirmationForbidden,
      'ai_memory_review_not_ready' =>
        AiLearningFailureReason.memoryReviewNotReady,
      'ai_memory_already_reviewed' =>
        AiLearningFailureReason.memoryAlreadyReviewed,
      'ai_personalization_not_ready' =>
        AiLearningFailureReason.personalizationNotReady,
      'ai_curriculum_unavailable' =>
        AiLearningFailureReason.curriculumUnavailable,
      'ai_focused_questions_locked' =>
        AiLearningFailureReason.focusedQuestionsLocked,
      'answer_required' => AiLearningFailureReason.answerRequired,
      'answer_too_long' => AiLearningFailureReason.answerTooLong,
      'question_not_ready' => AiLearningFailureReason.questionNotReady,
      'invalid_daily_question' => AiLearningFailureReason.invalidQuestion,
      _ => AiLearningFailureReason.unknown,
    };
  }
}
