import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'couple_calendar_event_repository_contract.dart';
import 'couple_calendar_event_data_gateways.dart';
import 'default_couple_calendar_event_repository.dart';
import 'supabase_couple_calendar_event_artwork_store.dart';
import 'supabase_couple_calendar_event_gateway.dart';

export 'couple_calendar_event_repository_contract.dart';
export 'default_couple_calendar_event_repository.dart';

final coupleCalendarEventGatewayProvider = Provider<CoupleCalendarEventGateway>(
  (ref) => const SupabaseCoupleCalendarEventGateway(),
);

final coupleCalendarEventRepositoryProvider =
    Provider<CoupleCalendarEventRepository>((ref) {
      return DefaultCoupleCalendarEventRepository(
        eventGateway: ref.watch(coupleCalendarEventGatewayProvider),
        artworkStore: const SupabaseCoupleCalendarEventArtworkStore(),
      );
    });
