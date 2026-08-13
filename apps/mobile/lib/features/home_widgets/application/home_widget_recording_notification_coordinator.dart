import 'package:flutter/foundation.dart';

typedef MarkHomeWidgetRecordingRequired =
    Future<void> Function({
      required String coupleId,
      required String recordingId,
    });

typedef SynchronizeHomeWidgetRecording =
    Future<void> Function({required String expectedCoupleId});

class HomeWidgetRecordingNotification {
  const HomeWidgetRecordingNotification({
    required this.coupleId,
    required this.recordingId,
  });

  final String coupleId;
  final String recordingId;

  static HomeWidgetRecordingNotification? tryParse(Map<String, dynamic> data) {
    if (data['type'] != 'recording_activity' ||
        data['event_type'] != 'current_recording_updated') {
      return null;
    }

    final coupleId = _nonEmptyString(data['couple_id']);
    final recordingId = _nonEmptyString(data['recording_id']);
    if (coupleId == null || recordingId == null) {
      return null;
    }
    return HomeWidgetRecordingNotification(
      coupleId: coupleId,
      recordingId: recordingId,
    );
  }

  static String? _nonEmptyString(Object? value) {
    if (value is! String) {
      return null;
    }
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }
}

class HomeWidgetRecordingNotificationCoordinator {
  const HomeWidgetRecordingNotificationCoordinator({
    required MarkHomeWidgetRecordingRequired markRequired,
    required SynchronizeHomeWidgetRecording synchronizeRecording,
  }) : _markRequired = markRequired,
       _synchronizeRecording = synchronizeRecording;

  final MarkHomeWidgetRecordingRequired _markRequired;
  final SynchronizeHomeWidgetRecording _synchronizeRecording;

  Future<bool> handle(Map<String, dynamic> data) async {
    final notification = HomeWidgetRecordingNotification.tryParse(data);
    if (notification == null) {
      return false;
    }

    await _markRequired(
      coupleId: notification.coupleId,
      recordingId: notification.recordingId,
    );
    await _synchronizeRecording(expectedCoupleId: notification.coupleId);
    return true;
  }

  Future<bool> handleSafely(Map<String, dynamic> data) async {
    try {
      return await handle(data);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[widget] recording notification sync failed: $error');
      }
      return false;
    }
  }
}
