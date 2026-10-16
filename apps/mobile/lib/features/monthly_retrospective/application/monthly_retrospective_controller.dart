import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../couple/application/couple_controller.dart';
import '../../couple/data/couple.dart';
import '../data/monthly_retrospective.dart';
import '../data/monthly_retrospective_repository.dart';

final monthlyRetrospectiveClockProvider = Provider<DateTime Function()>(
  (ref) =>
      () => DateTime.now().toUtc(),
);

final monthlyRetrospectiveControllerProvider =
    AsyncNotifierProvider.autoDispose<
      MonthlyRetrospectiveController,
      MonthlyRetrospective
    >(MonthlyRetrospectiveController.new, retry: (_, _) => null);

class MonthlyRetrospectiveController
    extends AsyncNotifier<MonthlyRetrospective> {
  int _epoch = 0;
  bool _writing = false;
  @override
  Future<MonthlyRetrospective> build() async {
    final couple = await ref.watch(coupleControllerProvider.future);
    if (couple == null ||
        !couple.canReadSharedData ||
        couple.status != CoupleStatus.active) {
      throw StateError('연결된 커플만 월간 회고를 볼 수 있어요');
    }
    final repository = ref.read(monthlyRetrospectiveRepositoryProvider);
    final data = await repository.fetch();
    final remaining = data.availableUntil.difference(
      ref.read(monthlyRetrospectiveClockProvider)(),
    );
    final timer = Timer(
      remaining.isNegative ? const Duration(minutes: 1) : remaining,
      () => ref.invalidateSelf(),
    );
    ref.onDispose(timer.cancel);
    final updates = Timer.periodic(const Duration(seconds: 30), (_) {
      if (ref.mounted) unawaited(refresh());
    });
    ref.onDispose(updates.cancel);
    return data;
  }

  Future<void> refresh() async {
    if (_writing) return;
    final epoch = ++_epoch;
    final result = await AsyncValue.guard(
      () => ref.read(monthlyRetrospectiveRepositoryProvider).fetch(),
    );
    if (ref.mounted && epoch == _epoch && !_writing) state = result;
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
    await _write(
      () => ref
          .read(monthlyRetrospectiveRepositoryProvider)
          .save(reflection, text),
    );
  }

  Future<void> useBasicQuestion(String id) async {
    await _write(
      () =>
          ref.read(monthlyRetrospectiveRepositoryProvider).useBasicQuestion(id),
    );
  }

  Future<void> _write(Future<MonthlyRetrospective> Function() operation) async {
    if (_writing) throw StateError('답변을 저장하고 있어요');
    _writing = true;
    ++_epoch;
    try {
      final result = await operation();
      if (ref.mounted) state = AsyncData(result);
    } catch (_) {
      _writing = false;
      if (ref.mounted) await refresh();
      rethrow;
    } finally {
      _writing = false;
    }
  }
}
