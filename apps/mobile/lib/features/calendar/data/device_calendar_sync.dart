import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'couple_calendar_event.dart';
import 'device_calendar_gateway.dart';

final deviceCalendarSyncStoreProvider = Provider<DeviceCalendarSyncStore>((
  ref,
) {
  return SharedPreferencesDeviceCalendarSyncStore();
});

enum DeviceCalendarSyncOperationType { upsert, delete }

class DeviceCalendarSyncOperation {
  const DeviceCalendarSyncOperation({
    required this.type,
    required this.event,
    this.attempts = 0,
  });

  final DeviceCalendarSyncOperationType type;
  final DeviceCalendarEventPayload? event;
  final int attempts;

  String get sourceEventId => event!.sourceEventId;

  DeviceCalendarSyncOperation incrementAttempts() {
    return DeviceCalendarSyncOperation(
      type: type,
      event: event,
      attempts: attempts + 1,
    );
  }

  Map<String, Object?> toJson() => {
    'type': type.name,
    'event': event?.toJson(),
    'attempts': attempts,
  };

  factory DeviceCalendarSyncOperation.fromJson(Map<String, Object?> json) {
    final event = json['event'];
    if (event is! Map) {
      throw const FormatException('Missing device calendar sync event.');
    }
    return DeviceCalendarSyncOperation(
      type: DeviceCalendarSyncOperationType.values.byName(
        json['type']! as String,
      ),
      event: DeviceCalendarEventPayload.fromJson(
        Map<String, Object?>.from(event),
      ),
      attempts: (json['attempts'] as num?)?.toInt() ?? 0,
    );
  }
}

class DeviceCalendarSyncQueue {
  const DeviceCalendarSyncQueue(this.operations);

  factory DeviceCalendarSyncQueue.empty() => const DeviceCalendarSyncQueue([]);

  final List<DeviceCalendarSyncOperation> operations;

  DeviceCalendarSyncQueue enqueueUpsert(CoupleCalendarEvent event) {
    return enqueuePayload(
      DeviceCalendarSyncOperation(
        type: DeviceCalendarSyncOperationType.upsert,
        event: DeviceCalendarEventPayload.fromEvent(event),
      ),
    );
  }

  DeviceCalendarSyncQueue enqueueDelete(CoupleCalendarEvent event) {
    return enqueuePayload(
      DeviceCalendarSyncOperation(
        type: DeviceCalendarSyncOperationType.delete,
        event: DeviceCalendarEventPayload.fromEvent(event),
      ),
    );
  }

  DeviceCalendarSyncQueue enqueuePayload(
    DeviceCalendarSyncOperation operation,
  ) {
    return DeviceCalendarSyncQueue([
      for (final existing in operations)
        if (existing.sourceEventId != operation.sourceEventId) existing,
      operation,
    ]);
  }

  DeviceCalendarSyncQueue remove(String sourceEventId) {
    return DeviceCalendarSyncQueue([
      for (final operation in operations)
        if (operation.sourceEventId != sourceEventId) operation,
    ]);
  }

  DeviceCalendarSyncQueue replace(DeviceCalendarSyncOperation operation) {
    return DeviceCalendarSyncQueue([
      for (final existing in operations)
        if (existing.sourceEventId == operation.sourceEventId)
          operation
        else
          existing,
    ]);
  }

  DeviceCalendarSyncQueue withoutUpserts() {
    return DeviceCalendarSyncQueue([
      for (final operation in operations)
        if (operation.type == DeviceCalendarSyncOperationType.delete) operation,
    ]);
  }

  DeviceCalendarSyncQueue withoutDeletes() {
    return DeviceCalendarSyncQueue([
      for (final operation in operations)
        if (operation.type == DeviceCalendarSyncOperationType.upsert) operation,
    ]);
  }

  DeviceCalendarSyncQueue clear() => DeviceCalendarSyncQueue.empty();

  List<Object?> toJson() => operations.map((value) => value.toJson()).toList();

  factory DeviceCalendarSyncQueue.fromJson(Object? json) {
    if (json is! List) {
      return DeviceCalendarSyncQueue.empty();
    }
    return DeviceCalendarSyncQueue(
      json
          .whereType<Map>()
          .map(
            (value) => DeviceCalendarSyncOperation.fromJson(
              Map<String, Object?>.from(value),
            ),
          )
          .toList(growable: false),
    );
  }
}

class DeviceCalendarEventMapping {
  const DeviceCalendarEventMapping({
    required this.externalEventId,
    required this.syncedRevision,
    required this.event,
  });

  final String externalEventId;
  final int syncedRevision;
  final DeviceCalendarEventPayload event;

  Map<String, Object?> toJson() => {
    'externalEventId': externalEventId,
    'syncedRevision': syncedRevision,
    'event': event.toJson(),
  };

  factory DeviceCalendarEventMapping.fromJson(Map<String, Object?> json) {
    return DeviceCalendarEventMapping(
      externalEventId: json['externalEventId']! as String,
      syncedRevision: (json['syncedRevision'] as num).toInt(),
      event: DeviceCalendarEventPayload.fromJson(
        Map<String, Object?>.from(json['event']! as Map),
      ),
    );
  }
}

class DeviceCalendarSyncState {
  const DeviceCalendarSyncState({
    required this.enabled,
    required this.calendar,
    required this.queue,
    required this.mappings,
  });

  factory DeviceCalendarSyncState.disabled() => DeviceCalendarSyncState(
    enabled: false,
    calendar: null,
    queue: DeviceCalendarSyncQueue.empty(),
    mappings: const {},
  );

  factory DeviceCalendarSyncState.enabled({
    required DeviceCalendarDescriptor calendar,
  }) {
    return DeviceCalendarSyncState(
      enabled: true,
      calendar: calendar,
      queue: DeviceCalendarSyncQueue.empty(),
      mappings: const {},
    );
  }

  final bool enabled;
  final DeviceCalendarDescriptor? calendar;
  final DeviceCalendarSyncQueue queue;
  final Map<String, DeviceCalendarEventMapping> mappings;

  DeviceCalendarSyncState copyWith({
    bool? enabled,
    DeviceCalendarDescriptor? calendar,
    bool clearCalendar = false,
    DeviceCalendarSyncQueue? queue,
    Map<String, DeviceCalendarEventMapping>? mappings,
  }) {
    return DeviceCalendarSyncState(
      enabled: enabled ?? this.enabled,
      calendar: clearCalendar ? null : calendar ?? this.calendar,
      queue: queue ?? this.queue,
      mappings: mappings ?? this.mappings,
    );
  }

  Map<String, Object?> toJson() => {
    'enabled': enabled,
    'calendar': calendar?.toJson(),
    'queue': queue.toJson(),
    'mappings': mappings.map((key, value) => MapEntry(key, value.toJson())),
  };

  factory DeviceCalendarSyncState.fromJson(Map<String, Object?> json) {
    final calendar = json['calendar'];
    final mappings = json['mappings'];
    return DeviceCalendarSyncState(
      enabled: json['enabled'] == true,
      calendar: calendar is Map
          ? DeviceCalendarDescriptor.fromJson(
              Map<String, Object?>.from(calendar),
            )
          : null,
      queue: DeviceCalendarSyncQueue.fromJson(json['queue']),
      mappings: mappings is Map
          ? mappings.map(
              (key, value) => MapEntry(
                key.toString(),
                DeviceCalendarEventMapping.fromJson(
                  Map<String, Object?>.from(value as Map),
                ),
              ),
            )
          : const {},
    );
  }
}

abstract interface class DeviceCalendarSyncStore {
  Future<DeviceCalendarSyncState> read({required String userId});

  Future<void> write({
    required String userId,
    required DeviceCalendarSyncState state,
  });

  Future<void> clearForUser(String userId);
}

class SharedPreferencesDeviceCalendarSyncStore
    implements DeviceCalendarSyncStore {
  SharedPreferencesDeviceCalendarSyncStore({
    SharedPreferencesAsync? preferences,
  }) : _providedPreferences = preferences;

  static const _keyPrefix = 'vinscent.calendar.device_sync.v1';

  final SharedPreferencesAsync? _providedPreferences;

  SharedPreferencesAsync get _preferences =>
      _providedPreferences ?? SharedPreferencesAsync();

  @override
  Future<DeviceCalendarSyncState> read({required String userId}) async {
    final value = await _preferences.getString('$_keyPrefix.$userId');
    if (value == null) {
      return DeviceCalendarSyncState.disabled();
    }
    try {
      return DeviceCalendarSyncState.fromJson(
        Map<String, Object?>.from(jsonDecode(value) as Map),
      );
    } catch (_) {
      return DeviceCalendarSyncState.disabled();
    }
  }

  @override
  Future<void> write({
    required String userId,
    required DeviceCalendarSyncState state,
  }) {
    return _preferences.setString(
      '$_keyPrefix.$userId',
      jsonEncode(state.toJson()),
    );
  }

  @override
  Future<void> clearForUser(String userId) {
    return _preferences.remove('$_keyPrefix.$userId');
  }
}

class InMemoryDeviceCalendarSyncStore implements DeviceCalendarSyncStore {
  InMemoryDeviceCalendarSyncStore(DeviceCalendarSyncState initialState)
    : _state = initialState;

  DeviceCalendarSyncState _state;

  @override
  Future<DeviceCalendarSyncState> read({required String userId}) async =>
      _state;

  @override
  Future<void> write({
    required String userId,
    required DeviceCalendarSyncState state,
  }) async {
    _state = state;
  }

  @override
  Future<void> clearForUser(String userId) async {
    _state = DeviceCalendarSyncState.disabled();
  }
}
