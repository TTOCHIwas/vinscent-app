import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/calendar/data/couple_calendar_event.dart';
import 'package:vinscent/features/calendar/data/couple_calendar_event_data_gateways.dart';
import 'package:vinscent/features/calendar/data/couple_calendar_event_repository_contract.dart';
import 'package:vinscent/features/calendar/data/default_couple_calendar_event_repository.dart';

void main() {
  test('saves metadata without uploading when artwork is unchanged', () async {
    final gateway = _FakeEventGateway();
    final artworkStore = _FakeArtworkStore();
    final repository = DefaultCoupleCalendarEventRepository(
      eventGateway: gateway,
      artworkStore: artworkStore,
    );

    await repository.saveEvent(coupleId: 'couple-id', request: _request());

    expect(artworkStore.uploadCount, 0);
    expect(gateway.lastArtworkRevision, isNull);
    expect(artworkStore.discardedArtifactIds, isEmpty);
  });

  test(
    'discards an uploaded artwork revision when metadata save fails',
    () async {
      final gateway = _FakeEventGateway()..saveError = StateError('conflict');
      final artworkStore = _FakeArtworkStore();
      final repository = DefaultCoupleCalendarEventRepository(
        eventGateway: gateway,
        artworkStore: artworkStore,
      );

      await expectLater(
        repository.saveEvent(
          coupleId: 'couple-id',
          request: _request(),
          previewBytes: Uint8List.fromList([1]),
          drawingDataBytes: Uint8List.fromList([2]),
        ),
        throwsStateError,
      );

      expect(artworkStore.uploadCount, 1);
      expect(artworkStore.discardedArtifactIds, ['artifact-id']);
    },
  );
}

CoupleCalendarEventSaveRequest _request() {
  return CoupleCalendarEventSaveRequest(
    eventId: 'event-id',
    title: '첫 여행',
    eventDate: DateTime(2026, 7, 26),
    repeatRule: CoupleCalendarEventRepeatRule.none,
    memo: null,
    expectedRevision: null,
    removeArtwork: false,
    reminder: const CoupleCalendarEventReminder.disabled(),
  );
}

class _FakeEventGateway implements CoupleCalendarEventGateway {
  Object? saveError;
  String? lastArtworkRevision;

  @override
  Future<void> deleteEvent({
    required String eventId,
    required int expectedRevision,
  }) async {}

  @override
  Future<CoupleCalendarEvent?> fetchEvent(String eventId) async => null;

  @override
  Future<List<CoupleCalendarEvent>> fetchOccurrences({
    required DateTime startDate,
    required DateTime endDate,
  }) async => const [];

  @override
  Future<CoupleCalendarEvent> saveEvent({
    required CoupleCalendarEventSaveRequest request,
    required String? artworkRevision,
  }) async {
    lastArtworkRevision = artworkRevision;
    final error = saveError;
    if (error != null) {
      throw error;
    }
    return _savedEvent;
  }
}

class _FakeArtworkStore implements CoupleCalendarEventArtworkStore {
  var uploadCount = 0;
  final discardedArtifactIds = <String>[];

  @override
  Future<void> discardUploadedArtwork({
    required String eventId,
    required String artifactId,
  }) async {
    discardedArtifactIds.add(artifactId);
  }

  @override
  Future<Uint8List> fetchDrawingData(String path) async => Uint8List(0);

  @override
  Future<String> uploadArtwork({
    required String coupleId,
    required String eventId,
    required Uint8List previewBytes,
    required Uint8List drawingDataBytes,
  }) async {
    uploadCount += 1;
    return 'artifact-id';
  }
}

final _savedEvent = CoupleCalendarEvent(
  id: 'event-id',
  coupleId: 'couple-id',
  title: '첫 여행',
  eventDate: DateTime(2026, 7, 26),
  occurrenceDate: DateTime(2026, 7, 26),
  repeatRule: CoupleCalendarEventRepeatRule.none,
  memo: null,
  revision: 1,
  createdByUserId: 'user-a',
  updatedByUserId: 'user-a',
  createdAt: DateTime(2026, 7, 26),
  updatedAt: DateTime(2026, 7, 26),
  reminder: const CoupleCalendarEventReminder.disabled(),
);
