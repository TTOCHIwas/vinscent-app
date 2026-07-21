import 'dart:async';

typedef LaunchReadiness = bool Function();
typedef LaunchHandler<T extends Object> = Future<bool> Function(T value);

class LatestLaunchDispatcher<T extends Object> {
  LatestLaunchDispatcher({
    required LaunchReadiness isReady,
    required LaunchHandler<T> handle,
  }) : _isReady = isReady,
       _handle = handle;

  final LaunchReadiness _isReady;
  final LaunchHandler<T> _handle;

  T? _pending;
  bool _isHandling = false;
  bool _isDisposed = false;

  void enqueue(T value) {
    if (_isDisposed) {
      return;
    }

    _pending = value;
    unawaited(drain());
  }

  Future<void> drain() async {
    final pending = _pending;
    if (_isDisposed || _isHandling || pending == null || !_isReady()) {
      return;
    }

    _isHandling = true;
    try {
      final consumed = await _handle(pending);
      if (consumed && _pending == pending) {
        _pending = null;
      }
    } finally {
      _isHandling = false;
      if (!_isDisposed && _pending != null && _pending != pending) {
        unawaited(drain());
      }
    }
  }

  void dispose() {
    _isDisposed = true;
    _pending = null;
  }
}
