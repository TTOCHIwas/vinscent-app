import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_status.dart';
import '../../couple/application/couple_controller.dart';
import '../../couple/data/couple.dart';
import '../data/couple_recording.dart';
import '../data/couple_recording_repository.dart';

final coupleRecordingOverviewControllerProvider = AsyncNotifierProvider<
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
    final couple = await ref.read(coupleControllerProvider.future);
    if (couple == null || !couple.canReadSharedData) {
      state = const AsyncValue.data(null);
      return;
    }

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(coupleRecordingRepositoryProvider).fetchOverview(),
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
    await refresh();
  }

  Future<void> openNextSlot() async {
    await ref.read(coupleRecordingRepositoryProvider).openNextSlot();
    await refresh();
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
    await refresh();
  }

  Future<void> deleteSlot({
    required String slotId,
    required int expectedSlotRevision,
  }) async {
    await ref.read(coupleRecordingRepositoryProvider).deleteSlot(
      slotId: slotId,
      expectedSlotRevision: expectedSlotRevision,
    );
    await refresh();
  }
}
