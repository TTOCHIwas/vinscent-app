import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';

class AppBootstrap {
  const AppBootstrap._();

  static Future<void> initialize() async {
    if (AppConfig.isKakaoConfigured) {
      await KakaoSdk.init(nativeAppKey: AppConfig.kakaoNativeAppKey);
    }

    if (AppConfig.isSupabaseConfigured) {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        anonKey: AppConfig.supabaseAnonKey,
      );
    }
  }
}
