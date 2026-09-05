import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/calendar/application/device_calendar_sync_coordinator.dart';
import 'package:vinscent/features/calendar/data/couple_calendar_event.dart';
import 'package:vinscent/features/calendar/data/device_calendar_gateway.dart';
import 'package:vinscent/features/calendar/data/device_calendar_sync.dart';

void main() {
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

    final state = await store.read(userId: 'user-id');
    expect(state.queue.operations, hasLength(1));
    expect(state.queue.operations.single.attempts, 1);
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

    final state = await store.read(userId: 'user-id');
    expect(state.queue.operations, isEmpty);
    expect(state.mappings['event-id']?.externalEventId, 'external-event-id');
    expect(state.mappings['event-id']?.syncedRevision, 4);
    expect(gateway.upsertedEvents.single.memo, '메모');
    expect(gateway.upsertedEvents.single.repeatRule, CoupleCalendarEventRepeatRule.yearly);
  });
}

class _FakeDeviceCalendarGateway implements DeviceCalendarGateway {
  _FakeDeviceCalendarGateway({this.shouldFailUpsert = false});

  final bool shouldFailUpsert;
  final List<DeviceCalendarEventPayload> upsertedEvents = [];

  @override
  Future<DeviceCalendarAuthorizationStatus> authorizationStatus() async {
    return DeviceCalendarAuthorizationStatus.authorized;
  }

  @override
  Future<void> deleteEvent({
    required String calendarId,
    required String sourceEventId,
    required String externalEventId,
  }) async {}

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
  }) async {
    upsertedEvents.add(event);
    if (shouldFailUpsert) {
      throw Exception('device calendar unavailable');
    }
    return 'external-event-id';
  }
}

class _FakeDeviceCalendarSyncEventSource
    implements DeviceCalendarSyncEventSource {
  const _FakeDeviceCalendarSyncEventSource();

  @override
  Future<List<CoupleCalendarEvent>> fetchFutureEvents(DateTime fromDate) async {
    return const [];
  }
}

CoupleCalendarEvent _event() {
  return CoupleCalendarEvent(
    id: 'event-id',
    coupleId: 'couple-id',
    title: '기념일',
    eventDate: DateTime(2026, 9, 10),
    occurrenceDate: DateTime(2026, 9, 10),
    repeatRule: CoupleCalendarEventRepeatRule.yearly,
    memo: '메모',
    revision: 4,
    createdByUserId: 'user-a',
    updatedByUserId: 'user-b',
    createdAt: DateTime(2026, 9, 1),
    updatedAt: DateTime(2026, 9, 2),
    reminder: const CoupleCalendarEventReminder.disabled(),
  );
}
