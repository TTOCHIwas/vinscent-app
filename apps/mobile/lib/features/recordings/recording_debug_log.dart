import 'package:flutter/foundation.dart';

void debugRecordingLog(String message) {
  if (kDebugMode) {
    debugPrint('[recording] $message');
  }
}
