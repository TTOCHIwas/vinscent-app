import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../couple/application/couple_controller.dart';
import '../../../couple/data/couple.dart';
import '../../application/couple_recording_overview_controller.dart';
import '../../application/home_recording_placement_geometry.dart';
import '../../application/recording_playback_controller.dart';
import '../../application/recording_slot_placement_session.dart';
import '../../data/couple_recording.dart';
import '../../data/couple_recording_failure.dart';
import 'home_recording_artwork_item.dart';

class HomeRecordingArtworkLayer extends ConsumerStatefulWidget {
  const HomeRecordingArtworkLayer({super.key});

  @override
  ConsumerState<HomeRecordingArtworkLayer> createState() =>
      _HomeRecordingArtworkLayerState();
}

class _HomeRecordingArtworkLayerState
    extends ConsumerState<HomeRecordingArtworkLayer> {
  final Map<String, Offset> _pendingPositions = {};
  final Map<String, int> _pendingBaseRevisions = {};
  final Map<String, int> _pulseTokens = {};
  final Set<String> _hiddenSlotIds = {};
  final Set<String> _busySlotIds = {};
  String? _frontSlotId;
  String? _draggingSlotId;
  Offset? _dragPosition;
  bool _isOverTrash = false;
  bool _isPlacementSessionRunning = false;
  String? _pendingNewSlotId;

  @override
  Widget build(BuildContext context) {
    final overviewAsync = ref.watch(coupleRecordingOverviewControllerProvider);
    final coupleAsync = ref.watch(coupleControllerProvider);
    final placementSessionSlotId = ref.watch(
      recordingSlotPlacementSessionProvider,
    );
    final playbackState = ref.watch(
      recordingPlaybackControllerProvider(RecordingPlaybackSurface.home),
    );
    final overview = switch (overviewAsync) {
      AsyncData<CoupleRecordingOverview?>(:final value) => value,
      _ => null,
    };
    final canEdit = switch (coupleAsync) {
      AsyncData<Couple?>(:final value) => value?.canEditSharedData ?? false,
      _ => false,
    };
    if (overview == null) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final canvasSize = constraints.biggest;
        if (canvasSize.isEmpty || !canvasSize.isFinite) {
          return const SizedBox.shrink();
        }

        final itemSize = _itemSizeFor(canvasSize.width);
        final geometry = HomeRecordingPlacementGeometry(
          canvasSize: canvasSize,
          itemSize: itemSize,
          forbiddenRects: const [],
        );
        _synchronizePendingPositions(overview);

        final slotsById = {
          for (final slot in overview.savedSlots) slot.slotId: slot,
        };
        _schedulePlacementSession(
          slotId: placementSessionSlotId,
          slot: placementSessionSlotId == null
              ? null
              : slotsById[placementSessionSlotId],
          geometry: geometry,
          overview: overview,
          canEdit: canEdit,
        );

        final displayedSlots = _bringFront(<CoupleRecordingSlot>[
          ...overview.placedSlots,
          if (_pendingNewSlotId case final pendingId?)
            if (slotsById[pendingId] case final pendingSlot?)
              if (!overview.placedSlots.any(
                (slot) => slot.slotId == pendingSlot.slotId,
              ))
                pendingSlot,
        ]);
        final trashRect = _trashRect(canvasSize);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            for (final slot in displayedSlots)
              if (!_hiddenSlotIds.contains(slot.slotId))
                if (_positionFor(slot, geometry) case final position?)
                  Positioned(
                    key: ValueKey(
                      'home-recording-artwork-positioned-${slot.slotId}',
                    ),
                    left: position.dx - itemSize / 2,
                    top: position.dy - itemSize / 2,
                    width: itemSize,
                    height: itemSize,
                    child: HomeRecordingArtworkItem(
                      slot: slot,
                      size: itemSize,
                      isBusy: _busySlotIds.contains(slot.slotId),
                      isDragging: _draggingSlotId == slot.slotId,
                      pulseToken: _pulseTokens[slot.slotId],
                      isPlaying:
                          playbackState.isPlaying &&
                          playbackState.activeTargetKey ==
                              RecordingPlaybackTarget.homeSlot(slot).key,
                      onTap: () => _togglePlayback(slot),
                      onLongPress: canEdit
                          ? () => _replaceSlotRecording(slot, overview)
                          : null,
                      onPanStart: canEdit
                          ? (_) => _startDrag(slot, position)
                          : null,
                      onPanUpdate: canEdit
                          ? (details) => _updateDrag(
                              slot: slot,
                              delta: details.delta,
                              canvasSize: canvasSize,
                              itemSize: itemSize,
                              trashRect: trashRect,
                            )
                          : null,
                      onPanEnd: canEdit
                          ? (_) => _finishDrag(slot, geometry)
                          : null,
                      onPanCancel: canEdit ? _cancelDrag : null,
                    ),
                  ),
            if (_draggingSlotId != null)
              Positioned.fromRect(
                rect: trashRect,
                child: _HomeRecordingArtworkTrashTarget(isActive: _isOverTrash),
              ),
          ],
        );
      },
    );
  }

  double _itemSizeFor(double canvasWidth) {
    final minimumSize = canvasWidth < 72 ? canvasWidth : 72.0;
    final maximumSize = canvasWidth < 104 ? canvasWidth : 104.0;
    return (canvasWidth * 0.24).clamp(minimumSize, maximumSize);
  }

  List<CoupleRecordingSlot> _bringFront(List<CoupleRecordingSlot> slots) {
    final frontSlotId = _frontSlotId;
    if (frontSlotId == null) {
      return slots;
    }
    final index = slots.indexWhere((slot) => slot.slotId == frontSlotId);
    if (index < 0 || index == slots.length - 1) {
      return slots;
    }
    final frontSlot = slots.removeAt(index);
    return [...slots, frontSlot];
  }

  void _synchronizePendingPositions(CoupleRecordingOverview overview) {
    final slotsById = {
      for (final slot in overview.savedSlots) slot.slotId: slot,
    };
    _pendingPositions.removeWhere((slotId, _) {
      final slot = slotsById[slotId];
      if (slot == null) {
        return true;
      }
      if (slot.placement == null) {
        return _pendingNewSlotId != slotId;
      }
      final baseRevision = _pendingBaseRevisions[slotId];
      return baseRevision != null && slot.placement!.revision != baseRevision;
    });
    _pendingBaseRevisions.removeWhere(
      (slotId, _) => !_pendingPositions.containsKey(slotId),
    );
    _hiddenSlotIds.removeWhere(
      (slotId) => slotsById[slotId]?.placement == null,
    );
  }

  Offset? _positionFor(
    CoupleRecordingSlot slot,
    HomeRecordingPlacementGeometry geometry,
  ) {
    if (_draggingSlotId == slot.slotId) {
      return _dragPosition;
    }
    final pendingPosition = _pendingPositions[slot.slotId];
    if (pendingPosition != null) {
      return pendingPosition;
    }
    final placement = slot.placement;
    if (placement == null) {
      return null;
    }
    return geometry.resolve(
      geometry.denormalize(
        Offset(placement.normalizedX, placement.normalizedY),
      ),
    );
  }

  void _schedulePlacementSession({
    required String? slotId,
    required CoupleRecordingSlot? slot,
    required HomeRecordingPlacementGeometry geometry,
    required CoupleRecordingOverview overview,
    required bool canEdit,
  }) {
    if (slotId == null || _isPlacementSessionRunning) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isPlacementSessionRunning) {
        return;
      }
      if (!canEdit) {
        ref.read(recordingSlotPlacementSessionProvider.notifier).clear();
        return;
      }
      if (slot == null || slot.artwork == null) {
        ref.read(recordingSlotPlacementSessionProvider.notifier).clear();
        _showMessage('배치할 슬롯 그림을 찾지 못했어요.');
        return;
      }
      if (slot.placement != null) {
        ref.read(recordingSlotPlacementSessionProvider.notifier).consume();
        _pulse(slot.slotId);
        return;
      }

      unawaited(_placeNewSlot(slot, overview, geometry));
    });
  }

  Future<void> _placeNewSlot(
    CoupleRecordingSlot slot,
    CoupleRecordingOverview overview,
    HomeRecordingPlacementGeometry geometry,
  ) async {
    _isPlacementSessionRunning = true;
    ref.read(recordingSlotPlacementSessionProvider.notifier).consume();
    final occupied = overview.placedSlots
        .map((placedSlot) => _positionFor(placedSlot, geometry))
        .whereType<Offset>();
    final defaultPosition = geometry.findDefaultPosition(occupied: occupied);
    if (defaultPosition == null) {
      _isPlacementSessionRunning = false;
      _showMessage('이 화면 크기에서는 그림을 둘 공간이 부족해요.');
      return;
    }

    setState(() {
      _pendingNewSlotId = slot.slotId;
      _pendingPositions[slot.slotId] = defaultPosition;
      _busySlotIds.add(slot.slotId);
    });

    try {
      final normalized = geometry.normalize(defaultPosition);
      await ref
          .read(coupleRecordingOverviewControllerProvider.notifier)
          .upsertSlotPlacement(
            slotId: slot.slotId,
            normalizedX: normalized.dx,
            normalizedY: normalized.dy,
            expectedPlacementRevision: null,
          );
      if (mounted) {
        _pulse(slot.slotId);
      }
    } catch (error) {
      _showMessage(_messageForError(error));
    } finally {
      _isPlacementSessionRunning = false;
      if (mounted) {
        setState(() {
          _pendingNewSlotId = null;
          _pendingPositions.remove(slot.slotId);
          _busySlotIds.remove(slot.slotId);
        });
      }
    }
  }

  void _startDrag(CoupleRecordingSlot slot, Offset position) {
    if (_busySlotIds.contains(slot.slotId) || slot.placement == null) {
      return;
    }
    setState(() {
      _frontSlotId = slot.slotId;
      _draggingSlotId = slot.slotId;
      _dragPosition = position;
      _isOverTrash = false;
    });
  }

  void _updateDrag({
    required CoupleRecordingSlot slot,
    required Offset delta,
    required Size canvasSize,
    required double itemSize,
    required Rect trashRect,
  }) {
    if (_draggingSlotId != slot.slotId || _dragPosition == null) {
      return;
    }

    final halfItem = itemSize / 2;
    final next = _dragPosition! + delta;
    final clamped = Offset(
      next.dx.clamp(halfItem, canvasSize.width - halfItem),
      next.dy.clamp(halfItem, canvasSize.height - halfItem),
    );
    setState(() {
      _dragPosition = clamped;
      _isOverTrash = trashRect.inflate(12).contains(clamped);
    });
  }

  void _finishDrag(
    CoupleRecordingSlot slot,
    HomeRecordingPlacementGeometry geometry,
  ) {
    if (_draggingSlotId != slot.slotId) {
      return;
    }
    final dragPosition = _dragPosition;
    final shouldDelete = _isOverTrash;
    setState(() {
      _draggingSlotId = null;
      _dragPosition = null;
      _isOverTrash = false;
    });

    if (shouldDelete) {
      unawaited(_deletePlacement(slot));
      return;
    }
    if (dragPosition == null) {
      setState(() {
        _frontSlotId = null;
      });
      return;
    }
    final resolved = geometry.resolve(dragPosition);
    if (resolved == null) {
      setState(() {
        _frontSlotId = null;
      });
      _showMessage('그림을 둘 수 있는 위치에 놓아 주세요.');
      return;
    }
    unawaited(_persistPosition(slot, resolved, geometry));
  }

  void _cancelDrag() {
    if (_draggingSlotId == null) {
      return;
    }
    setState(() {
      _frontSlotId = null;
      _draggingSlotId = null;
      _dragPosition = null;
      _isOverTrash = false;
    });
  }

  Future<void> _persistPosition(
    CoupleRecordingSlot slot,
    Offset position,
    HomeRecordingPlacementGeometry geometry,
  ) async {
    final placement = slot.placement;
    if (placement == null) {
      return;
    }

    setState(() {
      _pendingPositions[slot.slotId] = position;
      _pendingBaseRevisions[slot.slotId] = placement.revision;
      _busySlotIds.add(slot.slotId);
    });
    try {
      final normalized = geometry.normalize(position);
      await ref
          .read(coupleRecordingOverviewControllerProvider.notifier)
          .upsertSlotPlacement(
            slotId: slot.slotId,
            normalizedX: normalized.dx,
            normalizedY: normalized.dy,
            expectedPlacementRevision: placement.revision,
          );
    } catch (error) {
      _showMessage(_messageForError(error));
    } finally {
      if (mounted) {
        setState(() {
          _frontSlotId = null;
          _pendingPositions.remove(slot.slotId);
          _pendingBaseRevisions.remove(slot.slotId);
          _busySlotIds.remove(slot.slotId);
        });
      }
    }
  }

  Future<void> _deletePlacement(CoupleRecordingSlot slot) async {
    final placement = slot.placement;
    if (placement == null) {
      return;
    }

    setState(() {
      if (_frontSlotId == slot.slotId) {
        _frontSlotId = null;
      }
      _hiddenSlotIds.add(slot.slotId);
      _busySlotIds.add(slot.slotId);
    });
    unawaited(HapticFeedback.mediumImpact());
    try {
      await ref
          .read(coupleRecordingOverviewControllerProvider.notifier)
          .deleteSlotPlacement(
            slotId: slot.slotId,
            expectedPlacementRevision: placement.revision,
          );
    } catch (error) {
      _showMessage(_messageForError(error));
    } finally {
      if (mounted) {
        setState(() {
          _hiddenSlotIds.remove(slot.slotId);
          _busySlotIds.remove(slot.slotId);
        });
      }
    }
  }

  Future<void> _replaceSlotRecording(
    CoupleRecordingSlot slot,
    CoupleRecordingOverview overview,
  ) async {
    if (_busySlotIds.contains(slot.slotId)) {
      return;
    }
    final currentRecording = overview.currentRecording;
    if (currentRecording == null) {
      _showMessage('먼저 캐릭터를 길게 눌러 현재 녹음을 남겨 주세요.');
      return;
    }
    if (currentRecording.recordingId == slot.recordingId) {
      _showMessage('이미 현재 녹음이 담긴 슬롯이에요.');
      return;
    }

    setState(() {
      _busySlotIds.add(slot.slotId);
    });
    unawaited(HapticFeedback.mediumImpact());
    try {
      try {
        await ref
            .read(
              recordingPlaybackControllerProvider(
                RecordingPlaybackSurface.home,
              ).notifier,
            )
            .reset();
      } catch (_) {}
      await ref
          .read(coupleRecordingOverviewControllerProvider.notifier)
          .saveCurrentRecordingToSlot(
            slotIndex: slot.slotIndex,
            title: slot.title,
            expectedSlotRevision: slot.slotRevision,
          );
      _showMessage('현재 녹음으로 교체했어요.');
    } catch (error) {
      _showMessage(_messageForError(error));
    } finally {
      if (mounted) {
        setState(() {
          _busySlotIds.remove(slot.slotId);
        });
      }
    }
  }

  Future<void> _togglePlayback(CoupleRecordingSlot slot) async {
    if (_busySlotIds.contains(slot.slotId)) {
      return;
    }
    try {
      await ref
          .read(
            recordingPlaybackControllerProvider(
              RecordingPlaybackSurface.home,
            ).notifier,
          )
          .toggle(RecordingPlaybackTarget.homeSlot(slot));
    } catch (_) {
      _showMessage('녹음을 재생하지 못했어요.');
    }
  }

  void _pulse(String slotId) {
    if (!mounted) {
      return;
    }
    setState(() {
      _pulseTokens[slotId] = (_pulseTokens[slotId] ?? 0) + 1;
      _frontSlotId = slotId;
    });
  }

  Rect _trashRect(Size canvasSize) {
    return Rect.fromCenter(
      center: Offset(canvasSize.width / 2, canvasSize.height - 42),
      width: 64,
      height: 64,
    );
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _messageForError(Object error) {
    if (error is CoupleRecordingRepositoryException) {
      return switch (error.reason) {
        CoupleRecordingFailureReason.recordingPlacementConflict ||
        CoupleRecordingFailureReason.recordingSlotConflict =>
          '다른 기기에서 변경됐어요. 다시 시도해 주세요.',
        CoupleRecordingFailureReason.recordingPlacementLimitReached =>
          '홈에는 슬롯 그림을 최대 4개까지 둘 수 있어요.',
        CoupleRecordingFailureReason.recordingArtworkRequired =>
          '먼저 슬롯 그림을 만들어 주세요.',
        CoupleRecordingFailureReason.currentRecordingRequired =>
          '먼저 현재 녹음을 남겨 주세요.',
        CoupleRecordingFailureReason.requestTimeout =>
          '요청 시간이 초과됐어요. 다시 시도해 주세요.',
        _ => '슬롯 그림을 업데이트하지 못했어요.',
      };
    }
    return '슬롯 그림을 업데이트하지 못했어요.';
  }
}

class _HomeRecordingArtworkTrashTarget extends StatelessWidget {
  const _HomeRecordingArtworkTrashTarget({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      key: const ValueKey('home-recording-artwork-trash-target'),
      dimension: 64,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive ? const Color(0xE6000000) : const Color(0xB8000000),
          border: Border.all(
            color: isActive ? AppColors.actionPrimary : Colors.white54,
          ),
        ),
        child: Icon(
          Icons.delete_outline,
          key: const ValueKey('home-recording-artwork-trash-icon'),
          color: isActive ? AppColors.actionPrimary : Colors.white,
          size: isActive ? 34 : 30,
        ),
      ),
    );
  }
}
