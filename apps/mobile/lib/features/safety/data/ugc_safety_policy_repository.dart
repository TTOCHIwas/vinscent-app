import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import 'ugc_safety_policy_failure.dart';
import 'ugc_safety_policy_status.dart';

final ugcSafetyPolicyRepositoryProvider = Provider<UgcSafetyPolicyRepository>(
  (ref) => SupabaseUgcSafetyPolicyRepository(),
);

abstract interface class UgcSafetyPolicyRepository {
  Future<UgcSafetyPolicyStatus> fetchStatus();

  Future<UgcSafetyPolicyStatus> accept({required String policyVersion});
}

typedef UgcSafetyPolicyRpcInvoker =
    Future<Object?> Function(String functionName, Map<String, Object?>? params);

class SupabaseUgcSafetyPolicyRepository implements UgcSafetyPolicyRepository {
  SupabaseUgcSafetyPolicyRepository({
    UgcSafetyPolicyRpcInvoker? invoke,
    bool? isConfigured,
    Duration? timeout,
  }) : _invoke = invoke ?? _invokeRpc,
       _isConfigured = isConfigured ?? AppConfig.isSupabaseConfigured,
       _timeout = timeout ?? AppConfig.supabaseRpcTimeout;

  final UgcSafetyPolicyRpcInvoker _invoke;
  final bool _isConfigured;
  final Duration _timeout;

  @override
  Future<UgcSafetyPolicyStatus> fetchStatus() {
    return _request('get_my_ugc_safety_policy_status');
  }

  @override
  Future<UgcSafetyPolicyStatus> accept({required String policyVersion}) {
    return _request(
      'accept_current_ugc_safety_policy',
      params: {'requested_policy_version': policyVersion},
    );
  }

  Future<UgcSafetyPolicyStatus> _request(
    String functionName, {
    Map<String, Object?>? params,
  }) async {
    if (!_isConfigured) {
      throw const UgcSafetyPolicyException(
        UgcSafetyPolicyFailureReason.configMissing,
      );
    }

    try {
      final data = await _invoke(functionName, params).timeout(_timeout);
      return UgcSafetyPolicyStatus.fromJson(_asRow(data));
    } on TimeoutException {
      throw const UgcSafetyPolicyException(
        UgcSafetyPolicyFailureReason.requestTimeout,
      );
    } on PostgrestException catch (error) {
      throw UgcSafetyPolicyException(
        _failureReasonFromMessage(error.message),
        error.message,
      );
    } on FormatException catch (error) {
      throw UgcSafetyPolicyException(
        UgcSafetyPolicyFailureReason.invalidResponse,
        error.message,
      );
    } on UgcSafetyPolicyException {
      rethrow;
    } catch (_) {
      throw const UgcSafetyPolicyException(
        UgcSafetyPolicyFailureReason.unknown,
      );
    }
  }

  static Future<Object?> _invokeRpc(
    String functionName,
    Map<String, Object?>? params,
  ) {
    return Supabase.instance.client.rpc(functionName, params: params);
  }

  static Map<String, dynamic> _asRow(Object? data) {
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

    throw const FormatException('Missing UGC safety policy status');
  }

  static UgcSafetyPolicyFailureReason _failureReasonFromMessage(
    String message,
  ) {
    return switch (message) {
      'auth_required' => UgcSafetyPolicyFailureReason.authRequired,
      'ugc_safety_policy_version_outdated' =>
        UgcSafetyPolicyFailureReason.versionOutdated,
      _ => UgcSafetyPolicyFailureReason.unknown,
    };
  }
}
