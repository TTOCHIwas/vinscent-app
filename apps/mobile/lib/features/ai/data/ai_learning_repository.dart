import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
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
      'invalid_daily_question' => AiLearningFailureReason.invalidQuestion,
      _ => AiLearningFailureReason.unknown,
    };
  }
}
