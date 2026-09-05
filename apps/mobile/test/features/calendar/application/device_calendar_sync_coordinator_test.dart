import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/calendar/application/device_calendar_sync_coordinator.dart';
import 'package:vinscent/features/calendar/data/couple_calendar_event.dart';
import 'package:vinscent/features/calendar/data/device_calendar_gateway.dart';
import 'package:vinscent/features/calendar/data/device_calendar_sync.dart';

void main() {
  test('사용자가 선택한 캘린더에 동기화를 켜고 기존 미래 일정도 반영한다', () async {
    final store = InMemoryDeviceCalendarSyncStore(
      DeviceCalendarSyncState.disabled(),
    );
    final gateway = _FakeDeviceCalendarGateway();
    final coordinator = DeviceCalendarSyncCoordinator(
      gateway: gateway,
      store: store,
      eventSource: _FakeDeviceCalendarSyncEventSource([_event()]),
      currentUserId: () => 'user-id',
      currentDate: () => DateTime(2026, 9, 5),
    );

    await coordinator.enable(calendar: _calendar, includeExistingEvents: true);

    final state = await store.read(userId: 'user-id');
    expect(state.enabled, isTrue);
    expect(state.calendar?.id, _calendar.id);
    expect(state.mappings, contains('event-id'));
    expect(gateway.upsertedEvents, hasLength(1));
  });

  test('동기화만 중지하면 기기 일정과 매핑을 보존한다', () async {
    final mapping = DeviceCalendarEventMapping(
      externalEventId: 'external-event-id',
      syncedRevision: 4,
      event: DeviceCalendarEventPayload.fromEvent(_event()),
    );
    final store = InMemoryDeviceCalendarSyncStore(
      DeviceCalendarSyncState(
        enabled: true,
        calendar: _calendar,
        queue: DeviceCalendarSyncQueue.empty(),
        mappings: {'event-id': mapping},
      ),
    );
    final gateway = _FakeDeviceCalendarGateway();
    final coordinator = DeviceCalendarSyncCoordinator(
      gateway: gateway,
      store: store,
      eventSource: const _FakeDeviceCalendarSyncEventSource(),
      currentUserId: () => 'user-id',
      currentDate: () => DateTime(2026, 9, 5),
    );

    await coordinator.disable(deleteMirroredEvents: false);

    final state = await store.read(userId: 'user-id');
    expect(state.enabled, isFalse);
    expect(state.mappings, contains('event-id'));
    expect(gateway.deletedEventIds, isEmpty);
  });

  test('동기화 해제와 함께 단짠이 만든 기기 일정을 정리한다', () async {
    final mapping = DeviceCalendarEventMapping(
      externalEventId: 'external-event-id',
      syncedRevision: 4,
      event: DeviceCalendarEventPayload.fromEvent(_event()),
    );
    final store = InMemoryDeviceCalendarSyncStore(
      DeviceCalendarSyncState(
        enabled: true,
        calendar: _calendar,
        queue: DeviceCalendarSyncQueue.empty(),
        mappings: {'event-id': mapping},
      ),
    );
    final gateway = _FakeDeviceCalendarGateway();
    final coordinator = DeviceCalendarSyncCoordinator(
      gateway: gateway,
      store: store,
      eventSource: const _FakeDeviceCalendarSyncEventSource(),
      currentUserId: () => 'user-id',
      currentDate: () => DateTime(2026, 9, 5),
    );

    await coordinator.disable(deleteMirroredEvents: true);

    final state = await store.read(userId: 'user-id');
    expect(state.enabled, isFalse);
    expect(state.calendar, isNull);
    expect(state.mappings, isEmpty);
    expect(gateway.deletedEventIds, ['event-id']);
    expect(gateway.deletedEventDates, [mapping.event.eventDate]);
  });

  test('기기 저장 실패는 단짠 저장을 실패시키지 않고 재시도 작업을 남긴다', () async {
    final store = InMemoryDeviceCalendarSyncStore(
      DeviceCalendarSyncState.enabled(
        calendar: const DeviceCalendarDescriptor(
          id: 'calendar-id',
          name: '내 캘린더',
          accountName: 'user@example.com',
        ),
      ),
    );
    final gateway = _FakeDeviceCalendarGateway(shouldFailUpsert: true);
    final coordinator = DeviceCalendarSyncCoordinator(
      gateway: gateway,
      store: store,
      eventSource: const _FakeDeviceCalendarSyncEventSource(),
      currentUserId: () => 'user-id',
      currentDate: () => DateTime(2026, 9, 5),
    );

    await expectLater(coordinator.scheduleUpsert(_event()), completes);
    await coordinator.synchronize();

    final state = await store.read(userId: 'user-id');
    expect(state.queue.operations, hasLength(1));
    expect(state.queue.operations.single.attempts, 2);
    expect(state.mappings, isEmpty);
  });

  test('저장 성공 후 외부 ID와 동기화한 revision을 기록한다', () async {
    final store = InMemoryDeviceCalendarSyncStore(
      DeviceCalendarSyncState.enabled(
        calendar: const DeviceCalendarDescriptor(
          id: 'calendar-id',
          name: '내 캘린더',
          accountName: 'user@example.com',
        ),
      ),
    );
    final gateway = _FakeDeviceCalendarGateway();
    final coordinator = DeviceCalendarSyncCoordinator(
      gateway: gateway,
      store: store,
      eventSource: const _FakeDeviceCalendarSyncEventSource(),
      currentUserId: () => 'user-id',
      currentDate: () => DateTime(2026, 9, 5),
    );

    await coordinator.scheduleUpsert(_event());
    await coordinator.synchronize();

    final state = await store.read(userId: 'user-id');
    expect(state.queue.operations, isEmpty);
    expect(state.mappings['event-id']?.externalEventId, 'external-event-id');
    expect(state.mappings['event-id']?.syncedRevision, 4);
    expect(gateway.upsertedEvents.single.memo, '메모');
    expect(
      gateway.upsertedEvents.single.repeatRule,
      CoupleCalendarEventRepeatRule.yearly,
    );
  });

  test('기기 캘린더가 느려도 동기화 큐 저장까지만 기다린다', () async {
    final nativeWrite = Completer<String>();
    final store = InMemoryDeviceCalendarSyncStore(
      DeviceCalendarSyncState.enabled(calendar: _calendar),
    );
    final coordinator = DeviceCalendarSyncCoordinator(
      gateway: _FakeDeviceCalendarGateway(upsertCompleter: nativeWrite),
      store: store,
      eventSource: const _FakeDeviceCalendarSyncEventSource(),
      currentUserId: () => 'user-id',
      currentDate: () => DateTime(2026, 9, 5),
    );

    await coordinator
        .scheduleUpsert(_event())
        .timeout(const Duration(milliseconds: 200));

    final queued = await store.read(userId: 'user-id');
    expect(queued.queue.operations, hasLength(1));
    expect(queued.mappings, isEmpty);

    nativeWrite.complete('external-event-id');
    await coordinator.synchronize();
    final synchronized = await store.read(userId: 'user-id');
    expect(synchronized.queue.operations, isEmpty);
    expect(synchronized.mappings, contains('event-id'));
  });

  test('외부 ID가 바뀌 일정 수정을 찾도록 이전 날짜를 전달한다', () async {
    final previous = _event(eventDate: DateTime(2026, 8, 20), revision: 3);
    final store = InMemoryDeviceCalendarSyncStore(
      DeviceCalendarSyncState(
        enabled: true,
        calendar: _calendar,
        queue: DeviceCalendarSyncQueue.empty(),
        mappings: {
          previous.id: DeviceCalendarEventMapping(
            externalEventId: 'old-external-id',
            syncedRevision: previous.revision,
            event: DeviceCalendarEventPayload.fromEvent(previous),
          ),
        },
      ),
    );
    final gateway = _FakeDeviceCalendarGateway();
    final coordinator = DeviceCalendarSyncCoordinator(
      gateway: gateway,
      store: store,
      eventSource: const _FakeDeviceCalendarSyncEventSource(),
      currentUserId: () => 'user-id',
      currentDate: () => DateTime(2026, 9, 5),
    );

    await coordinator.scheduleUpsert(_event());
    await coordinator.synchronize();

    expect(gateway.previousEventDates.single, previous.eventDate);
  });

  test('한 일정의 동기화 실패가 다른 일정을 막지 않는다', () async {
    final first = _event(id: 'first-event');
    final second = _event(id: 'second-event');
    final store = InMemoryDeviceCalendarSyncStore(
      DeviceCalendarSyncState(
        enabled: true,
        calendar: _calendar,
        queue: DeviceCalendarSyncQueue.empty()
            .enqueueUpsert(first)
            .enqueueUpsert(second),
        mappings: const {},
      ),
    );
    final gateway = _FakeDeviceCalendarGateway(
      failingUpsertEventIds: const {'first-event'},
    );
    final coordinator = DeviceCalendarSyncCoordinator(
      gateway: gateway,
      store: store,
      eventSource: const _FakeDeviceCalendarSyncEventSource(),
      currentUserId: () => 'user-id',
      currentDate: () => DateTime(2026, 9, 5),
    );

    await coordinator.synchronize();

    final state = await store.read(userId: 'user-id');
    expect(gateway.upsertedEvents.map((event) => event.sourceEventId), [
      'first-event',
      'second-event',
    ]);
    expect(state.queue.operations, hasLength(1));
    expect(state.queue.operations.single.event?.sourceEventId, 'first-event');
    expect(state.queue.operations.single.attempts, 1);
    expect(state.mappings, contains('second-event'));
  });
}

class _FakeDeviceCalendarGateway implements DeviceCalendarGateway {
  _FakeDeviceCalendarGateway({
    this.shouldFailUpsert = false,
    this.failingUpsertEventIds = const {},
    this.upsertCompleter,
  });

  final bool shouldFailUpsert;
  final Set<String> failingUpsertEventIds;
  final Completer<String>? upsertCompleter;
  final List<DeviceCalendarEventPayload> upsertedEvents = [];
  final List<DateTime?> previousEventDates = [];
  final List<String> deletedEventIds = [];
  final List<DateTime> deletedEventDates = [];

  @override
  Future<DeviceCalendarAuthorizationStatus> authorizationStatus() async {
    return DeviceCalendarAuthorizationStatus.authorized;
  }

  @override
  Future<void> openSettings() async {}

  @override
  Future<void> deleteEvent({
    required String calendarId,
    required String sourceEventId,
    required String externalEventId,
    required DateTime eventDate,
  }) async {
    deletedEventIds.add(sourceEventId);
    deletedEventDates.add(eventDate);
  }

  @override
  Future<List<DeviceCalendarDescriptor>> listWritableCalendars() async {
    return const [];
  }

  @override
  Future<DeviceCalendarAuthorizationStatus> requestFullAccess() async {
    return DeviceCalendarAuthorizationStatus.authorized;
  }

  @override
  Future<String> upsertEvent({
    required String calendarId,
    required DeviceCalendarEventPayload event,
    String? externalEventId,
    DateTime? previousEventDate,
  }) async {
    upsertedEvents.add(event);
    previousEventDates.add(previousEventDate);
    if (shouldFailUpsert || failingUpsertEventIds.contains(event.sourceEventId)) {
      throw Exception('device calendar unavailable');
    }
    if (upsertCompleter case final completer?) {
      return completer.future;
    }
    return 'external-event-id';
  }
}

class _FakeDeviceCalendarSyncEventSource
    implements DeviceCalendarSyncEventSource {
  const _FakeDeviceCalendarSyncEventSource([
    this.events = const <CoupleCalendarEvent>[],
  ]);

  final List<CoupleCalendarEvent> events;

  @override
  Future<List<CoupleCalendarEvent>> fetchFutureEvents(DateTime fromDate) async {
    return events;
  }
}

const _calendar = DeviceCalendarDescriptor(
  id: 'calendar-id',
  name: '내 캘린더',
  accountName: 'user@example.com',
);

CoupleCalendarEvent _event({
  String id = 'event-id',
  DateTime? eventDate,
  int revision = 4,
}) {
  final resolvedEventDate = eventDate ?? DateTime(2026, 9, 10);
  return CoupleCalendarEvent(
    id: id,
    coupleId: 'couple-id',
    title: '기념일',
    eventDate: resolvedEventDate,
    occurrenceDate: resolvedEventDate,
    repeatRule: CoupleCalendarEventRepeatRule.yearly,
    memo: '메모',
    revision: revision,
    createdByUserId: 'user-a',
    updatedByUserId: 'user-b',
    createdAt: DateTime(2026, 9, 1),
    updatedAt: DateTime(2026, 9, 2),
    reminder: const CoupleCalendarEventReminder.disabled(),
  );
}
