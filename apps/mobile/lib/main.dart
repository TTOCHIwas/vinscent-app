import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/bootstrap/app_bootstrap.dart';
import 'features/home_widgets/application/widget_recording_upload_dispatcher.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppBootstrap.initialize();

  runApp(const ProviderScope(child: VinscentApp()));
}

@pragma('vm:entry-point')
Future<void> widgetRecordingUploadMain() {
  return runWidgetRecordingUploadDispatcher();
}
