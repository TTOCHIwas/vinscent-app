import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';

class AppBootstrap {
  const AppBootstrap._();

  static Future<void> initialize() async {
    if (AppConfig.isKakaoConfigured) {
      await KakaoSdk.init(nativeAppKey: AppConfig.kakaoNativeAppKey);
    }

    if (!_isFirebaseSupported) {
      _debugPushLog('Firebase initialization skipped: unsupported platform');
    } else if (Firebase.apps.isEmpty) {
      _debugPushLog('Firebase initialization started');
      await Firebase.initializeApp();
      _debugPushLog('Firebase initialization completed');
    } else {
      _debugPushLog('Firebase initialization skipped: already initialized');
    }

    if (AppConfig.isSupabaseConfigured) {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        anonKey: AppConfig.supabaseAnonKey,
        authOptions: const FlutterAuthClientOptions(
          detectSessionInUri: false,
        ),
      );
    }
  }

  static bool get _isFirebaseSupported {
    if (kIsWeb) {
      return false;
    }

    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  static void _debugPushLog(String message) {
    if (kDebugMode) {
      debugPrint('[push] $message');
    }
  }
}
