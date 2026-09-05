import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/date/app_date_policy.dart';
import '../../couple/application/couple_controller.dart';
import '../data/couple_calendar_event.dart';
import '../data/couple_calendar_event_repository.dart';
import 'couple_calendar_event_realtime_controller.dart';

final coupleCalendarEventMonthProvider = FutureProvider.autoDispose
    .family<List<CoupleCalendarEvent>, DateTime>((ref, month) async {
      ref.watch(coupleCalendarEventRevisionProvider);
      final couple = await ref.watch(coupleControllerProvider.future);
      if (couple == null ||
          !couple.canReadSharedData ||
          !couple.hasRelationshipStartDate) {
        return const [];
      }

      final normalizedMonth = calendarMonthOnly(month);
      final relationshipStartDate = calendarDateOnly(
        couple.relationshipStartDate!,
      );
      final relationshipStartMonth = calendarMonthOnly(relationshipStartDate);
      if (normalizedMonth.isBefore(relationshipStartMonth)) {
        return const [];
      }

      final monthEnd = DateTime(month.year, month.month + 1, 0);
      final startDate = normalizedMonth == relationshipStartMonth
          ? relationshipStartDate
          : normalizedMonth;
      return ref
          .watch(coupleCalendarEventRepositoryProvider)
          .fetchOccurrences(startDate: startDate, endDate: monthEnd);
    }, retry: (_, _) => null);

final coupleCalendarEventsByDateProvider = FutureProvider.autoDispose
    .family<Map<DateTime, List<CoupleCalendarEvent>>, DateTime>((
      ref,
      month,
    ) async {
      final events = await ref.watch(
        coupleCalendarEventMonthProvider(calendarMonthOnly(month)).future,
      );
      final grouped = <DateTime, List<CoupleCalendarEvent>>{};
      for (final event in events) {
        grouped
            .putIfAbsent(calendarDateOnly(event.occurrenceDate), () => [])
            .add(event);
      }
      return Map<DateTime, List<CoupleCalendarEvent>>.unmodifiable({
        for (final entry in grouped.entries)
          entry.key: List<CoupleCalendarEvent>.unmodifiable(entry.value),
      });
    }, retry: (_, _) => null);

final coupleCalendarEventDateProvider = FutureProvider.autoDispose
    .family<List<CoupleCalendarEvent>, DateTime>((ref, date) async {
      final normalizedDate = calendarDateOnly(date);
      final monthEvents = await ref.watch(
        coupleCalendarEventMonthProvider(
          calendarMonthOnly(normalizedDate),
        ).future,
      );
      return monthEvents
          .where(
            (event) => calendarDateOnly(event.occurrenceDate) == normalizedDate,
          )
          .toList(growable: false);
    }, retry: (_, _) => null);

final coupleCalendarEventHasOccurrenceProvider = FutureProvider.autoDispose
    .family<bool, DateTime>((ref, date) async {
      ref.watch(coupleCalendarEventRevisionProvider);
      final couple = await ref.watch(coupleControllerProvider.future);
      if (couple == null ||
          !couple.canReadSharedData ||
          !couple.hasRelationshipStartDate) {
        return false;
      }

      final normalizedDate = calendarDateOnly(date);
      final relationshipStartDate = calendarDateOnly(
        couple.relationshipStartDate!,
      );
      if (normalizedDate.isBefore(relationshipStartDate)) {
        return false;
      }

      return ref
          .watch(coupleCalendarEventGatewayProvider)
          .hasOccurrenceOn(normalizedDate);
    }, retry: (_, _) => null);

final coupleCalendarEventProvider = FutureProvider.autoDispose
    .family<CoupleCalendarEvent?, String>((ref, eventId) async {
      ref.watch(coupleCalendarEventRevisionProvider);
      final couple = await ref.watch(coupleControllerProvider.future);
      if (couple == null || !couple.canReadSharedData) {
        return null;
      }
      return ref
          .watch(coupleCalendarEventRepositoryProvider)
          .fetchEvent(eventId);
    }, retry: (_, _) => null);
