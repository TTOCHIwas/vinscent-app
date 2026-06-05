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

    if (_isFirebaseSupported && Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }

    if (AppConfig.isSupabaseConfigured) {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        anonKey: AppConfig.supabaseAnonKey,
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
}
