import '../../couple/data/couple_repository.dart';
import '../../recordings/data/couple_recording_repository.dart';
import '../application/widget_recording_upload_task.dart';
import 'home_widget_platform_store.dart';
import 'home_widget_recording_cache_repository.dart';
import 'widget_recording_upload_adapters.dart';

WidgetRecordingUploadTask createWidgetRecordingUploadTask() {
  const store = PluginHomeWidgetStore();
  return WidgetRecordingUploadTask(
    draftReader: const FileWidgetRecordingDraftReader(),
    uploadGateway: const SupabaseWidgetRecordingUploadGateway(
      coupleRepository: SupabaseCoupleRepository(),
      recordingRepository: SupabaseCoupleRecordingRepository(),
    ),
    playbackCache: HomeWidgetRecordingPlaybackCache(
      cacheRepository: HomeWidgetRecordingCacheRepository(store: store),
      store: store,
    ),
  );
}
