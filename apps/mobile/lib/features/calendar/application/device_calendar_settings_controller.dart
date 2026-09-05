import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/device_calendar_gateway.dart';
import '../data/device_calendar_sync.dart';
import 'device_calendar_sync_coordinator.dart';

final deviceCalendarSettingsControllerProvider =
    AsyncNotifierProvider<
      DeviceCalendarSettingsController,
      DeviceCalendarSettingsState
    >(DeviceCalendarSettingsController.new);

class DeviceCalendarSettingsState {
  const DeviceCalendarSettingsState({
    required this.sync,
    required this.authorization,
    required this.writableCalendars,
  });

  final DeviceCalendarSyncState sync;
  final DeviceCalendarAuthorizationStatus authorization;
  final List<DeviceCalendarDescriptor> writableCalendars;

  bool get isEnabled => sync.enabled && sync.calendar != null;
  bool get hasPendingOperations => sync.queue.operations.isNotEmpty;

  DeviceCalendarSettingsState copyWith({
    DeviceCalendarSyncState? sync,
    DeviceCalendarAuthorizationStatus? authorization,
    List<DeviceCalendarDescriptor>? writableCalendars,
  }) {
    return DeviceCalendarSettingsState(
      sync: sync ?? this.sync,
      authorization: authorization ?? this.authorization,
      writableCalendars: writableCalendars ?? this.writableCalendars,
    );
  }
}

class DeviceCalendarSettingsController
    extends AsyncNotifier<DeviceCalendarSettingsState> {
  @override
  Future<DeviceCalendarSettingsState> build() async {
    final coordinator = ref.watch(deviceCalendarSyncCoordinatorProvider);
    final results = await Future.wait<Object>([
      coordinator.readState(),
      coordinator.authorizationStatus(),
    ]);
    return DeviceCalendarSettingsState(
      sync: results[0] as DeviceCalendarSyncState,
      authorization: results[1] as DeviceCalendarAuthorizationStatus,
      writableCalendars: const [],
    );
  }

  Future<DeviceCalendarSettingsState> requestAccessAndLoadCalendars() async {
    final coordinator = ref.read(deviceCalendarSyncCoordinatorProvider);
    var authorization = await coordinator.authorizationStatus();
    if (authorization == DeviceCalendarAuthorizationStatus.notDetermined) {
      authorization = await coordinator.requestFullAccess();
    }
    final calendars =
        authorization == DeviceCalendarAuthorizationStatus.authorized
        ? await coordinator.listWritableCalendars()
        : const <DeviceCalendarDescriptor>[];
    final next = (state.asData?.value ?? await future).copyWith(
      authorization: authorization,
      writableCalendars: calendars,
    );
    state = AsyncValue.data(next);
    return next;
  }

  Future<void> openSettings() {
    return ref.read(deviceCalendarSyncCoordinatorProvider).openSettings();
  }

  Future<void> enable({
    required DeviceCalendarDescriptor calendar,
    required bool includeExistingEvents,
  }) async {
    await ref
        .read(deviceCalendarSyncCoordinatorProvider)
        .enable(
          calendar: calendar,
          includeExistingEvents: includeExistingEvents,
        );
    await refresh();
  }

  Future<void> disable({required bool deleteMirroredEvents}) async {
    await ref
        .read(deviceCalendarSyncCoordinatorProvider)
        .disable(deleteMirroredEvents: deleteMirroredEvents);
    await refresh();
  }

  Future<void> resynchronize() async {
    await ref
        .read(deviceCalendarSyncCoordinatorProvider)
        .synchronize(reconcile: true, force: true);
    await refresh();
  }

  Future<void> refresh() async {
    final coordinator = ref.read(deviceCalendarSyncCoordinatorProvider);
    final current = state.asData?.value;
    final sync = await coordinator.readState();
    final authorization = await coordinator.authorizationStatus();
    state = AsyncValue.data(
      DeviceCalendarSettingsState(
        sync: sync,
        authorization: authorization,
        writableCalendars:
            current?.writableCalendars ?? const <DeviceCalendarDescriptor>[],
      ),
    );
  }
}
