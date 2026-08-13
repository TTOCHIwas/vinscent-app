import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/app_bootstrap_gate.dart';
import 'core/bootstrap/app_bootstrap.dart';
import 'features/auth/application/auth_sign_out_cleanup_provider.dart';
import 'features/home_widgets/application/widget_recording_upload_dispatcher.dart';
import 'features/home_widgets/application/home_widget_recording_background_handler.dart';
import 'features/notifications/application/push_token_auth_sign_out_cleanup.dart';
import 'features/notifications/data/push_token_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FirebaseMessaging.onBackgroundMessage(
    handleHomeWidgetRecordingBackgroundMessage,
  );

  runApp(
    AppBootstrapGate(
      initialize: AppBootstrap.initialize,
      child: ProviderScope(
        overrides: [
          authSignOutCleanupProvider.overrideWith((ref) {
            return PushTokenAuthSignOutCleanup(
              ref.watch(pushTokenRepositoryProvider),
            );
          }),
        ],
        child: const VinscentApp(),
      ),
    ),
  );
}

@pragma('vm:entry-point')
Future<void> widgetRecordingUploadMain() {
  return runWidgetRecordingUploadDispatcher();
}
