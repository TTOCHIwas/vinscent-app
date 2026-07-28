import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';

final userSafetyStateChangeSourceProvider =
    Provider<UserSafetyStateChangeSource>((ref) {
      return const SupabaseUserSafetyStateChangeSource();
    });

abstract interface class UserSafetyStateChangeSource {
  Stream<int> watch({required String userId});
}

class SupabaseUserSafetyStateChangeSource
    implements UserSafetyStateChangeSource {
  const SupabaseUserSafetyStateChangeSource();

  @override
  Stream<int> watch({required String userId}) {
    if (!AppConfig.isSupabaseConfigured) {
      return const Stream<int>.empty();
    }

    return Supabase.instance.client
        .from('user_safety_states')
        .stream(primaryKey: ['user_id'])
        .eq('user_id', userId)
        .map((rows) {
          if (rows.isEmpty) {
            return 0;
          }

          final revision = rows.single['revision'];
          if (revision is int) {
            return revision;
          }
          if (revision is num) {
            return revision.toInt();
          }
          throw const FormatException('Invalid user safety revision');
        });
  }
}
