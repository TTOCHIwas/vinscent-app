import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';

final coupleCalendarEventChangeSourceProvider =
    Provider<CoupleCalendarEventChangeSource>((ref) {
      return const SupabaseCoupleCalendarEventChangeSource();
    });

abstract interface class CoupleCalendarEventChangeSource {
  Stream<void> watch({required String coupleId});
}

class SupabaseCoupleCalendarEventChangeSource
    implements CoupleCalendarEventChangeSource {
  const SupabaseCoupleCalendarEventChangeSource();

  static const _changeEvent = 'calendar_event_changed';

  @override
  Stream<void> watch({required String coupleId}) {
    if (!AppConfig.isSupabaseConfigured) {
      return const Stream<void>.empty();
    }

    final client = Supabase.instance.client;
    final controller = StreamController<void>();
    var isCancelled = false;
    final channel = client
        .channel(
          'couple-calendar-events:$coupleId',
          opts: const RealtimeChannelConfig(private: true),
        )
        .onBroadcast(
          event: _changeEvent,
          callback: (_) {
            if (!isCancelled) {
              controller.add(null);
            }
          },
        );

    channel.subscribe((status, error) {
      if (status == RealtimeSubscribeStatus.channelError ||
          status == RealtimeSubscribeStatus.timedOut) {
        debugPrint(
          '[calendar] Realtime channel unavailable: '
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
