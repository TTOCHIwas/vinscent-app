import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../couple/application/couple_controller.dart';
import '../../../couple/data/couple.dart';
import '../../application/couple_recording_overview_controller.dart';
import '../../application/recording_playback_controller.dart';
import '../../application/recording_capture_controller.dart';
import '../../data/couple_recording.dart';

class HomeRecordingPanel extends ConsumerWidget {
  const HomeRecordingPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<RecordingCaptureState>(recordingCaptureControllerProvider, (
      previous,
      next,
    ) {
      final message = next.errorMessage;
      if (message == null || message == previous?.errorMessage) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
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
    final playbackController = ref.read(
      recordingPlaybackControllerProvider(
        RecordingPlaybackSurface.home,
      ).notifier,
    );

    return SizedBox(
      width: double.infinity,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.wireframeBorder),
          borderRadius: BorderRadius.circular(8),
        ),
        child: coupleAsync.when(
          loading: () => const _RecordingPanelLoading(),
          error: (_, _) => _RecordingPanelError(
            message: '녹음 정보를 불러오지 못했어요.',
            onRetry: () => ref
                .read(coupleRecordingOverviewControllerProvider.notifier)
                .refresh(),
          ),
          data: (couple) => _buildContent(
            context: context,
            couple: couple,
            overviewAsync: overviewAsync,
            captureState: captureState,
            playbackState: playbackState,
            playbackController: playbackController,
          ),
        ),
      ),
    );
  }

  Widget _buildContent({
    required BuildContext context,
    required Couple? couple,
    required AsyncValue<CoupleRecordingOverview?> overviewAsync,
    required RecordingCaptureState captureState,
    required RecordingPlaybackState playbackState,
    required RecordingPlaybackController playbackController,
  }) {
    final canRead = couple?.canReadSharedData ?? false;
    final canEdit = couple?.canEditSharedData ?? false;

    if (!canRead) {
      return const _RecordingPanelError(message: '녹음을 확인할 수 없어요.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('녹음', style: AppTextStyles.homeBodyMedium),
            ),
            TextButton(
              onPressed: () => context.push('/home/recordings'),
              child: const Text('보관함'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        overviewAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          error: (_, _) => _RecordingPanelError(
            message: '녹음 상태를 불러오지 못했어요.',
            onRetry: () => ref
                .read(coupleRecordingOverviewControllerProvider.notifier)
                .refresh(),
          ),
          data: (overview) {
            final currentRecording = overview?.currentRecording;
            if (currentRecording == null) {
              return _CurrentRecordingEmpty(
                isArchivedReadOnly: couple?.isArchivedReadOnly ?? false,
              );
            }

            final playbackTarget = RecordingPlaybackTarget.homeCurrent(
              currentRecording,
            );
            return _CurrentRecordingCard(
              recording: currentRecording,
              isMine: currentRecording.senderUserId ==
                  Supabase.instance.client.auth.currentUser?.id,
              isPlaying:
                  playbackState.isPlaying &&
                  playbackState.activeTargetKey == playbackTarget.key,
              onPlayPressed: () =>
                  unawaited(playbackController.toggle(playbackTarget)),
            );
          },
        ),
        const SizedBox(height: 14),
        _PressAndHoldRecordButton(
          captureState: captureState,
          enabled: canEdit,
          onLongPressStart: canEdit && couple != null
              ? (_) => unawaited(
                  ref
                      .read(recordingCaptureControllerProvider.notifier)
                      .startRecording(couple),
                )
              : null,
          onLongPressMoveUpdate: canEdit
              ? (details) => ref
                    .read(recordingCaptureControllerProvider.notifier)
                    .updateDragOffset(details.offsetFromOrigin.dy)
              : null,
          onLongPressEnd: canEdit
              ? (_) => unawaited(
                  ref
                      .read(recordingCaptureControllerProvider.notifier)
                      .finishGesture(),
                )
              : null,
        ),
        const SizedBox(height: 8),
        Text(
          canEdit
              ? '길게 눌러 최대 15초까지 녹음할 수 있어요.'
              : '보관 중에는 녹음을 새로 남길 수 없어요.',
          style: AppTextStyles.homeCharacterLabel.copyWith(
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}

class _RecordingPanelLoading extends StatelessWidget {
  const _RecordingPanelLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: SizedBox.square(
          dimension: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class _RecordingPanelError extends StatelessWidget {
  const _RecordingPanelError({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final retry = onRetry;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          message,
          style: AppTextStyles.homeCharacterLabel.copyWith(
            color: AppColors.textMuted,
          ),
        ),
        if (retry != null)
          TextButton(onPressed: retry, child: const Text('다시 시도')),
      ],
    );
  }
}

class _CurrentRecordingEmpty extends StatelessWidget {
  const _CurrentRecordingEmpty({required this.isArchivedReadOnly});

  final bool isArchivedReadOnly;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '현재 재생할 녹음이 없어요.',
          style: AppTextStyles.homeBody,
        ),
        const SizedBox(height: 4),
        Text(
          isArchivedReadOnly
              ? '보관 중인 녹음만 계속 들을 수 있어요.'
              : '새 녹음을 남기면 상대방도 바로 들을 수 있어요.',
          style: AppTextStyles.homeCharacterLabel.copyWith(
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}

class _CurrentRecordingCard extends StatelessWidget {
  const _CurrentRecordingCard({
    required this.recording,
    required this.isMine,
    required this.isPlaying,
    required this.onPlayPressed,
  });

  final CurrentCoupleRecording recording;
  final bool isMine;
  final bool isPlaying;
  final VoidCallback onPlayPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 44,
          height: 44,
          child: OutlinedButton(
            onPressed: onPlayPressed,
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              side: const BorderSide(color: AppColors.wireframeBorder),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Icon(
              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isMine ? '내가 남긴 현재 녹음' : '상대가 남긴 현재 녹음',
                style: AppTextStyles.homeBody,
              ),
              const SizedBox(height: 4),
              Text(
                '${_formatRecordedAt(recording.recordedAt)} · ${_formatDuration(recording.duration)}',
                style: AppTextStyles.homeCharacterLabel.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PressAndHoldRecordButton extends StatelessWidget {
  const _PressAndHoldRecordButton({
    required this.captureState,
    required this.enabled,
    this.onLongPressStart,
    this.onLongPressMoveUpdate,
    this.onLongPressEnd,
  });

  final RecordingCaptureState captureState;
  final bool enabled;
  final GestureLongPressStartCallback? onLongPressStart;
  final GestureLongPressMoveUpdateCallback? onLongPressMoveUpdate;
  final GestureLongPressEndCallback? onLongPressEnd;

  @override
  Widget build(BuildContext context) {
    final isInteractive =
        enabled && !captureState.isPreparing && !captureState.isUploading;
    final isRecording = captureState.isRecording;
    final isCancelArmed = captureState.isCancelArmed;
    final backgroundColor = isRecording
        ? (isCancelArmed
              ? AppColors.actionDisabled
              : AppColors.actionPrimary)
        : AppColors.background;
    final contentColor = isRecording
        ? AppColors.textInverse
        : isInteractive
        ? AppColors.textPrimary
        : AppColors.actionDisabledContent;
    final progressValue = captureState.elapsedMs / 15000;

    return GestureDetector(
      onLongPressStart: isInteractive ? onLongPressStart : null,
      onLongPressMoveUpdate: isRecording ? onLongPressMoveUpdate : null,
      onLongPressEnd: isRecording || captureState.isPreparing
          ? onLongPressEnd
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border.all(color: AppColors.wireframeBorder),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (captureState.isUploading)
                  SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: contentColor,
                    ),
                  )
                else
                  Icon(Icons.mic_rounded, color: contentColor),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    _labelForState(captureState, enabled),
                    style: AppTextStyles.homeBody.copyWith(color: contentColor),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            if (isRecording) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progressValue.clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: AppColors.background.withValues(alpha: 0.24),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.textInverse,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isCancelArmed
                    ? '손을 떼면 녹음이 취소돼요.'
                    : '${_formatDuration(Duration(milliseconds: captureState.elapsedMs))} / 00:15',
                style: AppTextStyles.homeCharacterLabel.copyWith(
                  color: AppColors.textInverse,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _labelForState(RecordingCaptureState state, bool enabled) {
    if (!enabled) {
      return '보관 중에는 녹음을 새로 남길 수 없어요.';
    }

    return switch (state.phase) {
      RecordingCapturePhase.idle => '길게 눌러 녹음',
      RecordingCapturePhase.preparing => '녹음 준비 중',
      RecordingCapturePhase.recording => state.isCancelArmed
          ? '위로 밀어서 취소'
          : '손을 떼면 바로 저장돼요',
      RecordingCapturePhase.uploading => '녹음을 저장하고 있어요',
    };
  }
}

String _formatRecordedAt(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '${value.month}/${value.day} $hour:$minute';
}

String _formatDuration(Duration duration) {
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
