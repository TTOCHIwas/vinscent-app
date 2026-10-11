import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../couple/application/couple_controller.dart';
import '../../couple/data/couple.dart';
import '../data/monthly_retrospective.dart';
import '../data/monthly_retrospective_repository.dart';

final monthlyRetrospectiveControllerProvider = AsyncNotifierProvider.autoDispose<MonthlyRetrospectiveController, MonthlyRetrospective>(MonthlyRetrospectiveController.new, retry: (_, _) => null);

class MonthlyRetrospectiveController extends AsyncNotifier<MonthlyRetrospective> {
  @override
  Future<MonthlyRetrospective> build() async {
    final couple = await ref.watch(coupleControllerProvider.future);
    if (couple == null || !couple.canReadSharedData || couple.status != CoupleStatus.active) {
      throw StateError('연결된 커플만 월간 회고를 볼 수 있어요');
    }
    final repository = ref.read(monthlyRetrospectiveRepositoryProvider);
    final data = await repository.fetch();
    final remaining = data.availableUntil.difference(DateTime.now().toUtc());
    final timer = Timer(remaining.isNegative ? const Duration(minutes: 1) : remaining, () => ref.invalidateSelf());
    ref.onDispose(timer.cancel);
    return data;
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(() => ref.read(monthlyRetrospectiveRepositoryProvider).fetch());
  }

  Future<void> generate() async {
    await ref.read(monthlyRetrospectiveRepositoryProvider).generate();
    await refresh();
    for (var attempt = 0; attempt < 18; attempt++) {
      if (!ref.mounted || state.value?.contentStatus != 'generating') return;
      await Future<void>.delayed(const Duration(seconds: 5));
      if (!ref.mounted) return;
      await refresh();
    }
  }

  Future<void> save(RetrospectiveReflection reflection, String text) async {
    final data = await ref.read(monthlyRetrospectiveRepositoryProvider).save(reflection, text);
    state = AsyncData(data);
  }

  Future<void> useBasicQuestion(String id) async {
    state = AsyncData(await ref.read(monthlyRetrospectiveRepositoryProvider).useBasicQuestion(id));
  }
}
