import 'package:flutter/foundation.dart';

void debugStoryLoopLog(String message) {
  if (kDebugMode) {
    debugPrint('[story-loop] $message');
  }
}
