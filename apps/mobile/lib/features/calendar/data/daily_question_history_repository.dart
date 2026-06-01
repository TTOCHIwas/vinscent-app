import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import 'daily_question_history_entry.dart';
import 'daily_question_history_failure.dart';

final dailyQuestionHistoryRepositoryProvider =
    Provider<DailyQuestionHistoryRepository>((ref) {
      return const SupabaseDailyQuestionHistoryRepository();
    });

abstract interface class DailyQuestionHistoryRepository {
  Future<DailyQuestionHistoryEntry?> fetchByDate(DateTime date);
}

class SupabaseDailyQuestionHistoryRepository
    implements DailyQuestionHistoryRepository {
  const SupabaseDailyQuestionHistoryRepository();

  @override
  Future<DailyQuestionHistoryEntry?> fetchByDate(DateTime date) async {
    if (!AppConfig.isSupabaseConfigured) {
      throw const DailyQuestionHistoryRepositoryException(
        DailyQuestionHistoryFailureReason.configMissing,
      );
    }

    try {
      final data = await Supabase.instance.client.rpc(
        'get_daily_question_answer_state_for_date',
        params: {'target_date': _formatDate(date)},
      );
      final row = _asOptionalRow(data);

      return row == null ? null : DailyQuestionHistoryEntry.fromJson(row);
    } on PostgrestException catch (error) {
      throw _mapPostgrestError(error);
    }
  }

  Map<String, dynamic>? _asOptionalRow(Object? data) {
    if (data == null) {
      return null;
    }

    if (data is Map<String, dynamic>) {
      return data;
    }

    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }

    if (data is List) {
      if (data.isEmpty) {
        return null;
      }

      final first = data.first;
      if (first is Map<String, dynamic>) {
        return first;
      }

      if (first is Map) {
        return Map<String, dynamic>.from(first);
      }
    }

    throw const DailyQuestionHistoryRepositoryException(
      DailyQuestionHistoryFailureReason.unknown,
    );
  }

  DailyQuestionHistoryRepositoryException _mapPostgrestError(
    PostgrestException error,
  ) {
    return DailyQuestionHistoryRepositoryException(
      _reasonFromMessage(error.message),
      error.message,
    );
  }

  DailyQuestionHistoryFailureReason _reasonFromMessage(String message) {
    return switch (message) {
      'auth_required' => DailyQuestionHistoryFailureReason.authRequired,
      'active_couple_required' =>
        DailyQuestionHistoryFailureReason.activeCoupleRequired,
      'relationship_date_required' =>
        DailyQuestionHistoryFailureReason.relationshipDateRequired,
      _ => DailyQuestionHistoryFailureReason.unknown,
    };
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
