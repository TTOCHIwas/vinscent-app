import 'package:supabase_flutter/supabase_flutter.dart';

enum CoupleCalendarEventFailureReason {
  configMissing,
  authRequired,
  unavailable,
  relationshipDateRequired,
  invalidTitle,
  invalidDate,
  invalidRepeatRule,
  invalidMemo,
  invalidArtwork,
  invalidReminder,
  reminderInPast,
  beforeRelationshipStart,
  conflict,
  notFound,
  artworkMissing,
  requestTimeout,
  storage,
  unknown,
}

class CoupleCalendarEventRepositoryException implements Exception {
  const CoupleCalendarEventRepositoryException(this.reason, [this.message]);

  final CoupleCalendarEventFailureReason reason;
  final String? message;
}

CoupleCalendarEventRepositoryException mapCalendarEventPostgrestError(
  PostgrestException error,
) {
  final reason = switch (error.message) {
    'auth_required' => CoupleCalendarEventFailureReason.authRequired,
    'active_couple_required' ||
    'readable_couple_required' =>
      CoupleCalendarEventFailureReason.unavailable,
    'relationship_date_required' =>
      CoupleCalendarEventFailureReason.relationshipDateRequired,
    'invalid_calendar_event_title' =>
      CoupleCalendarEventFailureReason.invalidTitle,
    'invalid_calendar_event_date' =>
      CoupleCalendarEventFailureReason.invalidDate,
    'invalid_calendar_event_repeat_rule' =>
      CoupleCalendarEventFailureReason.invalidRepeatRule,
    'invalid_calendar_event_memo' =>
      CoupleCalendarEventFailureReason.invalidMemo,
    'invalid_calendar_event_artwork' =>
      CoupleCalendarEventFailureReason.invalidArtwork,
    'invalid_calendar_event_reminder' ||
    'invalid_calendar_reminder_window' =>
      CoupleCalendarEventFailureReason.invalidReminder,
    'calendar_event_reminder_in_past' =>
      CoupleCalendarEventFailureReason.reminderInPast,
    'calendar_event_before_relationship_start' =>
      CoupleCalendarEventFailureReason.beforeRelationshipStart,
    'calendar_event_conflict' =>
      CoupleCalendarEventFailureReason.conflict,
    'calendar_event_not_found' =>
      CoupleCalendarEventFailureReason.notFound,
    'calendar_event_artwork_missing' =>
      CoupleCalendarEventFailureReason.artworkMissing,
    _ => CoupleCalendarEventFailureReason.unknown,
  };
  return CoupleCalendarEventRepositoryException(reason, error.message);
}
