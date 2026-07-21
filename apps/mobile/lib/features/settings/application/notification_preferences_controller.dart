import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/notification_preferences.dart';
import '../data/settings_repository.dart';

final notificationPreferencesControllerProvider =
    AsyncNotifierProvider<
      NotificationPreferencesController,
      NotificationPreferences
    >(NotificationPreferencesController.new);

class NotificationPreferencesController
    extends AsyncNotifier<NotificationPreferences> {
  NotificationPreferences? _lastConfirmedPreferences;
  NotificationPreferences? _queuedPreferences;
  Completer<void>? _activeSaveCompleter;

  @override
  Future<NotificationPreferences> build() async {
    final preferences = await ref
        .watch(settingsRepositoryProvider)
        .fetchNotificationPreferences();
    _lastConfirmedPreferences = preferences;
    return preferences;
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final preferences = await ref
          .read(settingsRepositoryProvider)
          .fetchNotificationPreferences();
      _lastConfirmedPreferences = preferences;
      return preferences;
    });
  }

  Future<void> updatePreferences(NotificationPreferences preferences) {
    state = AsyncValue.data(preferences);
    _queuedPreferences = preferences;

    final activeCompleter = _activeSaveCompleter;
    if (activeCompleter != null) {
      return activeCompleter.future;
    }

    final completer = Completer<void>();
    _activeSaveCompleter = completer;
    unawaited(_drainSaveQueue(completer));
    return completer.future;
  }

  Future<void> _drainSaveQueue(Completer<void> completer) async {
    try {
      while (_queuedPreferences != null) {
        final pendingPreferences = _queuedPreferences!;
        _queuedPreferences = null;

        if (_isSamePreferences(pendingPreferences, _lastConfirmedPreferences)) {
          if (_queuedPreferences == null && _lastConfirmedPreferences != null) {
            state = AsyncValue.data(_lastConfirmedPreferences!);
          }
          continue;
        }

        try {
          final updated = await ref
              .read(settingsRepositoryProvider)
              .updateNotificationPreferences(pendingPreferences);
          _lastConfirmedPreferences = updated;

          if (_queuedPreferences == null) {
            state = AsyncValue.data(updated);
          }
        } catch (error, stackTrace) {
          final fallback = _lastConfirmedPreferences;
          if (fallback != null) {
            state = AsyncValue.data(fallback);
          }
          completer.completeError(error, stackTrace);
          return;
        }
      }

      completer.complete();
    } finally {
      if (identical(_activeSaveCompleter, completer)) {
        _activeSaveCompleter = null;
      }
    }
  }

  bool _isSamePreferences(
    NotificationPreferences next,
    NotificationPreferences? current,
  ) {
    if (current == null) {
      return false;
    }

    return next.userId == current.userId &&
        next.partnerAnswerEnabled == current.partnerAnswerEnabled &&
        next.dailyQuestionEnabled == current.dailyQuestionEnabled &&
        next.reminderEnabled == current.reminderEnabled &&
        next.coupleDisconnectEnabled == current.coupleDisconnectEnabled &&
        next.recordingEnabled == current.recordingEnabled &&
        next.partnerStoryCardEnabled == current.partnerStoryCardEnabled &&
        next.coupleActivityEnabled == current.coupleActivityEnabled &&
        next.aiUpdatesEnabled == current.aiUpdatesEnabled;
  }
}
