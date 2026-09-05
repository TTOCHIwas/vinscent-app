import 'dart:typed_data';

import 'couple_calendar_event.dart';
import 'couple_calendar_event_repository_contract.dart';

abstract interface class CoupleCalendarEventGateway {
  Future<bool> hasOccurrenceOn(DateTime date);

  Future<List<CoupleCalendarEvent>> fetchOccurrences({
    required DateTime startDate,
    required DateTime endDate,
  });

  Future<CoupleCalendarEvent?> fetchEvent(String eventId);

  Future<CoupleCalendarEvent> saveEvent({
    required CoupleCalendarEventSaveRequest request,
    required String? artworkRevision,
  });

  Future<void> deleteEvent({
    required String eventId,
    required int expectedRevision,
  });
}

abstract interface class CoupleCalendarEventArtworkStore {
  Future<Uint8List> fetchDrawingData(String path);

  Future<String> uploadArtwork({
    required String coupleId,
    required String eventId,
    required Uint8List previewBytes,
    required Uint8List drawingDataBytes,
  });

  Future<void> discardUploadedArtwork({
    required String eventId,
    required String artifactId,
  });
}
