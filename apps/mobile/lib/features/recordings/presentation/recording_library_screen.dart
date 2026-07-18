import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../couple/application/couple_controller.dart';
import '../../couple/data/couple.dart';
import '../../profile/application/profile_controller.dart';
import '../../settings/presentation/widgets/settings_group.dart';
import '../../settings/presentation/widgets/settings_page_layout.dart';
import '../application/couple_recording_overview_controller.dart';
import '../application/recording_playback_controller.dart';
import '../application/recording_slot_placement_session.dart';
import '../recording_debug_log.dart';
import '../data/couple_recording.dart';
import '../data/couple_recording_failure.dart';

class RecordingLibraryScreen extends ConsumerStatefulWidget {
  const RecordingLibraryScreen({super.key});

  @override
  ConsumerState<RecordingLibraryScreen> createState() =>
      _RecordingLibraryScreenState();
}

class _RecordingLibraryScreenState
    extends ConsumerState<RecordingLibraryScreen> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<CoupleRecordingOverview?>>(
      coupleRecordingOverviewControllerProvider,
      (_, next) {
        if (next is! AsyncData<CoupleRecordingOverview?>) {
          return;
        }

        final overview = next.value;
        final currentRecording = overview?.currentRecording;
        final slotTargets =
            overview?.savedSlots.map(RecordingPlaybackTarget.librarySlot) ??
            const <RecordingPlaybackTarget>[];
        final availableTargetKeys = <String>{
          if (currentRecording != null)
            RecordingPlaybackTarget.libraryCurrent(currentRecording).key,
          ...slotTargets.map((target) => target.key),
        };

        unawaited(
          ref
              .read(
                recordingPlaybackControllerProvider(
                  RecordingPlaybackSurface.library,
                ).notifier,
              )
              .syncAvailableTargetKeys(availableTargetKeys),
        );
      },
    );

    final coupleAsync = ref.watch(coupleControllerProvider);
    final currentUserId = ref.watch(
      profileControllerProvider.select(
        (state) =>
            state.maybeWhen(data: (profile) => profile?.id, orElse: () => null),
      ),
    );
    final overviewAsync = ref.watch(coupleRecordingOverviewControllerProvider);
    final playbackState = ref.watch(
      recordingPlaybackControllerProvider(RecordingPlaybackSurface.library),
    );
    final playbackController = ref.read(
      recordingPlaybackControllerProvider(
        RecordingPlaybackSurface.library,
      ).notifier,
    );

    return SettingsPageLayout(
      title: '녹음 보관함',
      onBackPressed: () {
        if (context.canPop()) {
          context.pop();
          return;
        }
        context.go('/home');
      },
      child: coupleAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        error: (_, _) => const _LibraryMessage(title: '녹음 보관함을 불러오지 못했어요.'),
        data: (couple) => overviewAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          error: (_, _) => _LibraryMessage(
            title: '녹음 정보를 불러오지 못했어요.',
            actionLabel: '다시 시도',
            onAction: () => ref
                .read(coupleRecordingOverviewControllerProvider.notifier)
                .refresh(),
          ),
          data: (overview) => _buildContent(
            context: context,
            couple: couple,
            overview: overview,
            playbackState: playbackState,
            playbackController: playbackController,
            currentUserId: currentUserId,
          ),
        ),
      ),
    );
  }

  Widget _buildContent({
    required BuildContext context,
    required Couple? couple,
    required CoupleRecordingOverview? overview,
    required RecordingPlaybackState playbackState,
    required RecordingPlaybackController playbackController,
    required String? currentUserId,
  }) {
    if (couple == null || overview == null) {
      return const _LibraryMessage(title: '보관함을 확인할 수 없어요.');
    }

    final canEdit = couple.canEditSharedData;
    final currentRecording = overview.currentRecording;
    final currentPlaybackTarget = currentRecording == null
        ? null
        : RecordingPlaybackTarget.libraryCurrent(currentRecording);
    final slotsByIndex = {
      for (final slot in overview.savedSlots) slot.slotIndex: slot,
    };

    return ListView(
      key: const ValueKey('recording-library-list'),
      padding: EdgeInsets.zero,
      children: [
        SettingsGroup(
          label: '현재 녹음',
          children: [
            if (currentRecording == null)
              const _LibraryEmptyRow(message: '아직 저장된 현재 녹음이 없어요.')
            else
              _CurrentRecordingPreview(
                recording: currentRecording,
                isMine: currentRecording.senderUserId == currentUserId,
                isPlaying:
                    playbackState.isPlaying &&
                    playbackState.activeTargetKey == currentPlaybackTarget!.key,
                onPlayPressed: () => unawaited(
                  playbackController.toggle(currentPlaybackTarget!),
                ),
              ),
          ],
        ),
        const SizedBox(height: 24),
        _LibrarySectionHeader(
          title: '보관 슬롯 ${overview.slotLimit}/10',
          actionLabel: canEdit && overview.slotLimit < 10 ? '슬롯 추가' : null,
          onAction: canEdit && overview.slotLimit < 10 && !_isProcessing
              ? _openNextSlot
              : null,
        ),
        const SizedBox(height: 8),
        SettingsGroup(
          dividerIndent: 84,
          children: [
            for (var index = 1; index <= overview.slotLimit; index++)
              _RecordingSlotTile(
                slotIndex: index,
                slot: slotsByIndex[index],
                currentRecording: currentRecording,
                canEdit: canEdit,
                isPlaying: _isSlotPlaying(
                  slot: slotsByIndex[index],
                  playbackState: playbackState,
                ),
                currentUserId: currentUserId,
                onPlayPressed: _buildSlotPlayCallback(
                  slot: slotsByIndex[index],
                  playbackController: playbackController,
                ),
                onSavePressed:
                    !canEdit || currentRecording == null || _isProcessing
                    ? null
                    : slotsByIndex[index] == null
                    ? () => context.push('/home/recordings/create/$index')
                    : () => _saveSlot(
                        slotIndex: index,
                        slot: slotsByIndex[index],
                      ),
                onDeletePressed:
                    !canEdit || slotsByIndex[index] == null || _isProcessing
                    ? null
                    : () => _deleteSlot(slotsByIndex[index]!),
                onArtworkPressed:
                    slotsByIndex[index] == null ||
                        (!canEdit && slotsByIndex[index]!.artwork == null)
                    ? null
                    : () => context.push(
                        '/home/recordings/${slotsByIndex[index]!.slotId}/artwork',
                      ),
                onHomePlacementPressed:
                    !canEdit || slotsByIndex[index]?.artwork == null
                    ? null
                    : () => _startHomePlacement(
                        slot: slotsByIndex[index]!,
                        overview: overview,
                      ),
              ),
          ],
        ),
      ],
    );
  }

  bool _isSlotPlaying({
    required CoupleRecordingSlot? slot,
    required RecordingPlaybackState playbackState,
  }) {
    if (slot == null) {
      return false;
    }

    final playbackTarget = RecordingPlaybackTarget.librarySlot(slot);
    return playbackState.isPlaying &&
        playbackState.activeTargetKey == playbackTarget.key;
  }

  VoidCallback? _buildSlotPlayCallback({
    required CoupleRecordingSlot? slot,
    required RecordingPlaybackController playbackController,
  }) {
    if (slot == null) {
      return null;
    }

    final playbackTarget = RecordingPlaybackTarget.librarySlot(slot);
    return () => unawaited(playbackController.toggle(playbackTarget));
  }

  Future<void> _openNextSlot() async {
    final couple = _readAsyncValue(ref.read(coupleControllerProvider));
    final overview = _readAsyncValue(
      ref.read(coupleRecordingOverviewControllerProvider),
    );
    debugRecordingLog(
      'Open slot button pressed: '
      'coupleId=${couple?.id}, canEdit=${couple?.canEditSharedData}, '
      'accessMode=${couple?.accessMode.name}, currentSlotLimit=${overview?.slotLimit}',
    );

    setState(() {
      _isProcessing = true;
    });

    try {
      await ref
          .read(coupleRecordingOverviewControllerProvider.notifier)
          .openNextSlot();
      if (!mounted) {
        return;
      }

      final updatedOverview = _readAsyncValue(
        ref.read(coupleRecordingOverviewControllerProvider),
      );
      debugRecordingLog(
        'Open slot flow completed in screen: '
        'updatedSlotLimit=${updatedOverview?.slotLimit}, '
        'savedSlotCount=${updatedOverview?.savedSlots.length}',
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('새 슬롯을 열었어요.')));
    } catch (error) {
      debugRecordingLog(
        'Open slot flow failed in screen: '
        'errorType=${error.runtimeType}, error=$error',
      );
      _showError(error);
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _saveSlot({
    required int slotIndex,
    required CoupleRecordingSlot? slot,
  }) async {
    final title = await _promptForTitle(initialTitle: slot?.title);
    if (title == null || !mounted) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      await ref
          .read(coupleRecordingOverviewControllerProvider.notifier)
          .saveCurrentRecordingToSlot(
            slotIndex: slotIndex,
            title: title,
            expectedSlotRevision: slot?.slotRevision,
          );
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(slot == null ? '슬롯에 녹음을 저장했어요.' : '슬롯 녹음을 교체했어요.'),
        ),
      );
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _deleteSlot(CoupleRecordingSlot slot) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('슬롯을 비울까요?'),
          content: Text("'${slot.title}' 녹음은 즉시 삭제되고 복구할 수 없어요."),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('삭제'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true || !mounted) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      await ref
          .read(coupleRecordingOverviewControllerProvider.notifier)
          .deleteSlot(
            slotId: slot.slotId,
            expectedSlotRevision: slot.slotRevision,
          );
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('슬롯 녹음을 삭제했어요.')));
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _startHomePlacement({
    required CoupleRecordingSlot slot,
    required CoupleRecordingOverview overview,
  }) {
    if (slot.placement == null && overview.placedSlots.length >= 4) {
      _showError(
        const CoupleRecordingRepositoryException(
          CoupleRecordingFailureReason.recordingPlacementLimitReached,
        ),
      );
      return;
    }

    unawaited(HapticFeedback.mediumImpact());
    ref.read(recordingSlotPlacementSessionProvider.notifier).begin(slot.slotId);
    context.go('/home');
  }

  Future<String?> _promptForTitle({String? initialTitle}) async {
    final controller = TextEditingController(text: initialTitle ?? '');
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('슬롯 제목'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              autofocus: true,
              maxLength: 20,
              decoration: const InputDecoration(hintText: '제목을 입력해 주세요.'),
              validator: (value) {
                final trimmed = value?.trim() ?? '';
                if (trimmed.isEmpty) {
                  return '제목을 입력해 주세요.';
                }

                if (trimmed.length > 20) {
                  return '제목은 20자까지 입력할 수 있어요.';
                }

                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) {
                  return;
                }

                Navigator.of(context).pop(controller.text.trim());
              },
              child: const Text('저장'),
            ),
          ],
        );
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.dispose();
    });
    return result;
  }

  void _showError(Object error) {
    if (!mounted) {
      return;
    }

    debugRecordingLog(
      'Recording library error surfaced to user: '
      'errorType=${error.runtimeType}, error=$error, '
      'message=${_messageForError(error)}',
    );
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_messageForError(error))));
  }

  T? _readAsyncValue<T>(AsyncValue<T> value) {
    return switch (value) {
      AsyncData<T> data => data.value,
      _ => null,
    };
  }

  String _messageForError(Object error) {
    if (error is CoupleRecordingRepositoryException) {
      return switch (error.reason) {
        CoupleRecordingFailureReason.configMissing =>
          '앱 설정을 불러오지 못했어요. 다시 실행해 주세요.',
        CoupleRecordingFailureReason.authRequired =>
          '로그인 상태를 확인한 뒤 다시 시도해 주세요.',
        CoupleRecordingFailureReason.activeCoupleRequired =>
          '현재 연결된 커플만 보관함을 수정할 수 있어요.',
        CoupleRecordingFailureReason.readableCoupleRequired =>
          '보관함 정보를 불러온 뒤 다시 시도해 주세요.',
        CoupleRecordingFailureReason.recordingSlotConflict =>
          '보관함이 다른 기기에서 변경됐어요. 화면을 새로고침한 뒤 다시 시도해 주세요.',
        CoupleRecordingFailureReason.recordingSlotLocked => '아직 열리지 않은 슬롯이에요.',
        CoupleRecordingFailureReason.recordingSlotLimitReached =>
          '더 이상 열 수 있는 슬롯이 없어요.',
        CoupleRecordingFailureReason.currentRecordingRequired =>
          '먼저 현재 녹음을 남겨 주세요.',
        CoupleRecordingFailureReason.invalidRecordingArtwork =>
          '그림을 저장할 수 있는 크기로 줄여 주세요.',
        CoupleRecordingFailureReason.recordingArtworkFileMissing =>
          '그림 파일 업로드를 완료하지 못했어요.',
        CoupleRecordingFailureReason.recordingArtworkRequired =>
          '먼저 슬롯 그림을 만들어 주세요.',
        CoupleRecordingFailureReason.recordingPlacementConflict =>
          '홈 배치가 다른 기기에서 변경됐어요. 다시 시도해 주세요.',
        CoupleRecordingFailureReason.recordingPlacementLimitReached =>
          '홈에는 슬롯 그림을 최대 4개까지 둘 수 있어요.',
        CoupleRecordingFailureReason.invalidRecordingSlotTitle =>
          '제목은 1자 이상 20자 이하로 입력해 주세요.',
        CoupleRecordingFailureReason.requestTimeout =>
          '요청이 지연되고 있어요. 다시 시도해 주세요.',
        _ => '보관함을 업데이트하지 못했어요.',
      };
    }

    return '보관함을 업데이트하지 못했어요.';
  }
}

class _LibrarySectionHeader extends StatelessWidget {
  const _LibrarySectionHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final actionLabel = this.actionLabel;

    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              title,
              style: AppTextStyles.homeCharacterLabel.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ),
        ),
        if (actionLabel != null)
          TextButton(onPressed: onAction, child: Text(actionLabel)),
      ],
    );
  }
}

class _LibraryEmptyRow extends StatelessWidget {
  const _LibraryEmptyRow({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 60),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            message,
            style: AppTextStyles.homeCharacterLabel.copyWith(
              color: AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _CurrentRecordingPreview extends StatelessWidget {
  const _CurrentRecordingPreview({
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
    return Semantics(
      button: true,
      label: isPlaying ? '현재 녹음 일시정지' : '현재 녹음 재생',
      child: InkWell(
        key: const ValueKey('recording-library-current-row'),
        onTap: onPlayPressed,
        splashColor: AppColors.settingsPressed,
        highlightColor: AppColors.settingsPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 68),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  isPlaying
                      ? Icons.pause_circle_filled_rounded
                      : Icons.play_circle_outline_rounded,
                  color: AppColors.textPrimary,
                  size: 30,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isMine ? '내가 남긴 녹음' : '상대가 남긴 녹음',
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
            ),
          ),
        ),
      ),
    );
  }
}

class _RecordingSlotTile extends StatelessWidget {
  const _RecordingSlotTile({
    required this.slotIndex,
    required this.slot,
    required this.currentRecording,
    required this.canEdit,
    required this.isPlaying,
    required this.currentUserId,
    this.onPlayPressed,
    this.onSavePressed,
    this.onDeletePressed,
    this.onArtworkPressed,
    this.onHomePlacementPressed,
  });

  final int slotIndex;
  final CoupleRecordingSlot? slot;
  final CurrentCoupleRecording? currentRecording;
  final bool canEdit;
  final bool isPlaying;
  final String? currentUserId;
  final VoidCallback? onPlayPressed;
  final VoidCallback? onSavePressed;
  final VoidCallback? onDeletePressed;
  final VoidCallback? onArtworkPressed;
  final VoidCallback? onHomePlacementPressed;

  @override
  Widget build(BuildContext context) {
    final slot = this.slot;

    return slot == null
        ? _EmptySlotContent(
            slotIndex: slotIndex,
            canEdit: canEdit,
            hasCurrentRecording: currentRecording != null,
            onSavePressed: onSavePressed,
          )
        : _FilledSlotContent(
            slot: slot,
            canEdit: canEdit,
            isPlaying: isPlaying,
            currentUserId: currentUserId,
            onPlayPressed: onPlayPressed,
            onSavePressed: onSavePressed,
            onDeletePressed: onDeletePressed,
            onArtworkPressed: onArtworkPressed,
            onHomePlacementPressed: onHomePlacementPressed,
          );
  }
}

class _EmptySlotContent extends StatelessWidget {
  const _EmptySlotContent({
    required this.slotIndex,
    required this.canEdit,
    required this.hasCurrentRecording,
    this.onSavePressed,
  });

  final int slotIndex;
  final bool canEdit;
  final bool hasCurrentRecording;
  final VoidCallback? onSavePressed;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 76),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            const SizedBox.square(
              dimension: 56,
              child: Icon(
                Icons.mic_none_rounded,
                color: AppColors.textMuted,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('슬롯 $slotIndex', style: AppTextStyles.homeBody),
                  const SizedBox(height: 4),
                  Text(
                    hasCurrentRecording ? '비어 있음' : '저장할 현재 녹음이 없어요.',
                    style: AppTextStyles.homeCharacterLabel.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (canEdit)
              IconButton(
                key: ValueKey('recording-library-empty-slot-save-$slotIndex'),
                tooltip: '현재 녹음 저장',
                onPressed: hasCurrentRecording ? onSavePressed : null,
                icon: const Icon(Icons.add_rounded),
              ),
          ],
        ),
      ),
    );
  }
}

enum _RecordingSlotMenuAction { artwork, homePlacement, replace, delete }

class _RecordingSlotMenuItem extends StatelessWidget {
  const _RecordingSlotMenuItem({
    required this.icon,
    required this.label,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final color = isDestructive
        ? AppColors.recordingActive
        : AppColors.textPrimary;

    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: color)),
      ],
    );
  }
}

class _SlotArtworkThumbnail extends StatelessWidget {
  const _SlotArtworkThumbnail({required this.slot});

  final CoupleRecordingSlot slot;

  @override
  Widget build(BuildContext context) {
    final artwork = slot.artwork;

    return SizedBox.square(
      key: artwork == null
          ? null
          : ValueKey('recording-slot-artwork-${slot.slotId}'),
      dimension: 56,
      child: artwork == null
          ? const Icon(
              Icons.mic_none_rounded,
              color: AppColors.textMuted,
              size: 28,
            )
          : Image.network(
              artwork.previewUrl,
              fit: BoxFit.contain,
              gaplessPlayback: true,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.broken_image_outlined,
                color: AppColors.textMuted,
              ),
            ),
    );
  }
}

class _FilledSlotContent extends StatelessWidget {
  const _FilledSlotContent({
    required this.slot,
    required this.canEdit,
    required this.isPlaying,
    required this.currentUserId,
    this.onPlayPressed,
    this.onSavePressed,
    this.onDeletePressed,
    this.onArtworkPressed,
    this.onHomePlacementPressed,
  });

  final CoupleRecordingSlot slot;
  final bool canEdit;
  final bool isPlaying;
  final String? currentUserId;
  final VoidCallback? onPlayPressed;
  final VoidCallback? onSavePressed;
  final VoidCallback? onDeletePressed;
  final VoidCallback? onArtworkPressed;
  final VoidCallback? onHomePlacementPressed;

  @override
  Widget build(BuildContext context) {
    final isMine = slot.senderUserId == currentUserId;
    final artworkLabel = slot.artwork == null
        ? '그림 추가'
        : canEdit
        ? '그림 수정'
        : '그림 보기';
    final hasMenu =
        onArtworkPressed != null ||
        onHomePlacementPressed != null ||
        onSavePressed != null ||
        onDeletePressed != null;

    return Semantics(
      button: true,
      label: isPlaying ? '${slot.title} 일시정지' : '${slot.title} 재생',
      child: InkWell(
        key: ValueKey('recording-library-slot-${slot.slotId}'),
        onTap: onPlayPressed,
        onLongPress: onHomePlacementPressed,
        splashColor: AppColors.settingsPressed,
        highlightColor: AppColors.settingsPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 76),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                _SlotArtworkThumbnail(slot: slot),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(slot.title, style: AppTextStyles.homeBodyMedium),
                      const SizedBox(height: 4),
                      Text(
                        '${isMine ? '내가 남김' : '상대가 남김'} · ${_formatRecordedAt(slot.recordedAt)} · ${_formatDuration(slot.duration)}',
                        style: AppTextStyles.homeCharacterLabel.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: AppColors.textMuted,
                  size: 22,
                ),
                if (hasMenu)
                  PopupMenuButton<_RecordingSlotMenuAction>(
                    key: ValueKey('recording-library-slot-menu-${slot.slotId}'),
                    tooltip: '더보기',
                    onSelected: (action) {
                      switch (action) {
                        case _RecordingSlotMenuAction.artwork:
                          onArtworkPressed?.call();
                        case _RecordingSlotMenuAction.homePlacement:
                          onHomePlacementPressed?.call();
                        case _RecordingSlotMenuAction.replace:
                          onSavePressed?.call();
                        case _RecordingSlotMenuAction.delete:
                          onDeletePressed?.call();
                      }
                    },
                    itemBuilder: (context) => [
                      if (onArtworkPressed != null)
                        PopupMenuItem(
                          value: _RecordingSlotMenuAction.artwork,
                          child: _RecordingSlotMenuItem(
                            icon: slot.artwork == null
                                ? Icons.draw_outlined
                                : canEdit
                                ? Icons.edit_outlined
                                : Icons.visibility_outlined,
                            label: artworkLabel,
                          ),
                        ),
                      if (onHomePlacementPressed != null)
                        const PopupMenuItem(
                          value: _RecordingSlotMenuAction.homePlacement,
                          child: _RecordingSlotMenuItem(
                            icon: Icons.add_to_home_screen_outlined,
                            label: '홈에 배치',
                          ),
                        ),
                      if (onSavePressed != null)
                        const PopupMenuItem(
                          value: _RecordingSlotMenuAction.replace,
                          child: _RecordingSlotMenuItem(
                            icon: Icons.swap_horiz_rounded,
                            label: '현재 녹음으로 교체',
                          ),
                        ),
                      if (onDeletePressed != null)
                        const PopupMenuItem(
                          value: _RecordingSlotMenuAction.delete,
                          child: _RecordingSlotMenuItem(
                            icon: Icons.delete_outline_rounded,
                            label: '삭제',
                            isDestructive: true,
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LibraryMessage extends StatelessWidget {
  const _LibraryMessage({required this.title, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final actionLabel = this.actionLabel;
    final onAction = this.onAction;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: AppTextStyles.homeBodyMedium),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            TextButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ],
      ),
    );
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
