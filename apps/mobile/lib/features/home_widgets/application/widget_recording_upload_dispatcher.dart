import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';

import '../../../core/bootstrap/app_bootstrap.dart';
import 'widget_recording_upload_task.dart';

const widgetRecordingUploadChannelName =
    'com.vinscent.vinscent/widget_recording_upload';

Future<void> runWidgetRecordingUploadDispatcher() async {
  WidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(widgetRecordingUploadChannelName);

  channel.setMethodCallHandler((call) async {
    if (call.method != 'upload') {
      throw MissingPluginException('Unknown widget recording method.');
    }

    try {
      final request = WidgetRecordingUploadRequest.fromArguments(
        call.arguments,
      );
      await AppBootstrap.initializeSupabase();
      await createWidgetRecordingUploadTask().execute(request);
      return const <String, Object>{'success': true, 'retryable': false};
    } catch (error) {
      return <String, Object>{
        'success': false,
        'retryable': isRetryableWidgetRecordingUploadError(error),
        'errorType': error.runtimeType.toString(),
      };
    }
  });

  await channel.invokeMethod<void>('ready');
}
