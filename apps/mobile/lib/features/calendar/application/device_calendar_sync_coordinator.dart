import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/date/app_date_policy.dart';
import '../data/couple_calendar_event.dart';
import '../data/couple_calendar_event_mapper.dart';
import '../data/device_calendar_gateway.dart';
import '../data/device_calendar_sync.dart';
import 'calendar_cell_preview_mode_controller.dart';

final deviceCalendarSyncEventSourceProvider =
    Provider<DeviceCalendarSyncEventSource>((ref) {
      return const SupabaseDeviceCalendarSyncEventSource();
    });

final deviceCalendarSyncCoordinatorProvider =
    Provider<DeviceCalendarSyncCoordinator>((ref) {
      return DeviceCalendarSyncCoordinator(
        gateway: ref.watch(deviceCalendarGatewayProvider),
        store: ref.watch(deviceCalendarSyncStoreProvider),
        eventSource: ref.watch(deviceCalendarSyncEventSourceProvider),
        currentUserId: () => ref.read(calendarPreferenceUserIdProvider),
        currentDate: currentAppDate,
      );
    });

abstract interface class DeviceCalendarSyncEventSource {
  Future<List<CoupleCalendarEvent>> fetchFutureEvents(DateTime fromDate);
}

class SupabaseDeviceCalendarSyncEventSource
    implements DeviceCalendarSyncEventSource {
  const SupabaseDeviceCalendarSyncEventSource({
    CoupleCalendarEventMapper mapper = const CoupleCalendarEventMapper(),
  }) : _mapper = mapper;

  final CoupleCalendarEventMapper _mapper;

  @override
  Future<List<CoupleCalendarEvent>> fetchFutureEvents(DateTime fromDate) async {
    if (!AppConfig.isSupabaseConfigured) {
      return const [];
    }
    final data = await Supabase.instance.client
        .rpc(
          'get_couple_calendar_events_for_device_sync',
          params: {'target_start_date': formatCalendarDate(fromDate)},
        )
        .timeout(AppConfig.supabaseRpcTimeout);
    if (data is! List) {
      return const [];
    }
    return data
        .whereType<Map>()
        .map(
          (row) => _mapper.mapOccurrence(
            Map<String, dynamic>.from(row),
            previewUrlsByPath: const {},
          ),
        )
        .toList(growable: false);
  }
}

class DeviceCalendarSyncCoordinator {
  DeviceCalendarSyncCoordinator({
    required DeviceCalendarGateway gateway,
    required DeviceCalendarSyncStore store,
    required DeviceCalendarSyncEventSource eventSource,
    required String? Function() currentUserId,
    required DateTime Function() currentDate,
  }) : _gateway = gateway,
       _store = store,
       _eventSource = eventSource,
       _currentUserId = currentUserId,
       _currentDate = currentDate;

  final DeviceCalendarGateway _gateway;
  final DeviceCalendarSyncStore _store;
  final DeviceCalendarSyncEventSource _eventSource;
  final String? Function() _currentUserId;
  final DateTime Function() _currentDate;
  Future<void> _serialWork = Future.value();

  Future<DeviceCalendarSyncState> readState() async {
    final userId = _currentUserId();
    if (userId == null) {
      return DeviceCalendarSyncState.disabled();
    }
    return _store.read(userId: userId);
  }

  Future<DeviceCalendarAuthorizationStatus> authorizationStatus() {
    return _gateway.authorizationStatus();
  }

  Future<DeviceCalendarAuthorizationStatus> requestFullAccess() {
    return _gateway.requestFullAccess();
  }

  Future<void> openSettings() {
    return _gateway.openSettings();
  }

  Future<List<DeviceCalendarDescriptor>> listWritableCalendars() {
    return _gateway.listWritableCalendars();
  }

  Future<void> enable({
    required DeviceCalendarDescriptor calendar,
    required bool includeExistingEvents,
  }) {
    return _run(() async {
      final userId = _requireCurrentUserId();
      final previous = await _store.read(userId: userId);
      final isSameCalendar = previous.calendar?.id == calendar.id;
      var state = DeviceCalendarSyncState(
        enabled: true,
        calendar: calendar,
        queue: isSameCalendar
            ? previous.queue.withoutDeletes()
            : DeviceCalendarSyncQueue.empty(),
        mappings: isSameCalendar ? previous.mappings : const {},
      );
      await _store.write(userId: userId, state: state);
      if (includeExistingEvents) {
        state = await _reconcile(userId: userId, state: state, force: true);
      }
      await _drain(userId, state);
    });
  }

  Future<void> disable({required bool deleteMirroredEvents}) {
    return _run(() async {
      final userId = _requireCurrentUserId();
      var state = await _store.read(userId: userId);
      if (!deleteMirroredEvents) {
        state = state.copyWith(enabled: false, queue: state.queue.clear());
        await _store.write(userId: userId, state: state);
        return;
      }

      var queue = DeviceCalendarSyncQueue.empty();
      for (final mapping in state.mappings.values) {
        queue = queue.enqueuePayload(
          DeviceCalendarSyncOperation(
            type: DeviceCalendarSyncOperationType.delete,
            event: mapping.event,
          ),
        );
      }
      state = state.copyWith(enabled: false, queue: queue);
      await _store.write(userId: userId, state: state);
      await _drain(userId, state);

      final drained = await _store.read(userId: userId);
      if (drained.queue.operations.isEmpty && drained.mappings.isEmpty) {
        await _store.write(
          userId: userId,
          state: DeviceCalendarSyncState.disabled(),
        );
      }
    });
  }

  Future<void> scheduleUpsert(CoupleCalendarEvent event) {
    return _runSafely(() async {
      final userId = _currentUserId();
      if (userId == null) {
        return;
      }
      var state = await _store.read(userId: userId);
      if (!state.enabled || state.calendar == null) {
        return;
      }
      state = state.copyWith(queue: state.queue.enqueueUpsert(event));
      await _store.write(userId: userId, state: state);
      unawaited(synchronize());
    });
  }

  Future<void> scheduleDelete(CoupleCalendarEvent event) {
    return _runSafely(() async {
      final userId = _currentUserId();
      if (userId == null) {
        return;
      }
      var state = await _store.read(userId: userId);
      if (!state.enabled || state.calendar == null) {
        return;
      }
      state = state.copyWith(queue: state.queue.enqueueDelete(event));
      await _store.write(userId: userId, state: state);
      unawaited(synchronize());
    });
  }

  Future<void> synchronize({bool reconcile = false, bool force = false}) {
    return _runSafely(() async {
      final userId = _currentUserId();
      if (userId == null) {
        return;
      }
      var state = await _store.read(userId: userId);
      if (reconcile && state.enabled && state.calendar != null) {
        state = await _reconcile(userId: userId, state: state, force: force);
      }
      await _drain(userId, state);
    });
  }

  Future<DeviceCalendarSyncState> _reconcile({
    required String userId,
    required DeviceCalendarSyncState state,
    required bool force,
  }) async {
    final sourceEvents = await _eventSource.fetchFutureEvents(_currentDate());
    final sourceById = {for (final event in sourceEvents) event.id: event};
    var queue = state.queue;
    for (final event in sourceEvents) {
      final mapping = state.mappings[event.id];
      if (force ||
          mapping == null ||
          mapping.syncedRevision != event.revision) {
        queue = queue.enqueueUpsert(event);
      }
    }
    for (final entry in state.mappings.entries) {
      if (sourceById.containsKey(entry.key)) {
        continue;
      }
      final mappedEvent = entry.value.event;
      if (mappedEvent.repeatRule == CoupleCalendarEventRepeatRule.yearly ||
          !mappedEvent.eventDate.isBefore(calendarDateOnly(_currentDate()))) {
        queue = queue.enqueuePayload(
          DeviceCalendarSyncOperation(
            type: DeviceCalendarSyncOperationType.delete,
            event: mappedEvent,
          ),
        );
      }
    }
    final nextState = state.copyWith(queue: queue);
    await _store.write(userId: userId, state: nextState);
    return nextState;
  }

  Future<void> _drain(String userId, DeviceCalendarSyncState state) async {
    final calendar = state.calendar;
    if (calendar == null || state.queue.operations.isEmpty) {
      return;
    }
    if (await _gateway.authorizationStatus() !=
        DeviceCalendarAuthorizationStatus.authorized) {
      return;
    }

    var current = state;
    for (final operation in List.of(state.queue.operations)) {
      try {
        final payload = operation.event!;
        final mapping = current.mappings[payload.sourceEventId];
        switch (operation.type) {
          case DeviceCalendarSyncOperationType.upsert:
            if (!current.enabled) {
              current = current.copyWith(
                queue: current.queue.remove(payload.sourceEventId),
              );
              break;
            }
            final externalEventId = await _gateway.upsertEvent(
              calendarId: calendar.id,
              event: payload,
              externalEventId: mapping?.externalEventId,
              previousEventDate: mapping?.event.eventDate,
            );
            current = current.copyWith(
              queue: current.queue.remove(payload.sourceEventId),
              mappings: {
                ...current.mappings,
                payload.sourceEventId: DeviceCalendarEventMapping(
                  externalEventId: externalEventId,
                  syncedRevision: payload.revision,
                  event: payload,
                ),
              },
            );
          case DeviceCalendarSyncOperationType.delete:
            if (mapping != null) {
              await _gateway.deleteEvent(
                calendarId: calendar.id,
                sourceEventId: payload.sourceEventId,
                externalEventId: mapping.externalEventId,
                eventDate: mapping.event.eventDate,
              );
            }
            final mappings = Map<String, DeviceCalendarEventMapping>.from(
              current.mappings,
            )..remove(payload.sourceEventId);
            current = current.copyWith(
              queue: current.queue.remove(payload.sourceEventId),
              mappings: mappings,
            );
        }
        await _store.write(userId: userId, state: current);
      } catch (_) {
        current = current.copyWith(
          queue: current.queue.replace(operation.incrementAttempts()),
        );
        await _store.write(userId: userId, state: current);
      }
    }
  }

  Future<void> _runSafely(Future<void> Function() action) {
    return _run(action).catchError((_) {});
  }

  Future<T> _run<T>(Future<T> Function() action) {
    final completion = Completer<T>();
    _serialWork = _serialWork.then((_) async {
      try {
        completion.complete(await action());
      } catch (error, stackTrace) {
        completion.completeError(error, stackTrace);
      }
    });
    return completion.future;
  }

  String _requireCurrentUserId() {
    final userId = _currentUserId();
    if (userId == null) {
      throw StateError('A signed-in user is required for calendar sync.');
    }
    return userId;
  }
}
