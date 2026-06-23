import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/date/app_date_policy.dart';
import '../../../core/date/today_controller.dart';
import 'couple_controller.dart';

final coupleCurrentDateProvider = Provider<DateTime>((ref) {
  final fallbackToday = ref.watch(todayControllerProvider);
  final couple = ref.watch(
    coupleControllerProvider.select(
      (state) => state.maybeWhen(data: (value) => value, orElse: () => null),
    ),
  );

  return calendarDateOnly(couple?.effectiveCurrentDate ?? fallbackToday);
});
