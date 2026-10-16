import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../couple/application/couple_controller.dart';
import '../../couple/application/couple_current_date_provider.dart';
import '../../couple/data/couple.dart';
import '../../story_loops/application/story_loop_realtime_controller.dart';
import '../data/monthly_retrospective.dart';
import '../data/monthly_retrospective_repository.dart';
import 'monthly_retrospective_controller.dart';

final monthlyRetrospectiveAvailabilityProvider =
    FutureProvider.autoDispose<MonthlyRetrospectiveAvailability?>((ref) async {
      ref.watch(coupleCurrentDateProvider);
      ref.watch(storyCardReadRevisionProvider);
      ref.watch(dailyQuestionReadRevisionProvider);
      final couple = await ref.watch(coupleControllerProvider.future);
      if (couple == null ||
          !couple.canReadSharedData ||
          couple.status != CoupleStatus.active) {
        return null;
      }
      final data = await ref
          .watch(monthlyRetrospectiveRepositoryProvider)
          .fetchAvailability();
      final remaining = data.availableUntil.difference(
        ref.read(monthlyRetrospectiveClockProvider)(),
      );
      final delay =
          remaining > Duration.zero && remaining < const Duration(seconds: 30)
          ? remaining
          : const Duration(seconds: 30);
      final timer = Timer(delay, ref.invalidateSelf);
      ref.onDispose(timer.cancel);
      return data;
    }, retry: (_, _) => null);
