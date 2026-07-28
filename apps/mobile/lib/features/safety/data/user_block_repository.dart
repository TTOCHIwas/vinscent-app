import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import 'user_block.dart';
import 'user_block_failure.dart';

final userBlockRepositoryProvider = Provider<UserBlockRepository>(
  (ref) => SupabaseUserBlockRepository(),
);

abstract interface class UserBlockRepository {
  Future<void> blockCurrentPartner();

  Future<bool> unblockUser(String userId);

  Future<List<BlockedUser>> fetchBlockedUsers();

  Future<List<ReconnectableCoupleArchive>> fetchReconnectableArchives();

  Future<void> createReconnectInvite(String coupleId);
}

typedef UserBlockRpcInvoker =
    Future<Object?> Function(String function, Map<String, Object?>? params);

class SupabaseUserBlockRepository implements UserBlockRepository {
  SupabaseUserBlockRepository({
    UserBlockRpcInvoker? invoke,
    bool? isConfigured,
    Duration? timeout,
  }) : _invoke = invoke ?? _invokeRpc,
       _isConfigured = isConfigured ?? AppConfig.isSupabaseConfigured,
       _timeout = timeout ?? AppConfig.supabaseRpcTimeout;

  final UserBlockRpcInvoker _invoke;
  final bool _isConfigured;
  final Duration _timeout;

  @override
  Future<void> blockCurrentPartner() async {
    await _run('block_current_partner');
  }

  @override
  Future<bool> unblockUser(String userId) async {
    final result = await _run(
      'unblock_user',
      params: {'target_user_id': userId},
    );
    if (result is! bool) {
      throw const UserBlockException(UserBlockFailureReason.invalidResponse);
    }
    return result;
  }

  @override
  Future<List<BlockedUser>> fetchBlockedUsers() async {
    final result = await _run('list_blocked_users');
    return _rows(result).map(BlockedUser.fromJson).toList(growable: false);
  }

  @override
  Future<List<ReconnectableCoupleArchive>> fetchReconnectableArchives() async {
    final result = await _run('list_reconnectable_couple_archives');
    return _rows(
      result,
    ).map(ReconnectableCoupleArchive.fromJson).toList(growable: false);
  }

  @override
  Future<void> createReconnectInvite(String coupleId) async {
    await _run(
      'create_couple_archive_reconnect_invite',
      params: {'target_couple_id': coupleId},
    );
  }

  Future<Object?> _run(String function, {Map<String, Object?>? params}) async {
    if (!_isConfigured) {
      throw const UserBlockException(UserBlockFailureReason.configMissing);
    }

    try {
      return await _invoke(function, params).timeout(_timeout);
    } on TimeoutException {
      throw const UserBlockException(UserBlockFailureReason.requestTimeout);
    } on PostgrestException catch (error) {
      throw UserBlockException(
        _failureReasonFromMessage(error.message),
        error.message,
      );
    } on UserBlockException {
      rethrow;
    } on FormatException {
      throw const UserBlockException(UserBlockFailureReason.invalidResponse);
    } on TypeError {
      throw const UserBlockException(UserBlockFailureReason.invalidResponse);
    } catch (_) {
      throw const UserBlockException(UserBlockFailureReason.unknown);
    }
  }

  static Future<Object?> _invokeRpc(
    String function,
    Map<String, Object?>? params,
  ) {
    if (params == null) {
      return Supabase.instance.client.rpc(function);
    }
    return Supabase.instance.client.rpc(function, params: params);
  }

  static List<Map<String, dynamic>> _rows(Object? data) {
    if (data is! List) {
      throw const UserBlockException(UserBlockFailureReason.invalidResponse);
    }

    return data
        .map((row) {
          if (row is Map<String, dynamic>) {
            return row;
          }
          if (row is Map) {
            return Map<String, dynamic>.from(row);
          }
          throw const UserBlockException(
            UserBlockFailureReason.invalidResponse,
          );
        })
        .toList(growable: false);
  }

  static UserBlockFailureReason _failureReasonFromMessage(String message) {
    return switch (message) {
      'auth_required' => UserBlockFailureReason.authRequired,
      'active_couple_required' => UserBlockFailureReason.activeCoupleRequired,
      'couple_already_exists' => UserBlockFailureReason.coupleAlreadyExists,
      'user_blocked' => UserBlockFailureReason.userBlocked,
      'blocked_archive_not_available' =>
        UserBlockFailureReason.archiveNotAvailable,
      _ => UserBlockFailureReason.unknown,
    };
  }
}
