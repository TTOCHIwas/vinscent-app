import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_status.dart';
import '../../couple/application/couple_controller.dart';
import '../../couple/data/couple.dart';
import '../recording_debug_log.dart';
import '../data/couple_recording.dart';
import '../data/couple_recording_repository.dart';

final coupleRecordingOverviewControllerProvider =
    AsyncNotifierProvider<
      CoupleRecordingOverviewController,
      CoupleRecordingOverview?
    >(CoupleRecordingOverviewController.new);

class CoupleRecordingOverviewController
    extends AsyncNotifier<CoupleRecordingOverview?> {
  @override
  Future<CoupleRecordingOverview?> build() async {
    final authStatus = ref.watch(authControllerProvider);
    if (authStatus != AuthStatus.authenticated) {
      return null;
    }

    final couple = await ref.watch(coupleControllerProvider.future);
    if (couple == null || !couple.canReadSharedData) {
      return null;
    }

    return ref.watch(coupleRecordingRepositoryProvider).fetchOverview();
  }

  Future<void> refresh() async {
    await _refresh(showLoading: true);
  }

  Future<void> _refreshAfterMutation() async {
    await _refresh(showLoading: false);
  }

  Future<void> _refresh({required bool showLoading}) async {
    final couple = await ref.read(coupleControllerProvider.future);
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
    state = await AsyncValue.guard(
      () => ref.read(coupleRecordingRepositoryProvider).fetchOverview(),
    );
    final overview = switch (state) {
      AsyncData<CoupleRecordingOverview?> value => value.value,
      _ => null,
    };
    debugRecordingLog(
      'Overview refresh completed: '
      'hasError=${state.hasError}, slotLimit=${overview?.slotLimit}, '
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
