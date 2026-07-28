import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../ai/data/ai_proactive_suggestion_store.dart';
import '../../calendar/data/calendar_cell_preview_preference_store.dart';
import '../../home/data/home_feedback_impression_store.dart';
import '../../home_widgets/application/home_widget_sync_service.dart';
import '../../recordings/application/pending_recording_draft_store.dart';
import '../data/account_deletion_repository.dart';
import 'account_deletion_service.dart';
import 'account_local_data_cleanup.dart';

final accountCurrentUserIdProvider = Provider<String?>((ref) {
  if (!AppConfig.isSupabaseConfigured) {
    return null;
  }
  return Supabase.instance.client.auth.currentUser?.id;
});

final accountLocalDataCleanupProvider = Provider<AccountLocalDataCleanup>((
  ref,
) {
  final homeWidgetSynchronizer = ref.watch(homeWidgetSynchronizerProvider);
  return AccountLocalDataCleanup(
    clearProactiveSuggestion: ref
        .watch(aiProactiveSuggestionStoreProvider)
        .clearForUser,
    clearCalendarPreviewPreference: ref
        .watch(calendarCellPreviewPreferenceStoreProvider)
        .clearForUser,
    clearHomeFeedbackImpression: ref
        .watch(homeFeedbackImpressionStoreProvider)
        .clearForUser,
    clearPendingRecordingDrafts: ref
        .watch(pendingRecordingDraftStoreProvider)
        .clear,
    clearHomeWidgets: () => homeWidgetSynchronizer.synchronize(null),
  );
});

final accountDeletionExecutorProvider = Provider<AccountDeletionExecutor>((
  ref,
) {
  return AccountDeletionService(
    repository: ref.watch(accountDeletionRepositoryProvider),
    localDataCleanup: ref.watch(accountLocalDataCleanupProvider),
    clearSession: () async {
      if (!AppConfig.isSupabaseConfigured) {
        return;
      }
      await Supabase.instance.client.auth.signOut();
    },
  );
});
