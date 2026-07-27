import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import 'couple_member_birthday.dart';

final coupleMemberBirthdayRepositoryProvider =
    Provider<CoupleMemberBirthdayRepository>((ref) {
      return const SupabaseCoupleMemberBirthdayRepository();
    });

abstract interface class CoupleMemberBirthdayRepository {
  Future<List<CoupleMemberBirthday>> fetchActiveCoupleBirthdays();
}

class SupabaseCoupleMemberBirthdayRepository
    implements CoupleMemberBirthdayRepository {
  const SupabaseCoupleMemberBirthdayRepository();

  @override
  Future<List<CoupleMemberBirthday>> fetchActiveCoupleBirthdays() async {
    if (!AppConfig.isSupabaseConfigured) {
      return const [];
    }

    final client = Supabase.instance.client;
    if (client.auth.currentUser == null) {
      return const [];
    }

    final data = await client
        .rpc('get_active_couple_member_birthdays')
        .timeout(AppConfig.supabaseRpcTimeout);
    if (data is! List) {
      throw const FormatException(
        'Unexpected active couple member birthdays response',
      );
    }

    return data
        .whereType<Map>()
        .map(
          (row) =>
              CoupleMemberBirthday.fromJson(Map<String, dynamic>.from(row)),
        )
        .toList(growable: false);
  }
}
