import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import 'daily_question_detail_snapshot.dart';
import 'daily_question_history_failure.dart';

final dailyQuestionReadRepositoryProvider =
    Provider<DailyQuestionReadRepository>(
      (ref) => const SupabaseDailyQuestionReadRepository(),
    );

abstract interface class DailyQuestionReadRepository {
  Future<DailyQuestionDetailSnapshot?> fetchDetail(DateTime? date);
}

class SupabaseDailyQuestionReadRepository
    implements DailyQuestionReadRepository {
  const SupabaseDailyQuestionReadRepository();

  @override
  Future<DailyQuestionDetailSnapshot?> fetchDetail(DateTime? date) async {
    if (!AppConfig.isSupabaseConfigured) {
      throw const DailyQuestionHistoryRepositoryException(
        DailyQuestionHistoryFailureReason.configMissing,
      );
    }

    try {
      final data = await Supabase.instance.client
          .rpc(
            'get_daily_question_detail',
            params: {'target_date': date == null ? null : _formatDate(date)},
          )
          .timeout(AppConfig.supabaseRpcTimeout);
      final row = _asOptionalRow(data);
      return row == null ? null : DailyQuestionDetailSnapshot.fromJson(row);
    } on TimeoutException {
      throw const DailyQuestionHistoryRepositoryException(
        DailyQuestionHistoryFailureReason.requestTimeout,
      );
    } on PostgrestException catch (error) {
      throw DailyQuestionHistoryRepositoryException(
        _reasonFromMessage(error.message),
        error.message,
      );
    }
  }

  Map<String, dynamic>? _asOptionalRow(Object? data) {
    if (data == null) {
      return null;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    if (data is List) {
      if (data.isEmpty) {
        return null;
      }
      final first = data.first;
      if (first is Map) {
        return Map<String, dynamic>.from(first);
      }
    }
    throw const DailyQuestionHistoryRepositoryException(
      DailyQuestionHistoryFailureReason.unknown,
    );
  }

  DailyQuestionHistoryFailureReason _reasonFromMessage(String message) {
    return switch (message) {
      'auth_required' => DailyQuestionHistoryFailureReason.authRequired,
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
