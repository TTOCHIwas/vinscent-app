import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/date/app_date_policy.dart';
import 'couple_calendar_event.dart';

final deviceCalendarGatewayProvider = Provider<DeviceCalendarGateway>((ref) {
  if (!Platform.isAndroid && !Platform.isIOS) {
    return const UnsupportedDeviceCalendarGateway();
  }
  return const MethodChannelDeviceCalendarGateway();
});

enum DeviceCalendarAuthorizationStatus {
  notDetermined,
  denied,
  restricted,
  authorized,
  unsupported;

  static DeviceCalendarAuthorizationStatus fromPlatformValue(Object? value) {
    return switch (value) {
      'notDetermined' => notDetermined,
      'denied' => denied,
      'restricted' => restricted,
      'authorized' => authorized,
      _ => unsupported,
    };
  }
}

class DeviceCalendarDescriptor {
  const DeviceCalendarDescriptor({
    required this.id,
    required this.name,
    this.accountName,
    this.isPrimary = false,
  });

  final String id;
  final String name;
  final String? accountName;
  final bool isPrimary;

  factory DeviceCalendarDescriptor.fromJson(Map<String, Object?> json) {
    return DeviceCalendarDescriptor(
      id: json['id']! as String,
      name: json['name']! as String,
      accountName: json['accountName'] as String?,
      isPrimary: json['isPrimary'] == true,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'accountName': accountName,
    'isPrimary': isPrimary,
  };
}

class DeviceCalendarEventPayload {
  const DeviceCalendarEventPayload({
    required this.sourceEventId,
    required this.title,
    required this.eventDate,
    required this.repeatRule,
    required this.memo,
    required this.revision,
  });

  factory DeviceCalendarEventPayload.fromEvent(CoupleCalendarEvent event) {
    return DeviceCalendarEventPayload(
      sourceEventId: event.id,
      title: event.title,
      eventDate: calendarDateOnly(event.eventDate),
      repeatRule: event.repeatRule,
      memo: event.memo,
      revision: event.revision,
    );
  }

  final String sourceEventId;
  final String title;
  final DateTime eventDate;
  final CoupleCalendarEventRepeatRule repeatRule;
  final String? memo;
  final int revision;

  String get id => sourceEventId;

  Map<String, Object?> toJson() => {
    'sourceEventId': sourceEventId,
    'title': title,
    'eventDate': formatCalendarDate(eventDate),
    'repeatRule': repeatRule.toJson(),
    'memo': memo,
    'revision': revision,
  };

  factory DeviceCalendarEventPayload.fromJson(Map<String, Object?> json) {
    final eventDate = parseCalendarDate(json['eventDate'] as String?);
    if (eventDate == null) {
      throw const FormatException('Invalid device calendar event date.');
    }
    return DeviceCalendarEventPayload(
      sourceEventId: json['sourceEventId']! as String,
      title: json['title']! as String,
      eventDate: eventDate,
      repeatRule: CoupleCalendarEventRepeatRule.fromJson(
        json['repeatRule']! as String,
      ),
      memo: json['memo'] as String?,
      revision: (json['revision'] as num).toInt(),
    );
  }
}

abstract interface class DeviceCalendarGateway {
  Future<DeviceCalendarAuthorizationStatus> authorizationStatus();

  Future<DeviceCalendarAuthorizationStatus> requestFullAccess();

  Future<void> openSettings();

  Future<List<DeviceCalendarDescriptor>> listWritableCalendars();

  Future<String> upsertEvent({
    required String calendarId,
    required DeviceCalendarEventPayload event,
    String? externalEventId,
    DateTime? previousEventDate,
  });

  Future<void> deleteEvent({
    required String calendarId,
    required String sourceEventId,
    required String externalEventId,
    required DateTime eventDate,
  });
}

class MethodChannelDeviceCalendarGateway implements DeviceCalendarGateway {
  const MethodChannelDeviceCalendarGateway();

  static const _channel = MethodChannel(
    'com.vinscent.vinscent/device_calendar',
  );

  @override
  Future<DeviceCalendarAuthorizationStatus> authorizationStatus() async {
    final value = await _channel.invokeMethod<String>('authorizationStatus');
    return DeviceCalendarAuthorizationStatus.fromPlatformValue(value);
  }

  @override
  Future<DeviceCalendarAuthorizationStatus> requestFullAccess() async {
    final value = await _channel.invokeMethod<String>('requestFullAccess');
    return DeviceCalendarAuthorizationStatus.fromPlatformValue(value);
  }

  @override
  Future<void> openSettings() {
    return _channel.invokeMethod<void>('openSettings');
  }

  @override
  Future<List<DeviceCalendarDescriptor>> listWritableCalendars() async {
    final rows = await _channel.invokeListMethod<Object?>(
      'listWritableCalendars',
    );
    return (rows ?? const [])
        .whereType<Map>()
        .map(
          (row) =>
              DeviceCalendarDescriptor.fromJson(Map<String, Object?>.from(row)),
        )
        .toList(growable: false);
  }

  @override
  Future<String> upsertEvent({
    required String calendarId,
    required DeviceCalendarEventPayload event,
    String? externalEventId,
    DateTime? previousEventDate,
  }) async {
    final result = await _channel.invokeMethod<String>('upsertEvent', {
      'calendarId': calendarId,
      'externalEventId': externalEventId,
      if (previousEventDate != null)
        'previousEventDate': formatCalendarDate(previousEventDate),
      ...event.toJson(),
    });
    if (result == null || result.isEmpty) {
      throw PlatformException(
        code: 'device_calendar_invalid_result',
        message: 'The device calendar did not return an event identifier.',
      );
    }
    return result;
  }

  @override
  Future<void> deleteEvent({
    required String calendarId,
    required String sourceEventId,
    required String externalEventId,
    required DateTime eventDate,
  }) {
    return _channel.invokeMethod<void>('deleteEvent', {
      'calendarId': calendarId,
      'sourceEventId': sourceEventId,
      'externalEventId': externalEventId,
      'eventDate': formatCalendarDate(eventDate),
    });
  }
}

class UnsupportedDeviceCalendarGateway implements DeviceCalendarGateway {
  const UnsupportedDeviceCalendarGateway();

  @override
  Future<DeviceCalendarAuthorizationStatus> authorizationStatus() async =>
      DeviceCalendarAuthorizationStatus.unsupported;

  @override
  Future<DeviceCalendarAuthorizationStatus> requestFullAccess() async =>
      DeviceCalendarAuthorizationStatus.unsupported;

  @override
  Future<void> openSettings() async {}

  @override
  Future<List<DeviceCalendarDescriptor>> listWritableCalendars() async =>
      const [];

  @override
  Future<void> deleteEvent({
    required String calendarId,
    required String sourceEventId,
    required String externalEventId,
    required DateTime eventDate,
  }) async {}

  @override
  Future<String> upsertEvent({
    required String calendarId,
    required DeviceCalendarEventPayload event,
    String? externalEventId,
    DateTime? previousEventDate,
  }) {
    throw UnsupportedError('Device calendar is not supported.');
  }
}
