import 'dart:typed_data';

import 'couple_calendar_event.dart';

class CoupleCalendarEventSaveRequest {
  const CoupleCalendarEventSaveRequest({
    required this.eventId,
    required this.title,
    required this.eventDate,
    required this.repeatRule,
    required this.memo,
    required this.expectedRevision,
    required this.removeArtwork,
    required this.reminder,
  });

  final String eventId;
  final String title;
  final DateTime eventDate;
  final CoupleCalendarEventRepeatRule repeatRule;
  final String? memo;
  final int? expectedRevision;
  final bool removeArtwork;
  final CoupleCalendarEventReminder reminder;
}

abstract interface class CoupleCalendarEventRepository {
  Future<List<CoupleCalendarEvent>> fetchOccurrences({
    required DateTime startDate,
    required DateTime endDate,
  });

  Future<CoupleCalendarEvent?> fetchEvent(String eventId);

  Future<Uint8List> fetchArtworkDrawingData(String drawingDataPath);

  Future<CoupleCalendarEvent> saveEvent({
    required String coupleId,
    required CoupleCalendarEventSaveRequest request,
    Uint8List? previewBytes,
    Uint8List? drawingDataBytes,
  });

  Future<void> deleteEvent({
    required String eventId,
    required int expectedRevision,
  });
}
