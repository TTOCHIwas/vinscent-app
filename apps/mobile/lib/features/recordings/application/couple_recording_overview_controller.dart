import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_status.dart';
import '../../couple/application/couple_controller.dart';
import '../../couple/data/couple.dart';
import '../recording_debug_log.dart';
import '../data/couple_recording.dart';
import '../data/couple_recording_overview_change_source.dart';
import '../data/couple_recording_repository.dart';

final coupleRecordingOverviewControllerProvider =
    AsyncNotifierProvider<
      CoupleRecordingOverviewController,
      CoupleRecordingOverview?
    >(CoupleRecordingOverviewController.new, retry: (_, _) => null);

class CoupleRecordingOverviewController
    extends AsyncNotifier<CoupleRecordingOverview?> {
  static const _realtimeRefreshDebounce = Duration(milliseconds: 160);

  StreamSubscription<void>? _overviewChangesSubscription;
  Timer? _realtimeRefreshTimer;
  Future<void>? _pendingSubscriptionCancellation;
  Future<void>? _refreshLoop;
  bool _refreshQueued = false;
  bool _showLoadingOnNextRefresh = false;

  @override
  Future<CoupleRecordingOverview?> build() async {
    _registerRealtimeLifecycle();
    final authStatus = ref.watch(authControllerProvider);
    final repository = ref.watch(coupleRecordingRepositoryProvider);
    final coupleFuture = authStatus == AuthStatus.authenticated
        ? ref.watch(coupleControllerProvider.future)
        : null;
    await _stopWatchingOverviewChanges();
    if (!ref.mounted) {
      return null;
    }

    if (authStatus != AuthStatus.authenticated) {
      return null;
    }

    final couple = await coupleFuture!;
    if (!ref.mounted) {
      return null;
    }
    if (couple == null || !couple.canReadSharedData) {
      return null;
    }

    _watchOverviewChanges(couple.id);
    return repository.fetchOverview();
  }

  void _registerRealtimeLifecycle() {
    ref.onDispose(() {
      _realtimeRefreshTimer?.cancel();
      _realtimeRefreshTimer = null;
      _refreshQueued = false;
      _showLoadingOnNextRefresh = false;
      final subscription = _overviewChangesSubscription;
      _overviewChangesSubscription = null;
      _pendingSubscriptionCancellation = _cancelSubscription(subscription);
    });
  }

  void _watchOverviewChanges(String coupleId) {
    _overviewChangesSubscription = ref
        .read(coupleRecordingOverviewChangeSourceProvider)
        .watch(coupleId: coupleId)
        .listen(
          (_) => _scheduleRealtimeRefresh(),
          onError: (Object error, StackTrace stackTrace) {
            debugRecordingLog('Overview realtime stream failed: $error');
          },
        );
  }

  Future<void> _stopWatchingOverviewChanges() async {
    _realtimeRefreshTimer?.cancel();
    _realtimeRefreshTimer = null;
    final pendingCancellation = _pendingSubscriptionCancellation;
    _pendingSubscriptionCancellation = null;
    await pendingCancellation;
    final subscription = _overviewChangesSubscription;
    _overviewChangesSubscription = null;
    await _cancelSubscription(subscription);
  }

  Future<void> _cancelSubscription(
    StreamSubscription<void>? subscription,
  ) async {
    if (subscription == null) {
      return;
    }
    try {
      await subscription.cancel();
    } catch (error) {
      debugRecordingLog('Overview realtime cancellation failed: $error');
    }
  }

  void _scheduleRealtimeRefresh() {
    _realtimeRefreshTimer?.cancel();
    _realtimeRefreshTimer = Timer(_realtimeRefreshDebounce, () {
      _realtimeRefreshTimer = null;
      unawaited(_refreshFromRealtime());
    });
  }

  Future<void> _refreshFromRealtime() async {
    if (!ref.mounted) {
      return;
    }
    if (state.isLoading) {
      _scheduleRealtimeRefresh();
      return;
    }

    try {
      await _refresh(showLoading: false);
    } catch (error) {
      debugRecordingLog('Overview realtime refresh failed: $error');
    }
  }

  Future<void> refresh() async {
    await _refresh(showLoading: true);
  }

  Future<void> _refreshAfterMutation() async {
    await _refresh(showLoading: false);
  }

  Future<void> _refresh({required bool showLoading}) {
    _refreshQueued = true;
    _showLoadingOnNextRefresh |= showLoading;
    return _refreshLoop ??= _drainRefreshQueue();
  }

  Future<void> _drainRefreshQueue() async {
    try {
      while (_refreshQueued) {
        _refreshQueued = false;
        final showLoading = _showLoadingOnNextRefresh;
        _showLoadingOnNextRefresh = false;
        await _performRefresh(showLoading: showLoading);
      }
    } finally {
      _refreshLoop = null;
    }
  }

  Future<void> _performRefresh({required bool showLoading}) async {
    final requestRef = ref;
    final couple = await requestRef.read(coupleControllerProvider.future);
    if (!requestRef.mounted) {
      return;
    }
    if (couple == null || !couple.canReadSharedData) {
      debugRecordingLog('Overview refresh skipped: no readable couple');
      state = const AsyncValue.data(null);
      return;
    }

    debugRecordingLog(
      'Overview refresh started: '
      'coupleId=${couple.id}, canEdit=${couple.canEditSharedData}, '
      'accessMode=${couple.accessMode.name}',
    );
    if (showLoading) {
      state = const AsyncValue.loading();
    }
    final nextState = await AsyncValue.guard(
      () => requestRef.read(coupleRecordingRepositoryProvider).fetchOverview(),
    );
    if (!requestRef.mounted) {
      return;
    }
    state = nextState;
    final overview = switch (nextState) {
      AsyncData<CoupleRecordingOverview?> value => value.value,
      _ => null,
    };
    debugRecordingLog(
      'Overview refresh completed: '
      'hasError=${nextState.hasError}, slotLimit=${overview?.slotLimit}, '
      'savedSlotCount=${overview?.savedSlots.length}, '
      'hasCurrentRecording=${overview?.currentRecording != null}',
    );
  }

  Future<void> uploadCurrentRecording({
    required Couple couple,
    required Uint8List audioBytes,
    required int durationMs,
  }) async {
    await ref
        .read(coupleRecordingRepositoryProvider)
        .uploadCurrentRecording(
          coupleId: couple.id,
          audioBytes: audioBytes,
          durationMs: durationMs,
        );
    await _refreshAfterMutation();
  }

  Future<void> openNextSlot() async {
    final couple = await ref.read(coupleControllerProvider.future);
    debugRecordingLog(
      'Open slot requested from controller: '
      'coupleId=${couple?.id}, canEdit=${couple?.canEditSharedData}, '
      'accessMode=${couple?.accessMode.name}',
    );
    await ref.read(coupleRecordingRepositoryProvider).openNextSlot();
    await _refreshAfterMutation();
  }

  Future<void> saveCurrentRecordingToSlot({
    required int slotIndex,
    required String title,
    required int? expectedSlotRevision,
  }) async {
    await ref
        .read(coupleRecordingRepositoryProvider)
        .saveCurrentRecordingToSlot(
          slotIndex: slotIndex,
          title: title,
          expectedSlotRevision: expectedSlotRevision,
        );
    await _refreshAfterMutation();
  }

  Future<void> deleteSlot({
    required String slotId,
    required int expectedSlotRevision,
  }) async {
    await ref
        .read(coupleRecordingRepositoryProvider)
        .deleteSlot(slotId: slotId, expectedSlotRevision: expectedSlotRevision);
    await _refreshAfterMutation();
  }

  Future<void> saveSlotArtwork({
    required Couple couple,
    required String slotId,
    required int expectedSlotRevision,
    required Uint8List previewBytes,
    required Uint8List drawingDataBytes,
  }) async {
    await ref
        .read(coupleRecordingRepositoryProvider)
        .saveSlotArtwork(
          coupleId: couple.id,
          slotId: slotId,
          expectedSlotRevision: expectedSlotRevision,
          previewBytes: previewBytes,
          drawingDataBytes: drawingDataBytes,
        );
    await _refreshAfterMutation();
  }

  Future<void> upsertSlotPlacement({
    required String slotId,
    required double normalizedX,
    required double normalizedY,
    required int? expectedPlacementRevision,
  }) async {
    await ref
        .read(coupleRecordingRepositoryProvider)
        .upsertSlotPlacement(
          slotId: slotId,
          normalizedX: normalizedX,
          normalizedY: normalizedY,
          expectedPlacementRevision: expectedPlacementRevision,
        );
    await _refreshAfterMutation();
  }

  Future<void> deleteSlotPlacement({
    required String slotId,
    required int expectedPlacementRevision,
  }) async {
    await ref
        .read(coupleRecordingRepositoryProvider)
        .deleteSlotPlacement(
          slotId: slotId,
          expectedPlacementRevision: expectedPlacementRevision,
        );
    await _refreshAfterMutation();
  }
}
