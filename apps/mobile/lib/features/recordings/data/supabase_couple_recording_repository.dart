import 'dart:typed_data';

import 'couple_recording.dart';
import 'couple_recording_data_gateways.dart';
import 'couple_recording_repository_contract.dart';
import 'supabase_couple_recording_overview_reader.dart';
import 'supabase_couple_recording_slot_artwork_store.dart';
import 'supabase_couple_recording_slot_placement_store.dart';
import 'supabase_couple_recording_slot_writer.dart';
import 'supabase_current_couple_recording_writer.dart';

class SupabaseCoupleRecordingRepository implements CoupleRecordingRepository {
  const SupabaseCoupleRecordingRepository({
    CoupleRecordingOverviewReader overviewReader =
        const SupabaseCoupleRecordingOverviewReader(),
    CurrentCoupleRecordingWriter currentRecordingWriter =
        const SupabaseCurrentCoupleRecordingWriter(),
    CoupleRecordingSlotWriter slotWriter =
        const SupabaseCoupleRecordingSlotWriter(),
    CoupleRecordingSlotArtworkStore artworkStore =
        const SupabaseCoupleRecordingSlotArtworkStore(),
    CoupleRecordingSlotPlacementStore placementStore =
        const SupabaseCoupleRecordingSlotPlacementStore(),
  }) : _overviewReader = overviewReader,
       _currentRecordingWriter = currentRecordingWriter,
       _slotWriter = slotWriter,
       _artworkStore = artworkStore,
       _placementStore = placementStore;

  final CoupleRecordingOverviewReader _overviewReader;
  final CurrentCoupleRecordingWriter _currentRecordingWriter;
  final CoupleRecordingSlotWriter _slotWriter;
  final CoupleRecordingSlotArtworkStore _artworkStore;
  final CoupleRecordingSlotPlacementStore _placementStore;

  @override
  Future<CoupleRecordingOverview> fetchOverview() {
    return _overviewReader.fetchOverview();
  }

  @override
  Future<void> uploadCurrentRecording({
    required String coupleId,
    required Uint8List audioBytes,
    required int durationMs,
    String? recordingId,
    bool resumeExistingUpload = false,
  }) {
    return _currentRecordingWriter.uploadCurrentRecording(
      coupleId: coupleId,
      audioBytes: audioBytes,
      durationMs: durationMs,
      recordingId: recordingId,
      resumeExistingUpload: resumeExistingUpload,
    );
  }

  @override
  Future<CoupleRecordingSlotSaveResult> saveCurrentRecordingToSlot({
    required int slotIndex,
    required String title,
    required int? expectedSlotRevision,
  }) {
    return _slotWriter.saveCurrentRecordingToSlot(
      slotIndex: slotIndex,
      title: title,
      expectedSlotRevision: expectedSlotRevision,
    );
  }

  @override
  Future<void> deleteSlot({
    required String slotId,
    required int expectedSlotRevision,
  }) {
    return _slotWriter.deleteSlot(
      slotId: slotId,
      expectedSlotRevision: expectedSlotRevision,
    );
  }

  @override
  Future<void> openNextSlot() {
    return _slotWriter.openNextSlot();
  }

  @override
  Future<Uint8List> fetchSlotArtworkDrawingData({
    required String drawingDataPath,
  }) {
    return _artworkStore.fetchSlotArtworkDrawingData(
      drawingDataPath: drawingDataPath,
    );
  }

  @override
  Future<void> saveSlotArtwork({
    required String coupleId,
    required String slotId,
    required int expectedSlotRevision,
    required Uint8List previewBytes,
    required Uint8List drawingDataBytes,
  }) {
    return _artworkStore.saveSlotArtwork(
      coupleId: coupleId,
      slotId: slotId,
      expectedSlotRevision: expectedSlotRevision,
      previewBytes: previewBytes,
      drawingDataBytes: drawingDataBytes,
    );
  }

  @override
  Future<void> upsertSlotPlacement({
    required String slotId,
    required double normalizedX,
    required double normalizedY,
    required int? expectedPlacementRevision,
  }) {
    return _placementStore.upsertSlotPlacement(
      slotId: slotId,
      normalizedX: normalizedX,
      normalizedY: normalizedY,
      expectedPlacementRevision: expectedPlacementRevision,
    );
  }

  @override
  Future<void> deleteSlotPlacement({
    required String slotId,
    required int expectedPlacementRevision,
  }) {
    return _placementStore.deleteSlotPlacement(
      slotId: slotId,
      expectedPlacementRevision: expectedPlacementRevision,
    );
  }
}
