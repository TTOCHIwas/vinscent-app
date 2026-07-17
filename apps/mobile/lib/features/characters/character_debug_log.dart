import 'package:flutter/foundation.dart';

void debugCharacterLog(String message) {
  if (kDebugMode) {
    debugPrint('[character] $message');
  }
}
