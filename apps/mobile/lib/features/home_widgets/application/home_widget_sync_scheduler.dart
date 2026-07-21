import 'dart:async';

typedef HomeWidgetSynchronize = Future<void> Function();

class HomeWidgetSyncScheduler {
  HomeWidgetSyncScheduler({
    required HomeWidgetSynchronize synchronize,
    Duration debounceDuration = const Duration(milliseconds: 350),
  }) : _synchronize = synchronize,
       _debounceDuration = debounceDuration;

  final HomeWidgetSynchronize _synchronize;
  final Duration _debounceDuration;

  Timer? _timer;
  bool _isRunning = false;
  bool _isQueued = false;
  bool _isDisposed = false;

  void schedule() {
    if (_isDisposed) {
      return;
    }

    _timer?.cancel();
    _timer = Timer(_debounceDuration, () {
      _timer = null;
      unawaited(_run());
    });
  }

  void dispose() {
    _isDisposed = true;
    _isQueued = false;
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _run() async {
    if (_isDisposed) {
      return;
    }
    if (_isRunning) {
      _isQueued = true;
      return;
    }

    _isRunning = true;
    try {
      do {
        _isQueued = false;
        await _synchronize();
      } while (_isQueued && !_isDisposed);
    } finally {
      _isRunning = false;
    }
  }
}
