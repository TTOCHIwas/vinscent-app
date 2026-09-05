import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/public_holiday.dart';
import '../data/public_holiday_region_preference_store.dart';
import '../data/public_holiday_repository.dart';
import 'calendar_cell_preview_mode_controller.dart';

final publicHolidayDeviceLocaleProvider = Provider<Locale>((ref) {
  return PlatformDispatcher.instance.locale;
});

final publicHolidayRegionControllerProvider =
    AsyncNotifierProvider<PublicHolidayRegionController, PublicHolidayRegion>(
      PublicHolidayRegionController.new,
    );

class PublicHolidayRegionController extends AsyncNotifier<PublicHolidayRegion> {
  @override
  Future<PublicHolidayRegion> build() async {
    final userId = ref.watch(calendarPreferenceUserIdProvider);
    final fallback = const PublicHolidayRegionResolver().resolveDefault(
      ref.watch(publicHolidayDeviceLocaleProvider),
    );
    if (userId == null) {
      return fallback;
    }
    try {
      return await ref
              .watch(publicHolidayRegionPreferenceStoreProvider)
              .read(userId: userId) ??
          fallback;
    } catch (_) {
      return fallback;
    }
  }

  Future<void> select(PublicHolidayRegion region) async {
    final previous = state.asData?.value ?? PublicHolidayRegion.off;
    if (previous == region) {
      return;
    }
    state = AsyncValue.data(region);
    final userId = ref.read(calendarPreferenceUserIdProvider);
    if (userId == null) {
      return;
    }
    try {
      await ref
          .read(publicHolidayRegionPreferenceStoreProvider)
          .write(userId: userId, region: region);
    } catch (error, stackTrace) {
      state = AsyncValue.data(previous);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}

final publicHolidayMonthProvider = FutureProvider.autoDispose
    .family<Map<DateTime, PublicHoliday>, DateTime>((ref, month) async {
      final region = await ref.watch(
        publicHolidayRegionControllerProvider.future,
      );
      if (!region.isEnabled) {
        return const {};
      }
      final holidays = await ref
          .watch(publicHolidayRepositoryProvider)
          .fetchYear(region: region, year: month.year);
      return {for (final holiday in holidays) holiday.date: holiday};
    }, retry: (_, _) => null);
