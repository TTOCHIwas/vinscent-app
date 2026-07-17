import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/recordings/data/couple_recording.dart';

void main() {
  test('slot artwork and home placement remain independent', () {
    const artwork = CoupleRecordingSlotArtwork(
      previewPath: 'couple/slots/slot/artworks/artifact/preview.webp',
      previewUrl: 'https://example.com/preview.webp',
      drawingDataPath: 'couple/slots/slot/artworks/artifact/drawing.json.gz',
      revision: 2,
    );
    const placement = CoupleRecordingSlotPlacement(
      normalizedX: 0.25,
      normalizedY: 0.75,
      revision: 3,
    );

    expect(artwork.revision, 2);
    expect(placement.revision, 3);
    expect(placement.normalizedX, inInclusiveRange(0, 1));
    expect(placement.normalizedY, inInclusiveRange(0, 1));
  });

  test('overview exposes only slots placed on home', () {
    final placedSlot = _slot(
      slotId: 'placed',
      placement: const CoupleRecordingSlotPlacement(
        normalizedX: 0.2,
        normalizedY: 0.6,
        revision: 1,
      ),
    );
    final libraryOnlySlot = _slot(slotId: 'library-only');
    final overview = CoupleRecordingOverview(
      slotLimit: 2,
      currentRecording: null,
      savedSlots: [placedSlot, libraryOnlySlot],
    );

    expect(overview.placedSlots, [placedSlot]);
  });
}

CoupleRecordingSlot _slot({
  required String slotId,
  CoupleRecordingSlotPlacement? placement,
}) {
  final timestamp = DateTime.utc(2026, 7, 18);
  return CoupleRecordingSlot(
    slotId: slotId,
    slotIndex: 1,
    title: 'slot',
    recordingId: 'recording',
    senderUserId: 'sender',
    durationMs: 1000,
    recordedAt: timestamp,
    slotRevision: 1,
    createdByUserId: 'creator',
    updatedByUserId: 'updater',
    createdAt: timestamp,
    updatedAt: timestamp,
    audioUrl: 'https://example.com/audio.m4a',
    artwork: const CoupleRecordingSlotArtwork(
      previewPath: 'couple/slots/slot/artworks/artifact/preview.webp',
      previewUrl: 'https://example.com/preview.webp',
      drawingDataPath: 'couple/slots/slot/artworks/artifact/drawing.json.gz',
      revision: 1,
    ),
    placement: placement,
  );
}
