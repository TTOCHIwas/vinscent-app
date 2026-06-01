import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import 'daily_question.dart';
import 'daily_question_failure.dart';

final dailyQuestionRepositoryProvider = Provider<DailyQuestionRepository>((
  ref,
) {
  return const SupabaseDailyQuestionRepository();
});

abstract interface class DailyQuestionRepository {
  Future<DailyQuestion> fetchTodayQuestion();
}

class SupabaseDailyQuestionRepository implements DailyQuestionRepository {
  const SupabaseDailyQuestionRepository();

  @override
  Future<DailyQuestion> fetchTodayQuestion() async {
    if (!AppConfig.isSupabaseConfigured) {
      throw const DailyQuestionRepositoryException(
        DailyQuestionFailureReason.configMissing,
      );
    }

    try {
      final data = await Supabase.instance.client
          .rpc('get_or_assign_today_question')
          .timeout(AppConfig.supabaseRpcTimeout);

      return DailyQuestion.fromJson(_asRow(data));
    } on TimeoutException {
      throw const DailyQuestionRepositoryException(
        DailyQuestionFailureReason.requestTimeout,
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

    throw const DailyQuestionRepositoryException(
      DailyQuestionFailureReason.unknown,
    );
  }

  DailyQuestionRepositoryException _mapPostgrestError(
    PostgrestException error,
  ) {
    return DailyQuestionRepositoryException(
      _reasonFromMessage(error.message),
      error.message,
    );
  }

  DailyQuestionFailureReason _reasonFromMessage(String message) {
    return switch (message) {
      'auth_required' => DailyQuestionFailureReason.authRequired,
      'active_couple_required' =>
        DailyQuestionFailureReason.activeCoupleRequired,
      'relationship_date_required' =>
        DailyQuestionFailureReason.relationshipDateRequired,
      'question_pool_empty' => DailyQuestionFailureReason.questionPoolEmpty,
      _ => DailyQuestionFailureReason.unknown,
    };
  }
}
