import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../couple/application/couple_controller.dart';
import '../../couple/application/couple_current_date_provider.dart';
import 'couple_calendar_event_provider.dart';
import 'couple_default_calendar_event_resolver.dart';
import 'couple_member_birthday_provider.dart';

class CalendarAttentionState {
  const CalendarAttentionState({required this.hasTodayEvent});

  const CalendarAttentionState.empty() : hasTodayEvent = false;

  final bool hasTodayEvent;
}

final calendarAttentionStateProvider = Provider<CalendarAttentionState>((ref) {
  final today = ref.watch(coupleCurrentDateProvider);
  final couple = ref.watch(coupleControllerProvider).asData?.value;
  if (couple == null ||
      !couple.canReadSharedData ||
      !couple.hasRelationshipStartDate) {
    return const CalendarAttentionState.empty();
  }

  final hasCustomEvent = ref
      .watch(coupleCalendarEventHasOccurrenceProvider(today))
      .asData
      ?.value;
  final birthdays = ref.watch(coupleMemberBirthdayProvider).asData?.value;
  final defaultEvents = birthdays == null
      ? const <CoupleDefaultCalendarEventOccurrence>[]
      : const CoupleDefaultCalendarEventResolver().resolve(
          relationshipStartDate: couple.relationshipStartDate!,
          date: today,
          birthdays: birthdays,
        );

  return CalendarAttentionState(
    hasTodayEvent: (hasCustomEvent ?? false) || defaultEvents.isNotEmpty,
  );
});
