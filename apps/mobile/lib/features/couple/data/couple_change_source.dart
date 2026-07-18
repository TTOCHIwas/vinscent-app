import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';

final coupleChangeSourceProvider = Provider<CoupleChangeSource>((ref) {
  return const SupabaseCoupleChangeSource();
});

abstract interface class CoupleChangeSource {
  Stream<void> watch({required String coupleId});
}

class SupabaseCoupleChangeSource implements CoupleChangeSource {
  const SupabaseCoupleChangeSource();

  @override
  Stream<void> watch({required String coupleId}) {
    if (!AppConfig.isSupabaseConfigured) {
      return const Stream<void>.empty();
    }

    final client = Supabase.instance.client;
    final controller = StreamController<void>();
    final channel = client.channel('couple:$coupleId');
    var isCancelled = false;

    channel.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'couples',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'id',
        value: coupleId,
      ),
      callback: (_) {
        if (!isCancelled) {
          controller.add(null);
        }
      },
    );
    channel.subscribe();

    controller.onCancel = () async {
      isCancelled = true;
      await client.removeChannel(channel);
    };
    return controller.stream;
  }
}
