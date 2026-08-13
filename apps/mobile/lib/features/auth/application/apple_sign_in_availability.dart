import 'package:flutter/foundation.dart';

abstract final class AppleSignInAvailability {
  static bool get isSupported {
    if (kIsWeb) {
      return false;
    }

    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS || TargetPlatform.macOS => true,
      _ => false,
    };
  }
}
