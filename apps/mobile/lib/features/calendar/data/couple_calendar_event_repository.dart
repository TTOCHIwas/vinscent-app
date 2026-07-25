import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'couple_calendar_event_repository_contract.dart';
import 'default_couple_calendar_event_repository.dart';
import 'supabase_couple_calendar_event_artwork_store.dart';
import 'supabase_couple_calendar_event_gateway.dart';

export 'couple_calendar_event_repository_contract.dart';
export 'default_couple_calendar_event_repository.dart';

final coupleCalendarEventRepositoryProvider =
    Provider<CoupleCalendarEventRepository>((ref) {
      return const DefaultCoupleCalendarEventRepository(
        eventGateway: SupabaseCoupleCalendarEventGateway(),
        artworkStore: SupabaseCoupleCalendarEventArtworkStore(),
      );
    });
