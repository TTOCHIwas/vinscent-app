import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/calendar/application/couple_calendar_event_provider.dart';
import 'package:vinscent/features/calendar/data/couple_calendar_event.dart';
import 'package:vinscent/features/calendar/data/couple_calendar_event_data_gateways.dart';
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

  test('reuses the month result and filters only the selected date', () async {
    final selectedDate = DateTime(2026, 5, 10);
    final repository = _FakeCalendarEventRepository(
      events: [
        _calendarEvent(id: 'selected', date: selectedDate),
        _calendarEvent(id: 'other', date: DateTime(2026, 5, 11)),
      ],
    );
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

    final events = await container.read(
      coupleCalendarEventDateProvider(DateTime(2026, 5, 10, 23, 30)).future,
    );

    expect(repository.requestedRanges, [
      (DateTime(2026, 5, 1), DateTime(2026, 5, 31)),
    ]);
    expect(events.map((event) => event.id), ['selected']);
  });

  test('checks calendar attention without loading event rows', () async {
    final gateway = _FakeCalendarEventGateway(hasOccurrence: true);
    final container = ProviderContainer(
      overrides: [
        coupleControllerProvider.overrideWithBuild(
          (ref, notifier) async => activeCouple(
            relationshipStartDate: DateTime(2026, 5, 1),
            currentDate: DateTime(2026, 5, 10),
          ),
        ),
        coupleCalendarEventGatewayProvider.overrideWithValue(gateway),
      ],
    );
    addTearDown(container.dispose);

    final hasOccurrence = await container.read(
      coupleCalendarEventHasOccurrenceProvider(
        DateTime(2026, 5, 10, 23, 30),
      ).future,
    );

    expect(hasOccurrence, isTrue);
    expect(gateway.requestedDates, [DateTime(2026, 5, 10)]);
  });

  test('groups month events once into stable date buckets', () async {
    final date = DateTime(2026, 5, 10);
    final repository = _FakeCalendarEventRepository(
      events: [
        _calendarEvent(id: 'first', date: date),
        _calendarEvent(id: 'second', date: date),
      ],
    );
    final container = ProviderContainer(
      overrides: [
        coupleControllerProvider.overrideWithBuild(
          (ref, notifier) async => activeCouple(
            relationshipStartDate: DateTime(2026, 5, 1),
            currentDate: date,
          ),
        ),
        coupleCalendarEventRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    final provider = coupleCalendarEventsByDateProvider(DateTime(2026, 5));
    final first = await container.read(provider.future);
    final second = container.read(provider).requireValue;

    expect(first[date]?.map((event) => event.id), ['first', 'second']);
    expect(identical(first, second), isTrue);
    expect(repository.requestedRanges, [
      (DateTime(2026, 5, 1), DateTime(2026, 5, 31)),
    ]);
  });
}

class _FakeCalendarEventRepository implements CoupleCalendarEventRepository {
  _FakeCalendarEventRepository({this.events = const []});

  final requestedRanges = <(DateTime, DateTime)>[];
  final List<CoupleCalendarEvent> events;

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
    return events;
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

CoupleCalendarEvent _calendarEvent({
  required String id,
  required DateTime date,
}) {
  return CoupleCalendarEvent(
    id: id,
    coupleId: 'couple-id',
    title: '일정',
    eventDate: date,
    occurrenceDate: date,
    repeatRule: CoupleCalendarEventRepeatRule.none,
    memo: null,
    revision: 1,
    createdByUserId: 'user-a',
    updatedByUserId: 'user-a',
    createdAt: DateTime(2026, 5, 1),
    updatedAt: DateTime(2026, 5, 1),
    reminder: const CoupleCalendarEventReminder.disabled(),
  );
}

class _FakeCalendarEventGateway implements CoupleCalendarEventGateway {
  _FakeCalendarEventGateway({required this.hasOccurrence});

  final bool hasOccurrence;
  final requestedDates = <DateTime>[];

  @override
  Future<bool> hasOccurrenceOn(DateTime date) async {
    requestedDates.add(date);
    return hasOccurrence;
  }

  @override
  Future<void> deleteEvent({
    required String eventId,
    required int expectedRevision,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<CoupleCalendarEvent?> fetchEvent(String eventId) {
    throw UnimplementedError();
  }

  @override
  Future<List<CoupleCalendarEvent>> fetchOccurrences({
    required DateTime startDate,
    required DateTime endDate,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<CoupleCalendarEvent> saveEvent({
    required CoupleCalendarEventSaveRequest request,
    required String? artworkRevision,
  }) {
    throw UnimplementedError();
  }
}
