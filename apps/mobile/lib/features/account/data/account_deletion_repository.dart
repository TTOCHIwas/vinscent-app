import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';

final accountDeletionRepositoryProvider = Provider<AccountDeletionRepository>(
  (ref) => SupabaseAccountDeletionRepository(),
);

abstract interface class AccountDeletionRepository {
  Future<AccountDeletionReceipt> deleteAccount({
    String? appleAuthorizationCode,
  });
}

typedef AccountDeletionFunctionInvoker =
    Future<Object?> Function(String? appleAuthorizationCode);

class SupabaseAccountDeletionRepository implements AccountDeletionRepository {
  SupabaseAccountDeletionRepository({
    AccountDeletionFunctionInvoker? invoke,
    bool? isConfigured,
    Duration? timeout,
  }) : _invoke = invoke ?? _invokeDeleteAccount,
       _isConfigured = isConfigured ?? AppConfig.isSupabaseConfigured,
       _timeout = timeout ?? requestTimeout;

  static const requestTimeout = Duration(seconds: 30);

  final AccountDeletionFunctionInvoker _invoke;
  final bool _isConfigured;
  final Duration _timeout;

  @override
  Future<AccountDeletionReceipt> deleteAccount({
    String? appleAuthorizationCode,
  }) async {
    if (!_isConfigured) {
      throw const AccountDeletionException(
        AccountDeletionFailureReason.configMissing,
      );
    }

    try {
      final normalizedAuthorizationCode = appleAuthorizationCode?.trim();
      final data = await _invoke(
        normalizedAuthorizationCode == null ||
                normalizedAuthorizationCode.isEmpty
            ? null
            : normalizedAuthorizationCode,
      ).timeout(_timeout);
      final payload = switch (data) {
        Map<String, dynamic>() => data,
        Map() => Map<String, dynamic>.from(data),
        _ => throw const FormatException('Invalid account deletion response'),
      };
      final status = payload['status'];
      final deletedCoupleCount = payload['deletedCoupleCount'];
      if (status != 'deleted' ||
          deletedCoupleCount is! num ||
          deletedCoupleCount < 0 ||
          deletedCoupleCount != deletedCoupleCount.roundToDouble()) {
        throw const FormatException('Invalid account deletion response');
      }

      return AccountDeletionReceipt(
        deletedCoupleCount: deletedCoupleCount.toInt(),
      );
    } on TimeoutException {
      throw const AccountDeletionException(
        AccountDeletionFailureReason.requestTimeout,
      );
    } on FunctionException catch (error) {
      throw AccountDeletionException(
        switch (error.status) {
          401 => AccountDeletionFailureReason.sessionExpired,
          409 => AccountDeletionFailureReason.reauthenticationRequired,
          _ => AccountDeletionFailureReason.requestFailed,
        },
      );
    } on FormatException {
      throw const AccountDeletionException(
        AccountDeletionFailureReason.invalidResponse,
      );
    } on AccountDeletionException {
      rethrow;
    } catch (_) {
      throw const AccountDeletionException(
        AccountDeletionFailureReason.unknown,
      );
    }
  }

  static Future<Object?> _invokeDeleteAccount(
    String? appleAuthorizationCode,
  ) async {
    final response = await Supabase.instance.client.functions.invoke(
      'delete-account',
      body: appleAuthorizationCode == null
          ? null
          : {'appleAuthorizationCode': appleAuthorizationCode},
    );
    return response.data;
  }
}

class AccountDeletionReceipt {
  const AccountDeletionReceipt({required this.deletedCoupleCount});

  final int deletedCoupleCount;

  @override
  bool operator ==(Object other) {
    return other is AccountDeletionReceipt &&
        other.deletedCoupleCount == deletedCoupleCount;
  }

  @override
  int get hashCode => deletedCoupleCount.hashCode;
}

enum AccountDeletionFailureReason {
  configMissing,
  sessionExpired,
  reauthenticationRequired,
  reauthenticationCancelled,
  reauthenticationFailed,
  requestTimeout,
  requestFailed,
  invalidResponse,
  unknown,
}

class AccountDeletionException implements Exception {
  const AccountDeletionException(this.reason);

  final AccountDeletionFailureReason reason;

  @override
  String toString() => reason.name;
}
