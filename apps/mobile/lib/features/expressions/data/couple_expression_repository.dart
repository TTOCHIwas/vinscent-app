import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import 'couple_expression.dart';
import 'couple_expression_failure.dart';
import 'couple_expression_summary.dart';

final coupleExpressionRepositoryProvider = Provider<CoupleExpressionRepository>(
  (ref) {
    return const SupabaseCoupleExpressionRepository();
  },
);

abstract interface class CoupleExpressionRepository {
  Future<CoupleExpression> send(CoupleExpressionType type);

  Future<List<CoupleExpressionSummary>> fetchSummaryByDate(DateTime date);
}

class SupabaseCoupleExpressionRepository implements CoupleExpressionRepository {
  const SupabaseCoupleExpressionRepository();

  @override
  Future<CoupleExpression> send(CoupleExpressionType type) async {
    if (!AppConfig.isSupabaseConfigured) {
      throw const CoupleExpressionRepositoryException(
        CoupleExpressionFailureReason.configMissing,
      );
    }

    try {
      final data = await Supabase.instance.client
          .rpc(
            'send_couple_expression',
            params: {'requested_expression_type': type.value},
          )
          .timeout(AppConfig.supabaseRpcTimeout);

      return CoupleExpression.fromJson(_asRow(data));
    } on TimeoutException {
      throw const CoupleExpressionRepositoryException(
        CoupleExpressionFailureReason.requestTimeout,
      );
    } on PostgrestException catch (error) {
      throw _mapPostgrestError(error);
    } on FormatException catch (error) {
      throw CoupleExpressionRepositoryException(
        CoupleExpressionFailureReason.unknown,
        error.message,
      );
    }
  }

  @override
  Future<List<CoupleExpressionSummary>> fetchSummaryByDate(
    DateTime date,
  ) async {
    if (!AppConfig.isSupabaseConfigured) {
      throw const CoupleExpressionRepositoryException(
        CoupleExpressionFailureReason.configMissing,
      );
    }

    try {
      final data = await Supabase.instance.client
          .rpc(
            'get_couple_expression_summary_for_date',
            params: {'target_date': _formatDate(date)},
          )
          .timeout(AppConfig.supabaseRpcTimeout);

      return [
        for (final row in _asRows(data)) CoupleExpressionSummary.fromJson(row),
      ];
    } on TimeoutException {
      throw const CoupleExpressionRepositoryException(
        CoupleExpressionFailureReason.requestTimeout,
      );
    } on PostgrestException catch (error) {
      throw _mapPostgrestError(error);
    } on FormatException catch (error) {
      throw CoupleExpressionRepositoryException(
        CoupleExpressionFailureReason.unknown,
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

    throw const CoupleExpressionRepositoryException(
      CoupleExpressionFailureReason.unknown,
    );
  }

  List<Map<String, dynamic>> _asRows(Object? data) {
    if (data == null) {
      return const [];
    }

    if (data is List) {
      return [
        for (final row in data)
          if (row is Map<String, dynamic>)
            row
          else if (row is Map)
            Map<String, dynamic>.from(row)
          else
            throw const CoupleExpressionRepositoryException(
              CoupleExpressionFailureReason.unknown,
            ),
      ];
    }

    return [_asRow(data)];
  }

  CoupleExpressionRepositoryException _mapPostgrestError(
    PostgrestException error,
  ) {
    return CoupleExpressionRepositoryException(
      _reasonFromMessage(error.message),
      error.message,
    );
  }

  CoupleExpressionFailureReason _reasonFromMessage(String message) {
    return switch (message) {
      'auth_required' => CoupleExpressionFailureReason.authRequired,
      'active_couple_required' =>
        CoupleExpressionFailureReason.activeCoupleRequired,
      'relationship_date_required' =>
        CoupleExpressionFailureReason.relationshipDateRequired,
      'invalid_expression_type' =>
        CoupleExpressionFailureReason.invalidExpressionType,
      _ => CoupleExpressionFailureReason.unknown,
    };
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
