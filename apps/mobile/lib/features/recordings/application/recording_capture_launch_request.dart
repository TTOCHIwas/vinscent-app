import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

final recordingCaptureLaunchRequestProvider =
    NotifierProvider<RecordingCaptureLaunchRequestController, int?>(
      RecordingCaptureLaunchRequestController.new,
    );

class RecordingCaptureLaunchRequestController extends Notifier<int?> {
  static const _requestLifetime = Duration(seconds: 30);

  Timer? _expiryTimer;
  int _nextRequestId = 0;

  @override
  int? build() {
    ref.onDispose(() => _expiryTimer?.cancel());
    return null;
  }

  int request() {
    final requestId = ++_nextRequestId;
    state = requestId;
    _expiryTimer?.cancel();
    _expiryTimer = Timer(_requestLifetime, () {
      if (state == requestId) {
        state = null;
      }
    });
    return requestId;
  }

  bool consume(int requestId) {
    if (state != requestId) {
      return false;
    }

    _expiryTimer?.cancel();
    _expiryTimer = null;
    state = null;
    return true;
  }
}
