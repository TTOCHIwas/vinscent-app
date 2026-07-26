import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_status.dart';
import '../data/calendar_cell_preview_mode.dart';
import '../data/calendar_cell_preview_preference_store.dart';

final calendarPreferenceUserIdProvider = Provider<String?>((ref) {
  final authStatus = ref.watch(authControllerProvider);
  if (authStatus != AuthStatus.authenticated ||
      !AppConfig.isSupabaseConfigured) {
    return null;
  }
  return Supabase.instance.client.auth.currentUser?.id;
});

final calendarCellPreviewModeControllerProvider =
    AsyncNotifierProvider<
      CalendarCellPreviewModeController,
      CalendarCellPreviewMode
    >(CalendarCellPreviewModeController.new);

class CalendarCellPreviewModeController
    extends AsyncNotifier<CalendarCellPreviewMode> {
  @override
  Future<CalendarCellPreviewMode> build() async {
    final userId = ref.watch(calendarPreferenceUserIdProvider);
    if (userId == null) {
      return CalendarCellPreviewMode.all;
    }

    try {
      return await ref
          .watch(calendarCellPreviewPreferenceStoreProvider)
          .read(userId: userId);
    } catch (_) {
      return CalendarCellPreviewMode.all;
    }
  }

  Future<void> selectMode(CalendarCellPreviewMode mode) async {
    final previousMode = state.asData?.value ?? CalendarCellPreviewMode.all;
    if (previousMode == mode) {
      return;
    }

    state = AsyncValue.data(mode);
    final userId = ref.read(calendarPreferenceUserIdProvider);
    if (userId == null) {
      return;
    }

    try {
      await ref
          .read(calendarCellPreviewPreferenceStoreProvider)
          .write(userId: userId, mode: mode);
    } catch (error, stackTrace) {
      state = AsyncValue.data(previousMode);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}
