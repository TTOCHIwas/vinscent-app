import '../../couple/data/couple_repository.dart';
import '../../recordings/data/couple_recording_repository.dart';
import '../application/widget_recording_upload_task.dart';
import 'home_widget_platform_store.dart';

WidgetRecordingUploadTask createWidgetRecordingUploadTask() {
  return WidgetRecordingUploadTask(
    draftReader: const FileWidgetRecordingDraftReader(),
    uploadGateway: const SupabaseWidgetRecordingUploadGateway(
      coupleRepository: SupabaseCoupleRepository(),
      recordingRepository: SupabaseCoupleRecordingRepository(),
    ),
    playbackCache: const HomeWidgetRecordingPlaybackCache(
      store: PluginHomeWidgetStore(),
    ),
  );
}
