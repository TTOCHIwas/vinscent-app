import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../couple/application/couple_controller.dart';
import '../../../couple/data/couple.dart';
import '../../application/couple_recording_overview_controller.dart';
import '../../application/recording_capture_controller.dart';
import '../../application/recording_playback_controller.dart';
import '../../data/couple_recording.dart';
import 'recording_control_button.dart';

class HomeRecordingPanel extends ConsumerWidget {
  const HomeRecordingPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<RecordingCaptureState>(recordingCaptureControllerProvider, (
      previous,
      next,
    ) {
      final errorMessage = next.errorMessage;
      if (errorMessage == null || errorMessage == previous?.errorMessage) {
        return;
      }

      unawaited(HapticFeedback.heavyImpact());
      ref.read(recordingCaptureControllerProvider.notifier).clearError();
    });

    ref.listen<AsyncValue<CoupleRecordingOverview?>>(
      coupleRecordingOverviewControllerProvider,
      (_, next) {
        if (next is! AsyncData<CoupleRecordingOverview?>) {
          return;
        }

        final currentRecording = next.value?.currentRecording;
        final availableTargetKeys = <String>{
          if (currentRecording != null)
            RecordingPlaybackTarget.homeCurrent(currentRecording).key,
        };

        unawaited(
          ref
              .read(
                recordingPlaybackControllerProvider(
                  RecordingPlaybackSurface.home,
                ).notifier,
              )
              .syncAvailableTargetKeys(availableTargetKeys),
        );
      },
    );

    final coupleAsync = ref.watch(coupleControllerProvider);
    final overviewAsync = ref.watch(coupleRecordingOverviewControllerProvider);
    final captureState = ref.watch(recordingCaptureControllerProvider);
    final playbackState = ref.watch(
      recordingPlaybackControllerProvider(RecordingPlaybackSurface.home),
    );
    final captureController = ref.read(
      recordingCaptureControllerProvider.notifier,
    );
    final playbackController = ref.read(
      recordingPlaybackControllerProvider(
        RecordingPlaybackSurface.home,
      ).notifier,
    );

    final couple = switch (coupleAsync) {
      AsyncData<Couple?>(:final value) => value,
      _ => null,
    };
    final currentRecording = switch (overviewAsync) {
      AsyncData<CoupleRecordingOverview?>(:final value) =>
        value?.currentRecording,
      _ => null,
    };
    final playbackTarget = currentRecording == null
        ? null
        : RecordingPlaybackTarget.homeCurrent(currentRecording);
    final isPlaying =
        playbackTarget != null &&
        playbackState.isPlaying &&
        playbackState.activeTargetKey == playbackTarget.key;
    final canRecord = couple?.canEditSharedData ?? false;

    return Center(
      child: RecordingControlButton(
        capturePhase: captureState.phase,
        recordingProgress: captureState.elapsedMs / recordingMaxDurationMs,
        hasRecording: currentRecording != null,
        isPlaying: isPlaying,
        isPlaybackBusy: playbackState.isBusy,
        isLoading: coupleAsync.isLoading || overviewAsync.isLoading,
        canRecord: canRecord,
        onPlaybackPressed: playbackTarget == null
            ? null
            : () => unawaited(playbackController.toggle(playbackTarget)),
        onRecordStart: !canRecord || couple == null
            ? null
            : () {
                unawaited(HapticFeedback.mediumImpact());
                unawaited(playbackController.reset());
                unawaited(captureController.startRecording(couple));
              },
        onRecordEnd: () {
          unawaited(HapticFeedback.lightImpact());
          unawaited(captureController.finishGesture());
        },
      ),
    );
  }
}
