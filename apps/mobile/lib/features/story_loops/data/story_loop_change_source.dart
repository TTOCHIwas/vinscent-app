import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../story_loop_debug_log.dart';

final storyLoopChangeSourceProvider = Provider<StoryLoopChangeSource>((ref) {
  return const SupabaseStoryLoopChangeSource();
});

abstract interface class StoryLoopChangeSource {
  Stream<void> watch({required String coupleId});
}

class SupabaseStoryLoopChangeSource implements StoryLoopChangeSource {
  const SupabaseStoryLoopChangeSource();

  static const _tables = [
    'daily_story_loops',
    'story_loop_cards',
    'daily_questions',
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
    final channel = client.channel('story-loop:$coupleId');

    for (final table in _tables) {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        filter: filter,
        callback: (_) {
          if (!isCancelled) {
            controller.add(null);
          }
        },
      );
    }

    channel.subscribe((status, error) {
      if (status == RealtimeSubscribeStatus.channelError ||
          status == RealtimeSubscribeStatus.timedOut) {
        debugStoryLoopLog(
          'Realtime channel unavailable: '
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
}
