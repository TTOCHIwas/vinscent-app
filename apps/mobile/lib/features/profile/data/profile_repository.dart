import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import 'user_profile.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return SupabaseProfileRepository();
});

abstract interface class ProfileRepository {
  Future<UserProfile?> fetchCurrentProfile();

  Future<UserProfile> completeOnboarding({
    required String displayName,
    required DateTime birthDate,
  });
}

class SupabaseProfileRepository implements ProfileRepository {
  const SupabaseProfileRepository();

  @override
  Future<UserProfile?> fetchCurrentProfile() async {
    if (!AppConfig.isSupabaseConfigured) {
      return null;
    }

    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      return null;
    }

    final data = await client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (data == null) {
      return null;
    }

    return UserProfile.fromJson(data);
  }

  @override
  Future<UserProfile> completeOnboarding({
    required String displayName,
    required DateTime birthDate,
  }) async {
    if (!AppConfig.isSupabaseConfigured) {
      throw const ProfileRepositoryException('Supabase config is missing.');
    }

    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      throw const ProfileRepositoryException('Authenticated user is missing.');
    }

    final now = DateTime.now().toUtc();
    final data = await client
        .from('profiles')
        .upsert({
          'id': user.id,
          'display_name': displayName.trim(),
          'birth_date': _formatDate(birthDate),
          'onboarding_completed_at': now.toIso8601String(),
        })
        .select()
        .single();

    return UserProfile.fromJson(data);
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}

class ProfileRepositoryException implements Exception {
  const ProfileRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}
