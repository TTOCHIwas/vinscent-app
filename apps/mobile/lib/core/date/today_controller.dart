import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_date_policy.dart';

final todayControllerProvider = NotifierProvider<TodayController, DateTime>(
  TodayController.new,
);

class TodayController extends Notifier<DateTime> {
  Timer? _timer;

  @override
  DateTime build() {
    ref.onDispose(() => _timer?.cancel());
    _scheduleNextRefresh();
    return currentAppDate();
  }

  void refresh() {
    final today = currentAppDate();
    if (state != today) {
      state = today;
    }

    _scheduleNextRefresh();
  }

  void _scheduleNextRefresh() {
    _timer?.cancel();

    final duration = durationUntilNextAppDate();
    _timer = Timer(_safeTimerDuration(duration), refresh);
  }

  Duration _safeTimerDuration(Duration duration) {
    if (duration <= Duration.zero) {
      return const Duration(seconds: 1);
    }

    return duration;
  }
}
