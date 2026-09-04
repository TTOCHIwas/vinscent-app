import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vinscent/core/bootstrap/app_bootstrap.dart';
import 'package:vinscent/core/config/app_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'initializes Supabase on cold start and reuses the client on retry',
    () async {
      expect(() => Supabase.instance, throwsAssertionError);

      await AppBootstrap.initializeSupabase();
      final instance = Supabase.instance;
      addTearDown(instance.dispose);
      final client = instance.client;

      expect(instance.isInitialized, isTrue);
      expect(client.auth.currentSession, isNull);

      await AppBootstrap.initializeSupabase();

      expect(Supabase.instance.client, same(client));
    },
    skip: AppConfig.isSupabaseConfigured
        ? false
        : 'Run with test-only SUPABASE_URL and SUPABASE_ANON_KEY dart defines.',
  );

  test(
    'skips Supabase when configuration is absent',
    () async {
      await AppBootstrap.initializeSupabase();

      expect(() => Supabase.instance, throwsAssertionError);
    },
    skip: AppConfig.isSupabaseConfigured,
  );
}
