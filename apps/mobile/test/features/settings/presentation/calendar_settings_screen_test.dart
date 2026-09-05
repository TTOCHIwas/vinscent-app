import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vinscent/features/calendar/application/calendar_cell_preview_mode_controller.dart';
import 'package:vinscent/features/calendar/application/device_calendar_sync_coordinator.dart';
import 'package:vinscent/features/calendar/application/public_holiday_controller.dart';
import 'package:vinscent/features/calendar/data/couple_calendar_event.dart';
import 'package:vinscent/features/calendar/data/device_calendar_gateway.dart';
import 'package:vinscent/features/calendar/data/device_calendar_sync.dart';
import 'package:vinscent/features/calendar/data/public_holiday.dart';
import 'package:vinscent/features/calendar/data/public_holiday_region_preference_store.dart';
import 'package:vinscent/features/settings/presentation/calendar_settings_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('권한 승인 뒤 선택한 캘린더에 기존 일정 포함 동기화를 켠다', (tester) async {
    final store = InMemoryDeviceCalendarSyncStore(
      DeviceCalendarSyncState.disabled(),
    );
    final gateway = _FakeDeviceCalendarGateway();
    await _pumpCalendarSettings(tester, gateway: gateway, store: store);

    await tester.tap(find.byKey(const Key('device-calendar-sync-toggle')));
    await tester.pumpAndSettle();

    expect(gateway.permissionRequestCount, 1);
    await tester.tap(find.text('내 캘린더'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('기존 일정도 추가'));
    await tester.pumpAndSettle();

    final state = await store.read(userId: 'user-id');
    expect(state.enabled, isTrue);
    expect(state.calendar?.id, 'calendar-id');
  });

  testWidgets('대한민국 공휴일 표시를 사용자가 끌 수 있다', (tester) async {
    final store = InMemoryDeviceCalendarSyncStore(
      DeviceCalendarSyncState.disabled(),
    );
    await _pumpCalendarSettings(
      tester,
      gateway: _FakeDeviceCalendarGateway(),
      store: store,
    );

    final toggle = find.byKey(const Key('south-korea-holiday-toggle'));
    final switchTile = find.descendant(
      of: toggle,
      matching: find.byType(SwitchListTile),
    );
    expect(tester.widget<SwitchListTile>(switchTile).value, isTrue);

    await tester.tap(toggle);
    await tester.pumpAndSettle();

    expect(tester.widget<SwitchListTile>(switchTile).value, isFalse);
  });

  testWidgets('이미 거부된 권한은 다시 요청하지 않고 기기 설정을 연다', (tester) async {
    final gateway = _FakeDeviceCalendarGateway(
      initialAuthorization: DeviceCalendarAuthorizationStatus.denied,
    );
    await _pumpCalendarSettings(
      tester,
      gateway: gateway,
      store: InMemoryDeviceCalendarSyncStore(
        DeviceCalendarSyncState.disabled(),
      ),
    );

    await tester.tap(find.byKey(const Key('device-calendar-sync-toggle')));
    await tester.pumpAndSettle();

    expect(gateway.permissionRequestCount, 0);
    expect(gateway.openSettingsCount, 1);
  });

  testWidgets('동기화가 꺼져도 남은 기기 일정 작업을 다시 시도할 수 있다', (tester) async {
    const calendar = DeviceCalendarDescriptor(id: 'calendar-id', name: '내 캘린더');
    final event = DeviceCalendarEventPayload(
      sourceEventId: 'event-id',
      title: '기념일',
      eventDate: DateTime(2026, 9, 5),
      repeatRule: CoupleCalendarEventRepeatRule.none,
      memo: null,
      revision: 1,
    );
    final state = DeviceCalendarSyncState(
      enabled: false,
      calendar: calendar,
      queue: DeviceCalendarSyncQueue([
        DeviceCalendarSyncOperation(
          type: DeviceCalendarSyncOperationType.delete,
          event: event,
        ),
      ]),
      mappings: const {},
    );

    await _pumpCalendarSettings(
      tester,
      gateway: _FakeDeviceCalendarGateway(
        initialAuthorization: DeviceCalendarAuthorizationStatus.denied,
      ),
      store: InMemoryDeviceCalendarSyncStore(state),
    );

    expect(find.text('남은 기기 일정 정리'), findsOneWidget);
    expect(find.text('기기 설정에서 권한 허용'), findsOneWidget);
  });
}

Future<void> _pumpCalendarSettings(
  WidgetTester tester, {
  required DeviceCalendarGateway gateway,
  required DeviceCalendarSyncStore store,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        calendarPreferenceUserIdProvider.overrideWithValue('user-id'),
        publicHolidayDeviceLocaleProvider.overrideWithValue(
          const Locale('ko', 'KR'),
        ),
        deviceCalendarGatewayProvider.overrideWithValue(gateway),
        deviceCalendarSyncStoreProvider.overrideWithValue(store),
        deviceCalendarSyncEventSourceProvider.overrideWithValue(
          const _EmptyDeviceCalendarSyncEventSource(),
        ),
        publicHolidayRegionPreferenceStoreProvider.overrideWithValue(
          _InMemoryPublicHolidayRegionPreferenceStore(),
        ),
      ],
      child: const MaterialApp(home: Scaffold(body: CalendarSettingsScreen())),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeDeviceCalendarGateway implements DeviceCalendarGateway {
  _FakeDeviceCalendarGateway({
    this.initialAuthorization = DeviceCalendarAuthorizationStatus.notDetermined,
  });

  final DeviceCalendarAuthorizationStatus initialAuthorization;
  var permissionRequestCount = 0;
  var openSettingsCount = 0;

  @override
  Future<DeviceCalendarAuthorizationStatus> authorizationStatus() async {
    return permissionRequestCount == 0
        ? initialAuthorization
        : DeviceCalendarAuthorizationStatus.authorized;
  }

  @override
  Future<void> openSettings() async {
    openSettingsCount += 1;
  }

  @override
  Future<DeviceCalendarAuthorizationStatus> requestFullAccess() async {
    permissionRequestCount += 1;
    return DeviceCalendarAuthorizationStatus.authorized;
  }

  @override
  Future<List<DeviceCalendarDescriptor>> listWritableCalendars() async {
    return const [
      DeviceCalendarDescriptor(
        id: 'calendar-id',
        name: '내 캘린더',
        accountName: 'user@example.com',
        isPrimary: true,
      ),
    ];
  }

  @override
  Future<String> upsertEvent({
    required String calendarId,
    required DeviceCalendarEventPayload event,
    String? externalEventId,
    DateTime? previousEventDate,
  }) async {
    return externalEventId ?? 'external-event-id';
  }

  @override
  Future<void> deleteEvent({
    required String calendarId,
    required String sourceEventId,
    required String externalEventId,
    required DateTime eventDate,
  }) async {}
}

class _EmptyDeviceCalendarSyncEventSource
    implements DeviceCalendarSyncEventSource {
  const _EmptyDeviceCalendarSyncEventSource();

  @override
  Future<List<CoupleCalendarEvent>> fetchFutureEvents(DateTime fromDate) async {
    return const [];
  }
}

class _InMemoryPublicHolidayRegionPreferenceStore
    implements PublicHolidayRegionPreferenceStore {
  PublicHolidayRegion? region;

  @override
  Future<PublicHolidayRegion?> read({required String userId}) async => region;

  @override
  Future<void> write({
    required String userId,
    required PublicHolidayRegion region,
  }) async {
    this.region = region;
  }

  @override
  Future<void> clearForUser(String userId) async {
    region = null;
  }
}
