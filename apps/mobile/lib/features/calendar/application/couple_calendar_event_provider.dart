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

      final normalizedMonth = DateTime(month.year, month.month);
      final relationshipStartDate = calendarDateOnly(
        couple.relationshipStartDate!,
      );
      final relationshipStartMonth = DateTime(
        relationshipStartDate.year,
        relationshipStartDate.month,
      );
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

final coupleCalendarEventDateProvider = FutureProvider.autoDispose
    .family<List<CoupleCalendarEvent>, DateTime>((ref, date) async {
      ref.watch(coupleCalendarEventRevisionProvider);
      final couple = await ref.watch(coupleControllerProvider.future);
      if (couple == null ||
          !couple.canReadSharedData ||
          !couple.hasRelationshipStartDate) {
        return const [];
      }

      final normalizedDate = calendarDateOnly(date);
      final relationshipStartDate = calendarDateOnly(
        couple.relationshipStartDate!,
      );
      if (normalizedDate.isBefore(relationshipStartDate)) {
        return const [];
      }

      return ref
          .watch(coupleCalendarEventRepositoryProvider)
          .fetchOccurrences(startDate: normalizedDate, endDate: normalizedDate);
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
