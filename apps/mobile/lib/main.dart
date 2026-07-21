import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/bootstrap/app_bootstrap.dart';
import 'features/auth/application/auth_sign_out_cleanup_provider.dart';
import 'features/home_widgets/application/widget_recording_upload_dispatcher.dart';
import 'features/notifications/application/push_token_auth_sign_out_cleanup.dart';
import 'features/notifications/data/push_token_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppBootstrap.initialize();

  runApp(
    ProviderScope(
      overrides: [
        authSignOutCleanupProvider.overrideWith((ref) {
          return PushTokenAuthSignOutCleanup(
            ref.watch(pushTokenRepositoryProvider),
          );
        }),
      ],
      child: const VinscentApp(),
    ),
  );
}

@pragma('vm:entry-point')
Future<void> widgetRecordingUploadMain() {
  return runWidgetRecordingUploadDispatcher();
}
