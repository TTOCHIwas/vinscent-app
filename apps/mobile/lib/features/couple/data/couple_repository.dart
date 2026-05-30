import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import 'couple.dart';
import 'couple_failure.dart';

final coupleRepositoryProvider = Provider<CoupleRepository>((ref) {
  return SupabaseCoupleRepository();
});

abstract interface class CoupleRepository {
  Future<Couple?> fetchCurrentCouple();

  Future<Couple> createInvite();

  Future<Couple> joinByCode(String inviteCode);

  Future<void> cancelInvite();

  Future<Couple> updateRelationshipStartDate(DateTime date);
}

class SupabaseCoupleRepository implements CoupleRepository {
  const SupabaseCoupleRepository();

  @override
  Future<Couple?> fetchCurrentCouple() async {
    if (!AppConfig.isSupabaseConfigured) {
      return null;
    }

    try {
      final data = await Supabase.instance.client
          .from('couples')
          .select()
          .inFilter('status', ['pending', 'active'])
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (data == null) {
        return null;
      }

      return Couple.fromJson(data);
    } on PostgrestException catch (error) {
      throw _mapPostgrestError(error);
    }
  }

  @override
  Future<Couple> createInvite() async {
    if (!AppConfig.isSupabaseConfigured) {
      throw const CoupleRepositoryException(CoupleFailureReason.configMissing);
    }

    try {
      final data = await Supabase.instance.client.rpc('create_couple_invite');

      return Couple.fromJson(_asRow(data));
    } on PostgrestException catch (error) {
      throw _mapPostgrestError(error);
    }
  }

  @override
  Future<Couple> joinByCode(String inviteCode) async {
    if (!AppConfig.isSupabaseConfigured) {
      throw const CoupleRepositoryException(CoupleFailureReason.configMissing);
    }

    try {
      final data = await Supabase.instance.client.rpc(
        'join_couple_by_code',
        params: {'invite_code': inviteCode.trim().toUpperCase()},
      );

      return Couple.fromJson(_asRow(data));
    } on PostgrestException catch (error) {
      throw _mapPostgrestError(error);
    }
  }

  @override
  Future<void> cancelInvite() async {
    if (!AppConfig.isSupabaseConfigured) {
      throw const CoupleRepositoryException(CoupleFailureReason.configMissing);
    }

    try {
      await Supabase.instance.client.rpc('cancel_couple_invite');
    } on PostgrestException catch (error) {
      throw _mapPostgrestError(error);
    }
  }

  @override
  Future<Couple> updateRelationshipStartDate(DateTime date) async {
    if (!AppConfig.isSupabaseConfigured) {
      throw const CoupleRepositoryException(CoupleFailureReason.configMissing);
    }

    try {
      final data = await Supabase.instance.client.rpc(
        'update_relationship_start_date',
        params: {'start_date': _formatDate(date)},
      );

      return Couple.fromJson(_asRow(data));
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
