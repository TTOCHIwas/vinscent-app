import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import 'safety_report.dart';
import 'safety_report_failure.dart';

final safetyReportRepositoryProvider = Provider<SafetyReportRepository>(
  (ref) => SupabaseSafetyReportRepository(),
);

abstract interface class SafetyReportRepository {
  Future<void> submit(SafetyReportRequest request);
}

typedef SafetyReportRpcInvoker =
    Future<Object?> Function(Map<String, Object?> params);

class SupabaseSafetyReportRepository implements SafetyReportRepository {
  SupabaseSafetyReportRepository({
    SafetyReportRpcInvoker? invoke,
    bool? isConfigured,
    Duration? timeout,
  }) : _invoke = invoke ?? _invokeSubmitSafetyReport,
       _isConfigured = isConfigured ?? AppConfig.isSupabaseConfigured,
       _timeout = timeout ?? AppConfig.supabaseRpcTimeout;

  final SafetyReportRpcInvoker _invoke;
  final bool _isConfigured;
  final Duration _timeout;

  @override
  Future<void> submit(SafetyReportRequest request) async {
    if (!_isConfigured) {
      throw const SafetyReportException(
        SafetyReportFailureReason.configMissing,
      );
    }

    try {
      await _invoke({
        'requested_target_type': request.target.type.rpcValue,
        'requested_target_id': request.target.id,
        'requested_reason': request.reason.rpcValue,
        'requested_details': _normalizeOptionalText(request.details),
        'requested_content_snapshot': _normalizeOptionalText(
          request.target.contentSnapshot,
        ),
      }).timeout(_timeout);
    } on TimeoutException {
      throw const SafetyReportException(
        SafetyReportFailureReason.requestTimeout,
      );
    } on PostgrestException catch (error) {
      throw SafetyReportException(
        _failureReasonFromMessage(error.message),
        error.message,
      );
    } on SafetyReportException {
      rethrow;
    } catch (_) {
      throw const SafetyReportException(SafetyReportFailureReason.unknown);
    }
  }

  static Future<Object?> _invokeSubmitSafetyReport(
    Map<String, Object?> params,
  ) {
    return Supabase.instance.client.rpc('submit_safety_report', params: params);
  }

  static String? _normalizeOptionalText(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  static SafetyReportFailureReason _failureReasonFromMessage(String message) {
    return switch (message) {
      'auth_required' => SafetyReportFailureReason.authRequired,
      'active_couple_required' =>
        SafetyReportFailureReason.activeCoupleRequired,
      'invalid_safety_report_target_type' ||
      'invalid_safety_report_target' => SafetyReportFailureReason.invalidTarget,
      'safety_report_target_not_available' =>
        SafetyReportFailureReason.targetNotAvailable,
      'invalid_safety_report_reason' => SafetyReportFailureReason.invalidReason,
      'safety_report_details_too_long' =>
        SafetyReportFailureReason.detailsTooLong,
      'safety_report_snapshot_required' =>
        SafetyReportFailureReason.snapshotRequired,
      'safety_report_snapshot_too_long' =>
        SafetyReportFailureReason.snapshotTooLong,
      _ => SafetyReportFailureReason.unknown,
    };
  }
}
