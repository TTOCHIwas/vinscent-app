import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import 'couple.dart';
import 'couple_failure.dart';

final coupleRepositoryProvider = Provider<CoupleRepository>((ref) {
  return const SupabaseCoupleRepository();
});

abstract interface class CoupleRepository {
  Future<Couple?> fetchCurrentCouple();

  Future<Couple> createInvite();

  Future<Couple> joinByCode(String inviteCode);

  Future<Couple?> cancelInvite();

  Future<Couple> updateRelationshipStartDate(DateTime date);

  Future<Couple> disconnectCouple();

  Future<void> deleteDisconnectedArchiveNow();
}

class SupabaseCoupleRepository implements CoupleRepository {
  const SupabaseCoupleRepository();

  @override
  Future<Couple?> fetchCurrentCouple() async {
    if (!AppConfig.isSupabaseConfigured) {
      return null;
    }

    try {
      final data = await Supabase.instance.client.rpc(
        'get_current_couple_context',
      );
      final row = _asOptionalRow(data);

      if (row == null) {
        return null;
      }

      return Couple.fromJson(row);
    } on PostgrestException catch (error) {
      throw _mapPostgrestError(error);
    }
  }

  @override
  Future<Couple> createInvite() async {
    return _runAndRefresh(
      () => Supabase.instance.client.rpc('create_couple_invite'),
    );
  }

  @override
  Future<Couple> joinByCode(String inviteCode) async {
    return _runAndRefresh(
      () => Supabase.instance.client.rpc(
        'join_couple_by_code',
        params: {'invite_code': inviteCode.trim().toUpperCase()},
      ),
    );
  }

  @override
  Future<Couple?> cancelInvite() async {
    if (!AppConfig.isSupabaseConfigured) {
      throw const CoupleRepositoryException(CoupleFailureReason.configMissing);
    }

    try {
      await Supabase.instance.client.rpc('cancel_couple_invite');
      return fetchCurrentCouple();
    } on PostgrestException catch (error) {
      throw _mapPostgrestError(error);
    }
  }

  @override
  Future<Couple> updateRelationshipStartDate(DateTime date) async {
    return _runAndRefresh(
      () => Supabase.instance.client.rpc(
        'update_relationship_start_date',
        params: {'start_date': _formatDate(date)},
      ),
    );
  }

  @override
  Future<Couple> disconnectCouple() async {
    return _runAndRefresh(
      () => Supabase.instance.client.rpc('disconnect_couple'),
    );
  }

  @override
  Future<void> deleteDisconnectedArchiveNow() async {
    if (!AppConfig.isSupabaseConfigured) {
      throw const CoupleRepositoryException(CoupleFailureReason.configMissing);
    }

    try {
      await Supabase.instance.client.rpc('delete_disconnected_couple_archive_now');
    } on PostgrestException catch (error) {
      throw _mapPostgrestError(error);
    }
  }

  Future<Couple> _runAndRefresh(Future<Object?> Function() action) async {
    if (!AppConfig.isSupabaseConfigured) {
      throw const CoupleRepositoryException(CoupleFailureReason.configMissing);
    }

    try {
      await action();
      final couple = await fetchCurrentCouple();
      if (couple == null) {
        throw const CoupleRepositoryException(CoupleFailureReason.unknown);
      }

      return couple;
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

    throw const CoupleRepositoryException(CoupleFailureReason.unknown);
  }

  CoupleRepositoryException _mapPostgrestError(PostgrestException error) {
    return CoupleRepositoryException(
      _reasonFromMessage(error.message),
      error.message,
    );
  }

  CoupleFailureReason _reasonFromMessage(String message) {
    return switch (message) {
      'auth_required' => CoupleFailureReason.authRequired,
      'profile_required' => CoupleFailureReason.profileRequired,
      'couple_already_exists' => CoupleFailureReason.alreadyExists,
      'archived_couple_exists' => CoupleFailureReason.archivedCoupleExists,
      'archived_couple_required' => CoupleFailureReason.archivedCoupleRequired,
      'invite_not_found' => CoupleFailureReason.inviteNotFound,
      'invite_not_pending' => CoupleFailureReason.inviteNotPending,
      'cannot_join_own_invite' => CoupleFailureReason.ownInvite,
      'invalid_invite_code' => CoupleFailureReason.invalidCode,
      'relationship_date_in_future' => CoupleFailureReason.futureDate,
      'active_couple_required' => CoupleFailureReason.activeCoupleRequired,
      'invite_code_generation_failed' =>
        CoupleFailureReason.codeGenerationFailed,
      _ => CoupleFailureReason.unknown,
    };
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
