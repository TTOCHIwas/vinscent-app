import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/calendar/application/couple_calendar_event_provider.dart';
import 'package:vinscent/features/calendar/data/couple_calendar_event.dart';
import 'package:vinscent/features/calendar/data/couple_calendar_event_repository.dart';
import 'package:vinscent/features/couple/application/couple_controller.dart';

import '../../../support/couple_fixtures.dart';

void main() {
  test('loads events for a future month', () async {
    final repository = _FakeCalendarEventRepository();
    final container = ProviderContainer(
      overrides: [
        coupleControllerProvider.overrideWithBuild(
          (ref, notifier) async => activeCouple(
            relationshipStartDate: DateTime(2026, 5, 1),
            currentDate: DateTime(2026, 5, 10),
          ),
        ),
        coupleCalendarEventRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    await container.read(
      coupleCalendarEventMonthProvider(DateTime(2026, 8)).future,
    );

    expect(repository.requestedRanges, [
      (DateTime(2026, 8, 1), DateTime(2026, 8, 31)),
    ]);
  });

  test('does not query a month before the relationship started', () async {
    final repository = _FakeCalendarEventRepository();
    final container = ProviderContainer(
      overrides: [
        coupleControllerProvider.overrideWithBuild(
          (ref, notifier) async =>
              activeCouple(relationshipStartDate: DateTime(2026, 5, 1)),
        ),
        coupleCalendarEventRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    final events = await container.read(
      coupleCalendarEventMonthProvider(DateTime(2026, 4)).future,
    );

    expect(events, isEmpty);
    expect(repository.requestedRanges, isEmpty);
  });

  test('loads only the selected date for a detail-only request', () async {
    final repository = _FakeCalendarEventRepository();
    final container = ProviderContainer(
      overrides: [
        coupleControllerProvider.overrideWithBuild(
          (ref, notifier) async => activeCouple(
            relationshipStartDate: DateTime(2026, 5, 1),
            currentDate: DateTime(2026, 5, 10),
          ),
        ),
        coupleCalendarEventRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    await container.read(
      coupleCalendarEventDateProvider(DateTime(2026, 5, 10, 23, 30)).future,
    );

    expect(repository.requestedRanges, [
      (DateTime(2026, 5, 10), DateTime(2026, 5, 10)),
    ]);
  });
}

class _FakeCalendarEventRepository implements CoupleCalendarEventRepository {
  final requestedRanges = <(DateTime, DateTime)>[];

  @override
  Future<void> deleteEvent({
    required String eventId,
    required int expectedRevision,
  }) async {}

  @override
  Future<CoupleCalendarEvent?> fetchEvent(String eventId) async => null;

  @override
  Future<Uint8List> fetchArtworkDrawingData(String drawingDataPath) async {
    return Uint8List(0);
  }

  @override
  Future<List<CoupleCalendarEvent>> fetchOccurrences({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    requestedRanges.add((startDate, endDate));
    return const [];
  }

  @override
  Future<CoupleCalendarEvent> saveEvent({
    required String coupleId,
    required CoupleCalendarEventSaveRequest request,
    Uint8List? previewBytes,
    Uint8List? drawingDataBytes,
  }) {
    throw UnimplementedError();
  }
}
