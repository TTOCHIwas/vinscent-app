import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../recording_debug_log.dart';

final coupleRecordingOverviewChangeSourceProvider =
    Provider<CoupleRecordingOverviewChangeSource>((ref) {
      return const SupabaseCoupleRecordingOverviewChangeSource();
    });

abstract interface class CoupleRecordingOverviewChangeSource {
  Stream<void> watch({required String coupleId});
}

class SupabaseCoupleRecordingOverviewChangeSource
    implements CoupleRecordingOverviewChangeSource {
  const SupabaseCoupleRecordingOverviewChangeSource();

  static const _tables = [
    'couple_current_recordings',
    'couple_recording_slot_settings',
    'couple_recording_slots',
    'couple_recording_slot_placements',
  ];

  @override
  Stream<void> watch({required String coupleId}) {
    if (!AppConfig.isSupabaseConfigured) {
      return const Stream<void>.empty();
    }

    final client = Supabase.instance.client;
    final controller = StreamController<void>();
    var isCancelled = false;
    final filter = PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'couple_id',
      value: coupleId,
    );
    final channel = client.channel('couple-recording-overview:$coupleId');

    for (final table in _tables) {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        filter: filter,
        callback: (payload) {
          if (isCancelled || _wasUpdatedByCurrentUser(payload, client)) {
            return;
          }
          controller.add(null);
        },
      );
    }

    channel.subscribe((status, error) {
      if (status == RealtimeSubscribeStatus.channelError ||
          status == RealtimeSubscribeStatus.timedOut) {
        debugRecordingLog(
          'Overview realtime channel unavailable: '
          'coupleId=$coupleId, status=${status.name}, error=$error',
        );
      }
    });

    controller.onCancel = () async {
      isCancelled = true;
      await client.removeChannel(channel);
    };
    return controller.stream;
  }

  bool _wasUpdatedByCurrentUser(
    PostgresChangePayload payload,
    SupabaseClient client,
  ) {
    final updatedByUserId =
        payload.newRecord['updated_by_user_id'] as String? ??
        payload.oldRecord['updated_by_user_id'] as String?;
    return updatedByUserId != null &&
        updatedByUserId == client.auth.currentUser?.id;
  }
}
