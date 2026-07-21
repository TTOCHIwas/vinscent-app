import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/recordings/application/home_recording_placement_geometry.dart';
import 'package:vinscent/features/recordings/application/home_recording_placement_state.dart';
import 'package:vinscent/features/recordings/data/couple_recording.dart';

void main() {
  final geometry = HomeRecordingPlacementGeometry(
    canvasSize: const Size(300, 500),
    itemSize: 80,
    forbiddenRects: const [],
  );

  test('keeps a new unpersisted placement visible at its pending position', () {
    final overview = _overview(_slot(placement: null));
    const position = Offset(150, 250);

    final state = HomeRecordingPlacementState.initial().beginNewPlacement(
      slotId: 'slot-1',
      position: position,
    );
    final synchronized = state.synchronize(overview);

    expect(synchronized.displayedSlots(overview), hasLength(1));
    expect(
      synchronized.positionFor(overview.savedSlots.single, geometry),
      position,
    );
  });

  test('clears a pending move when the server placement revision changes', () {
    final moving = HomeRecordingPlacementState.initial().beginMove(
      slotId: 'slot-1',
      position: const Offset(100, 120),
      baseRevision: 2,
    );
    final refreshed = _overview(
      _slot(
        placement: const CoupleRecordingSlotPlacement(
          normalizedX: 0.8,
          normalizedY: 0.7,
          revision: 3,
        ),
      ),
    );

    final synchronized = moving.synchronize(refreshed);

    expect(synchronized.pendingPositionFor('slot-1'), isNull);
    expect(
      synchronized.positionFor(refreshed.savedSlots.single, geometry),
      const Offset(240, 350),
    );
  });

  test('keeps deletion hidden until the server removes the placement', () {
    final placed = _overview(
      _slot(
        placement: const CoupleRecordingSlotPlacement(
          normalizedX: 0.5,
          normalizedY: 0.5,
          revision: 1,
        ),
      ),
    );
    final deleting = HomeRecordingPlacementState.initial().beginDelete(
      'slot-1',
    );

    expect(deleting.synchronize(placed).isHidden('slot-1'), isTrue);

    final removed = _overview(_slot(placement: null));
    expect(deleting.synchronize(removed).isHidden('slot-1'), isFalse);
  });

  test('tracks the placement-session lifetime independently', () {
    final running = HomeRecordingPlacementState.initial().startSession();

    expect(running.isPlacementSessionRunning, isTrue);
    expect(running.endSession().isPlacementSessionRunning, isFalse);
  });
}

CoupleRecordingOverview _overview(CoupleRecordingSlot slot) {
  return CoupleRecordingOverview(
    slotLimit: 4,
    currentRecording: null,
    savedSlots: [slot],
  );
}

CoupleRecordingSlot _slot({required CoupleRecordingSlotPlacement? placement}) {
  final now = DateTime(2026, 7, 22);
  return CoupleRecordingSlot(
    slotId: 'slot-1',
    slotIndex: 1,
    title: '첫 녹음',
    recordingId: 'recording-1',
    senderUserId: 'user-1',
    durationMs: 1000,
    recordedAt: now,
    slotRevision: 1,
    createdByUserId: 'user-1',
    updatedByUserId: 'user-1',
    createdAt: now,
    updatedAt: now,
    audioUrl: 'https://example.com/recording.m4a',
    artwork: const CoupleRecordingSlotArtwork(
      previewPath: 'preview.webp',
      previewUrl: 'https://example.com/preview.webp',
      drawingDataPath: 'drawing.json.gz',
      revision: 1,
    ),
    placement: placement,
  );
}
