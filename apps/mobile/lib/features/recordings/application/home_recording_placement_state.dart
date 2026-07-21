import 'dart:ui';

import '../data/couple_recording.dart';
import 'home_recording_placement_geometry.dart';

class HomeRecordingPlacementState {
  HomeRecordingPlacementState._({
    required Map<String, Offset> pendingPositions,
    required Map<String, int> pendingBaseRevisions,
    required Set<String> hiddenSlotIds,
    required this.pendingNewSlotId,
    required this.isPlacementSessionRunning,
  }) : pendingPositions = Map.unmodifiable(pendingPositions),
       pendingBaseRevisions = Map.unmodifiable(pendingBaseRevisions),
       hiddenSlotIds = Set.unmodifiable(hiddenSlotIds);

  factory HomeRecordingPlacementState.initial() {
    return HomeRecordingPlacementState._(
      pendingPositions: const {},
      pendingBaseRevisions: const {},
      hiddenSlotIds: const {},
      pendingNewSlotId: null,
      isPlacementSessionRunning: false,
    );
  }

  final Map<String, Offset> pendingPositions;
  final Map<String, int> pendingBaseRevisions;
  final Set<String> hiddenSlotIds;
  final String? pendingNewSlotId;
  final bool isPlacementSessionRunning;

  Offset? pendingPositionFor(String slotId) => pendingPositions[slotId];

  bool isHidden(String slotId) => hiddenSlotIds.contains(slotId);

  List<CoupleRecordingSlot> displayedSlots(CoupleRecordingOverview overview) {
    final slots = [...overview.placedSlots];
    final pendingId = pendingNewSlotId;
    if (pendingId == null || slots.any((slot) => slot.slotId == pendingId)) {
      return List.unmodifiable(slots);
    }

    final pendingSlot = overview.savedSlots
        .where((slot) => slot.slotId == pendingId)
        .firstOrNull;
    if (pendingSlot != null) {
      slots.add(pendingSlot);
    }
    return List.unmodifiable(slots);
  }

  Offset? positionFor(
    CoupleRecordingSlot slot,
    HomeRecordingPlacementGeometry geometry,
  ) {
    final pendingPosition = pendingPositions[slot.slotId];
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

  HomeRecordingPlacementState synchronize(CoupleRecordingOverview overview) {
    final slotsById = {
      for (final slot in overview.savedSlots) slot.slotId: slot,
    };
    final nextPositions = Map<String, Offset>.of(pendingPositions)
      ..removeWhere((slotId, _) {
        final slot = slotsById[slotId];
        if (slot == null) {
          return true;
        }
        if (slot.placement == null) {
          return pendingNewSlotId != slotId;
        }
        final baseRevision = pendingBaseRevisions[slotId];
        return baseRevision != null && slot.placement!.revision != baseRevision;
      });
    final nextRevisions = Map<String, int>.of(pendingBaseRevisions)
      ..removeWhere((slotId, _) => !nextPositions.containsKey(slotId));
    final nextHiddenSlotIds = Set<String>.of(hiddenSlotIds)
      ..removeWhere((slotId) => slotsById[slotId]?.placement == null);

    return _copyWith(
      pendingPositions: nextPositions,
      pendingBaseRevisions: nextRevisions,
      hiddenSlotIds: nextHiddenSlotIds,
    );
  }

  HomeRecordingPlacementState startSession() {
    return _copyWith(isPlacementSessionRunning: true);
  }

  HomeRecordingPlacementState endSession() {
    return _copyWith(isPlacementSessionRunning: false);
  }

  HomeRecordingPlacementState beginNewPlacement({
    required String slotId,
    required Offset position,
  }) {
    return _copyWith(
      pendingPositions: {...pendingPositions, slotId: position},
      pendingNewSlotId: slotId,
    );
  }

  HomeRecordingPlacementState completeNewPlacement(String slotId) {
    return _copyWith(
      pendingPositions: Map<String, Offset>.of(pendingPositions)
        ..remove(slotId),
      pendingBaseRevisions: Map<String, int>.of(pendingBaseRevisions)
        ..remove(slotId),
      pendingNewSlotId: pendingNewSlotId == slotId ? null : pendingNewSlotId,
    );
  }

  HomeRecordingPlacementState beginMove({
    required String slotId,
    required Offset position,
    required int baseRevision,
  }) {
    return _copyWith(
      pendingPositions: {...pendingPositions, slotId: position},
      pendingBaseRevisions: {...pendingBaseRevisions, slotId: baseRevision},
    );
  }

  HomeRecordingPlacementState completeMove(String slotId) {
    return _copyWith(
      pendingPositions: Map<String, Offset>.of(pendingPositions)
        ..remove(slotId),
      pendingBaseRevisions: Map<String, int>.of(pendingBaseRevisions)
        ..remove(slotId),
    );
  }

  HomeRecordingPlacementState beginDelete(String slotId) {
    return _copyWith(hiddenSlotIds: {...hiddenSlotIds, slotId});
  }

  HomeRecordingPlacementState completeDelete(String slotId) {
    return _copyWith(
      hiddenSlotIds: Set<String>.of(hiddenSlotIds)..remove(slotId),
    );
  }

  HomeRecordingPlacementState _copyWith({
    Map<String, Offset>? pendingPositions,
    Map<String, int>? pendingBaseRevisions,
    Set<String>? hiddenSlotIds,
    Object? pendingNewSlotId = _notProvided,
    bool? isPlacementSessionRunning,
  }) {
    return HomeRecordingPlacementState._(
      pendingPositions: pendingPositions ?? this.pendingPositions,
      pendingBaseRevisions: pendingBaseRevisions ?? this.pendingBaseRevisions,
      hiddenSlotIds: hiddenSlotIds ?? this.hiddenSlotIds,
      pendingNewSlotId: identical(pendingNewSlotId, _notProvided)
          ? this.pendingNewSlotId
          : pendingNewSlotId as String?,
      isPlacementSessionRunning:
          isPlacementSessionRunning ?? this.isPlacementSessionRunning,
    );
  }
}

const _notProvided = Object();
