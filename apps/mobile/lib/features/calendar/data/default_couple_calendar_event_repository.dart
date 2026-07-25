import 'dart:typed_data';

import 'couple_calendar_event.dart';
import 'couple_calendar_event_data_gateways.dart';
import 'couple_calendar_event_repository_contract.dart';

class DefaultCoupleCalendarEventRepository
    implements CoupleCalendarEventRepository {
  const DefaultCoupleCalendarEventRepository({
    required CoupleCalendarEventGateway eventGateway,
    required CoupleCalendarEventArtworkStore artworkStore,
  }) : _eventGateway = eventGateway,
       _artworkStore = artworkStore;

  final CoupleCalendarEventGateway _eventGateway;
  final CoupleCalendarEventArtworkStore _artworkStore;

  @override
  Future<List<CoupleCalendarEvent>> fetchOccurrences({
    required DateTime startDate,
    required DateTime endDate,
  }) {
    return _eventGateway.fetchOccurrences(
      startDate: startDate,
      endDate: endDate,
    );
  }

  @override
  Future<CoupleCalendarEvent?> fetchEvent(String eventId) {
    return _eventGateway.fetchEvent(eventId);
  }

  @override
  Future<Uint8List> fetchArtworkDrawingData(String drawingDataPath) {
    return _artworkStore.fetchDrawingData(drawingDataPath);
  }

  @override
  Future<CoupleCalendarEvent> saveEvent({
    required String coupleId,
    required CoupleCalendarEventSaveRequest request,
    Uint8List? previewBytes,
    Uint8List? drawingDataBytes,
  }) async {
    final hasPreview = previewBytes != null;
    final hasDrawingData = drawingDataBytes != null;
    if (hasPreview != hasDrawingData) {
      throw ArgumentError(
        'previewBytes and drawingDataBytes must be provided together.',
      );
    }

    String? artworkRevision;
    if (previewBytes != null && drawingDataBytes != null) {
      artworkRevision = await _artworkStore.uploadArtwork(
        coupleId: coupleId,
        eventId: request.eventId,
        previewBytes: previewBytes,
        drawingDataBytes: drawingDataBytes,
      );
    }

    try {
      return await _eventGateway.saveEvent(
        request: request,
        artworkRevision: artworkRevision,
      );
    } catch (_) {
      if (artworkRevision != null) {
        await _artworkStore.discardUploadedArtwork(
          eventId: request.eventId,
          artifactId: artworkRevision,
        );
      }
      rethrow;
    }
  }

  @override
  Future<void> deleteEvent({
    required String eventId,
    required int expectedRevision,
  }) {
    return _eventGateway.deleteEvent(
      eventId: eventId,
      expectedRevision: expectedRevision,
    );
  }
}
