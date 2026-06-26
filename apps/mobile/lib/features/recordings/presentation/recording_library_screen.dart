import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/presentation/widgets/app_action_button.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../couple/application/couple_controller.dart';
import '../../couple/data/couple.dart';
import '../../settings/presentation/widgets/settings_page_header.dart';
import '../application/couple_recording_overview_controller.dart';
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
  late final AudioPlayer _player;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  String? _activePlaybackKey;
  bool _isPlaying = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _playerStateSubscription = _player.playerStateStream.listen((playerState) {
      if (!mounted) {
        return;
      }

      final shouldPlay =
          playerState.playing &&
          playerState.processingState != ProcessingState.completed;
      if (_isPlaying == shouldPlay) {
        return;
      }

      setState(() {
        _isPlaying = shouldPlay;
      });
    });
  }

  @override
  void dispose() {
    _playerStateSubscription?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final coupleAsync = ref.watch(coupleControllerProvider);
    final overviewAsync = ref.watch(coupleRecordingOverviewControllerProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SettingsPageHeader(
              title: '녹음 보관함',
              onBackPressed: () => context.pop(),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: coupleAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                error: (_, _) => const _LibraryMessage(
                  title: '녹음 보관함을 불러오지 못했어요.',
                ),
                data: (couple) => overviewAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
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
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent({
    required BuildContext context,
    required Couple? couple,
    required CoupleRecordingOverview? overview,
  }) {
    if (couple == null || overview == null) {
      return const _LibraryMessage(title: '보관함을 확인할 수 없어요.');
    }

    final canEdit = couple.canEditSharedData;
    final currentRecording = overview.currentRecording;
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final slotsByIndex = {
      for (final slot in overview.savedSlots) slot.slotIndex: slot,
    };

    return ListView(
      children: [
        _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('현재 녹음', style: AppTextStyles.homeBodyMedium),
              const SizedBox(height: 10),
              if (currentRecording == null)
                Text(
                  '아직 저장된 현재 녹음이 없어요.',
                  style: AppTextStyles.homeCharacterLabel.copyWith(
                    color: AppColors.textMuted,
                  ),
                )
              else
                _CurrentRecordingPreview(
                  recording: currentRecording,
                  isMine: currentRecording.senderUserId == currentUserId,
                  isPlaying:
                      _isPlaying && _activePlaybackKey == 'current-recording',
                  onPlayPressed: () => _togglePlayback(
                    key: 'current-recording',
                    url: currentRecording.audioUrl,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '열린 슬롯 ${overview.slotLimit}/10',
                      style: AppTextStyles.homeBodyMedium,
                    ),
                  ),
                  if (canEdit && overview.slotLimit < 10)
                    TextButton(
                      onPressed: _isProcessing ? null : _openNextSlot,
                      child: const Text('슬롯 추가'),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                canEdit
                    ? '현재 녹음을 선택한 슬롯에 저장하거나 교체할 수 있어요.'
                    : '보관 중인 저장 녹음은 재생만 할 수 있어요.',
                style: AppTextStyles.homeCharacterLabel.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 16),
              for (var index = 1; index <= overview.slotLimit; index++) ...[
                _RecordingSlotTile(
                  slotIndex: index,
                  slot: slotsByIndex[index],
                  currentRecording: currentRecording,
                  canEdit: canEdit,
                  isPlaying:
                      _isPlaying && _activePlaybackKey == 'slot-$index',
                  onPlayPressed: slotsByIndex[index] == null
                      ? null
                      : () => _togglePlayback(
                          key: 'slot-$index',
                          url: slotsByIndex[index]!.audioUrl,
                        ),
                  onSavePressed: currentRecording == null || _isProcessing
                      ? null
                      : () => _saveSlot(
                          slotIndex: index,
                          slot: slotsByIndex[index],
                        ),
                  onDeletePressed: slotsByIndex[index] == null || _isProcessing
                      ? null
                      : () => _deleteSlot(slotsByIndex[index]!),
                ),
                if (index < overview.slotLimit) const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _togglePlayback({
    required String key,
    required String url,
  }) async {
    if (_activePlaybackKey != key) {
      await _player.stop();
      await _player.setUrl(url);
      _activePlaybackKey = key;
    }

    if (_player.playing) {
      await _player.pause();
      return;
    }

    await _player.play();
  }

  Future<void> _openNextSlot() async {
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

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('새 슬롯을 열었어요.')));
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
          content: Text(
            slot == null ? '슬롯에 녹음을 저장했어요.' : '슬롯 녹음을 교체했어요.',
          ),
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
              decoration: const InputDecoration(
                hintText: '제목을 입력해 주세요.',
              ),
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

    controller.dispose();
    return result;
  }

  void _showError(Object error) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_messageForError(error))));
  }

  String _messageForError(Object error) {
    if (error is CoupleRecordingRepositoryException) {
      return switch (error.reason) {
        CoupleRecordingFailureReason.recordingSlotConflict =>
          '보관함이 다른 기기에서 변경됐어요. 화면을 새로고침한 뒤 다시 시도해 주세요.',
        CoupleRecordingFailureReason.recordingSlotLocked =>
          '아직 열리지 않은 슬롯이에요.',
        CoupleRecordingFailureReason.recordingSlotLimitReached =>
          '더 이상 열 수 있는 슬롯이 없어요.',
        CoupleRecordingFailureReason.currentRecordingRequired =>
          '먼저 현재 녹음을 남겨 주세요.',
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

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.wireframeBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
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
    this.onPlayPressed,
    this.onSavePressed,
    this.onDeletePressed,
  });

  final int slotIndex;
  final CoupleRecordingSlot? slot;
  final CurrentCoupleRecording? currentRecording;
  final bool canEdit;
  final bool isPlaying;
  final VoidCallback? onPlayPressed;
  final VoidCallback? onSavePressed;
  final VoidCallback? onDeletePressed;

  @override
  Widget build(BuildContext context) {
    final slot = this.slot;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.wireframeBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: slot == null
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
              onPlayPressed: onPlayPressed,
              onSavePressed: onSavePressed,
              onDeletePressed: onDeletePressed,
            ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('슬롯 $slotIndex', style: AppTextStyles.homeBody),
        const SizedBox(height: 4),
        Text(
          hasCurrentRecording
              ? '현재 녹음을 이 슬롯에 저장할 수 있어요.'
              : '현재 저장할 녹음이 없어요.',
          style: AppTextStyles.homeCharacterLabel.copyWith(
            color: AppColors.textMuted,
          ),
        ),
        if (canEdit) ...[
          const SizedBox(height: 12),
          AppActionButton(
            label: '현재 녹음 저장',
            enabled: hasCurrentRecording,
            onPressed: onSavePressed,
          ),
        ],
      ],
    );
  }
}

class _FilledSlotContent extends StatelessWidget {
  const _FilledSlotContent({
    required this.slot,
    required this.canEdit,
    required this.isPlaying,
    this.onPlayPressed,
    this.onSavePressed,
    this.onDeletePressed,
  });

  final CoupleRecordingSlot slot;
  final bool canEdit;
  final bool isPlaying;
  final VoidCallback? onPlayPressed;
  final VoidCallback? onSavePressed;
  final VoidCallback? onDeletePressed;

  @override
  Widget build(BuildContext context) {
    final isMine =
        slot.senderUserId == Supabase.instance.client.auth.currentUser?.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(slot.title, style: AppTextStyles.homeBodyMedium),
            ),
            SizedBox(
              width: 40,
              height: 40,
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
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '${isMine ? '내가 남김' : '상대가 남김'} · ${_formatRecordedAt(slot.recordedAt)} · ${_formatDuration(slot.duration)}',
          style: AppTextStyles.homeCharacterLabel.copyWith(
            color: AppColors.textMuted,
          ),
        ),
        if (canEdit) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppActionButton(
                  label: '현재 녹음으로 교체',
                  enabled: true,
                  onPressed: onSavePressed,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppActionButton(
                  label: '삭제',
                  enabled: true,
                  isSecondary: true,
                  onPressed: onDeletePressed,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _LibraryMessage extends StatelessWidget {
  const _LibraryMessage({
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
