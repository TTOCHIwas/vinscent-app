import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import 'notification_preferences.dart';
import 'settings_failure.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return const SupabaseSettingsRepository();
});

abstract interface class SettingsRepository {
  Future<NotificationPreferences> fetchNotificationPreferences();

  Future<NotificationPreferences> updateNotificationPreferences(
    NotificationPreferences preferences,
  );
}

class SupabaseSettingsRepository implements SettingsRepository {
  const SupabaseSettingsRepository();

  @override
  Future<NotificationPreferences> fetchNotificationPreferences() async {
    if (!AppConfig.isSupabaseConfigured) {
      throw const SettingsRepositoryException(
        SettingsFailureReason.configMissing,
      );
    }

    try {
      final data = await Supabase.instance.client.rpc(
        'get_my_notification_preferences',
      );
      return NotificationPreferences.fromJson(_asRow(data));
    } on PostgrestException catch (error) {
      throw _mapPostgrestError(error);
    }
  }

  @override
  Future<NotificationPreferences> updateNotificationPreferences(
    NotificationPreferences preferences,
  ) async {
    if (!AppConfig.isSupabaseConfigured) {
      throw const SettingsRepositoryException(
        SettingsFailureReason.configMissing,
      );
    }

    try {
      final data = await Supabase.instance.client.rpc(
        'update_my_notification_preferences',
        params: {
          'requested_partner_answer_enabled': preferences.partnerAnswerEnabled,
          'requested_daily_question_enabled': preferences.dailyQuestionEnabled,
          'requested_reminder_enabled': preferences.reminderEnabled,
          'requested_couple_disconnect_enabled':
              preferences.coupleDisconnectEnabled,
          'requested_recording_enabled': preferences.recordingEnabled,
          'requested_partner_story_card_enabled':
              preferences.partnerStoryCardEnabled,
          'requested_couple_activity_enabled':
              preferences.coupleActivityEnabled,
          'requested_ai_updates_enabled': preferences.aiUpdatesEnabled,
        },
      );

      return NotificationPreferences.fromJson(_asRow(data));
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

    throw const SettingsRepositoryException(SettingsFailureReason.unknown);
  }

  SettingsRepositoryException _mapPostgrestError(PostgrestException error) {
    return SettingsRepositoryException(
      _reasonFromMessage(error.message),
      error.message,
    );
  }

  SettingsFailureReason _reasonFromMessage(String message) {
    return switch (message) {
      'auth_required' => SettingsFailureReason.authRequired,
      _ => SettingsFailureReason.unknown,
    };
  }
}
