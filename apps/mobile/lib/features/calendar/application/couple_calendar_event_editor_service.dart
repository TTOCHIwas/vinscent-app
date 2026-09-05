import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/drawing/app_drawing.dart';
import '../../../core/drawing/app_drawing_artifact_codec.dart';
import '../data/couple_calendar_event.dart';
import '../data/couple_calendar_event_repository.dart';
import 'device_calendar_sync_coordinator.dart';

final coupleCalendarEventEditorServiceProvider =
    Provider<CoupleCalendarEventEditorService>((ref) {
      return CoupleCalendarEventEditorService(
        repository: ref.watch(coupleCalendarEventRepositoryProvider),
        deviceCalendarSyncCoordinator: ref.watch(
          deviceCalendarSyncCoordinatorProvider,
        ),
      );
    });

class CoupleCalendarEventEditorData {
  const CoupleCalendarEventEditorData({
    required this.event,
    required this.drawing,
  });

  final CoupleCalendarEvent event;
  final AppDrawingData drawing;
}

class CoupleCalendarEventEditorService {
  CoupleCalendarEventEditorService({
    required CoupleCalendarEventRepository repository,
    required DeviceCalendarSyncCoordinator deviceCalendarSyncCoordinator,
    AppDrawingArtifactCodec artworkCodec = const AppDrawingArtifactCodec(),
  }) : _repository = repository,
       _deviceCalendarSyncCoordinator = deviceCalendarSyncCoordinator,
       _artworkCodec = artworkCodec;

  final CoupleCalendarEventRepository _repository;
  final DeviceCalendarSyncCoordinator _deviceCalendarSyncCoordinator;
  final AppDrawingArtifactCodec _artworkCodec;

  Future<CoupleCalendarEventEditorData?> load(String eventId) async {
    final event = await _repository.fetchEvent(eventId);
    if (event == null) {
      return null;
    }

    final drawingDataPath = event.artwork?.drawingDataPath;
    final drawing = drawingDataPath == null
        ? AppDrawingData.empty()
        : await _artworkCodec.decodeDrawingData(
            await _repository.fetchArtworkDrawingData(drawingDataPath),
          );
    return CoupleCalendarEventEditorData(event: event, drawing: drawing);
  }

  Future<CoupleCalendarEvent> save({
    required String coupleId,
    required CoupleCalendarEventSaveRequest request,
    required AppDrawingData drawing,
    required bool drawingChanged,
  }) async {
    late final CoupleCalendarEvent event;
    if (!drawingChanged) {
      event = await _repository.saveEvent(coupleId: coupleId, request: request);
    } else if (!drawing.hasVisibleContent) {
      event = await _repository.saveEvent(
        coupleId: coupleId,
        request: _copyRequest(request, removeArtwork: true),
      );
    } else {
      final artifact = await _artworkCodec.encode(drawing);
      event = await _repository.saveEvent(
        coupleId: coupleId,
        request: _copyRequest(request, removeArtwork: false),
        previewBytes: artifact.previewBytes,
        drawingDataBytes: artifact.drawingDataBytes,
      );
    }
    await _deviceCalendarSyncCoordinator.scheduleUpsert(event);
    return event;
  }

  CoupleCalendarEventSaveRequest _copyRequest(
    CoupleCalendarEventSaveRequest request, {
    required bool removeArtwork,
  }) {
    return CoupleCalendarEventSaveRequest(
      eventId: request.eventId,
      title: request.title,
      eventDate: request.eventDate,
      repeatRule: request.repeatRule,
      memo: request.memo,
      expectedRevision: request.expectedRevision,
      removeArtwork: removeArtwork,
      reminder: request.reminder,
    );
  }
}
