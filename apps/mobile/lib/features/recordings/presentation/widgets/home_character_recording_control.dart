import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../characters/presentation/widgets/couple_character_avatar.dart';
import '../../../couple/application/couple_controller.dart';
import '../../../couple/data/couple.dart';
import '../../application/couple_recording_overview_controller.dart';
import '../../application/recording_capture_controller.dart';
import '../../application/recording_playback_controller.dart';
import '../../data/couple_recording.dart';
import 'character_recording_control.dart';

class HomeCharacterRecordingControl extends ConsumerWidget {
  const HomeCharacterRecordingControl({super.key});

  static const preferredControlSize = 250.0;
  static const characterSpacing = 32.0;

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
        final placedSlots = next.value?.placedSlots ?? const [];
        final availableTargetKeys = <String>{
          if (currentRecording != null)
            RecordingPlaybackTarget.homeCurrent(currentRecording).key,
          for (final slot in placedSlots)
            RecordingPlaybackTarget.homeSlot(slot).key,
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
    final needsCharacterSetup = couple?.needsCharacterSetupPrompt ?? false;
    final isPlaying =
        !needsCharacterSetup &&
        playbackTarget != null &&
        playbackState.isPlaying &&
        playbackState.activeTargetKey == playbackTarget.key;
    final canRecord = couple?.canEditSharedData ?? false;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : preferredControlSize;
        final availableHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : preferredControlSize;
        final controlSize = math.min(
          preferredControlSize,
          math.min(availableWidth, availableHeight),
        );
        final characterSize = math.max(0.0, controlSize - characterSpacing);

        return Align(
          alignment: Alignment.topCenter,
          child: CharacterRecordingControl(
            size: controlSize,
            capturePhase: captureState.phase,
            recordingProgress: captureState.elapsedMs / recordingMaxDurationMs,
            recordingKey: currentRecording?.recordingId,
            isPlaying: isPlaying,
            isPlaybackBusy: playbackState.isBusy,
            isLoading: coupleAsync.isLoading || overviewAsync.isLoading,
            canRecord: canRecord,
            onPrimaryTap: needsCharacterSetup
                ? () => context.push('/settings/character')
                : null,
            primaryTapSemanticsLabel: needsCharacterSetup ? '캐릭터 설정' : null,
            onPlaybackPressed: needsCharacterSetup || playbackTarget == null
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
            child: SizedBox.square(
              dimension: characterSize,
              child: const _ResponsiveCoupleCharacterAvatar(),
            ),
          ),
        );
      },
    );
  }
}

class _ResponsiveCoupleCharacterAvatar extends StatelessWidget {
  const _ResponsiveCoupleCharacterAvatar();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(constraints.maxWidth, constraints.maxHeight);
        return CoupleCharacterAvatar(size: size);
      },
    );
  }
}
