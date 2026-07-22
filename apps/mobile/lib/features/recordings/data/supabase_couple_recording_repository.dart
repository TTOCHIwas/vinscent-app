import 'dart:async';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import 'couple_recording.dart';
import 'couple_recording_data_gateways.dart';
import 'couple_recording_failure.dart';
import 'couple_recording_repository_contract.dart';
import 'supabase_couple_recording_overview_reader.dart';
import 'supabase_couple_recording_slot_artwork_store.dart';
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
        const _SupabaseCoupleRecordingDataGateway(),
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

class _SupabaseCoupleRecordingDataGateway
    implements CoupleRecordingSlotPlacementStore {
  const _SupabaseCoupleRecordingDataGateway();

  @override
  Future<void> upsertSlotPlacement({
    required String slotId,
    required double normalizedX,
    required double normalizedY,
    required int? expectedPlacementRevision,
  }) async {
    _ensureSupabaseConfigured();

    try {
      await Supabase.instance.client
          .rpc(
            'upsert_couple_recording_slot_placement',
            params: {
              'requested_slot_id': slotId,
              'requested_normalized_x': normalizedX,
              'requested_normalized_y': normalizedY,
              'expected_placement_revision': expectedPlacementRevision,
            },
          )
          .timeout(AppConfig.supabaseRpcTimeout);
    } on TimeoutException {
      throw const CoupleRecordingRepositoryException(
        CoupleRecordingFailureReason.requestTimeout,
      );
    } on PostgrestException catch (error) {
      throw _mapPostgrestError(error);
    }
  }

  @override
  Future<void> deleteSlotPlacement({
    required String slotId,
    required int expectedPlacementRevision,
  }) async {
    _ensureSupabaseConfigured();

    try {
      await Supabase.instance.client
          .rpc(
            'delete_couple_recording_slot_placement',
            params: {
              'requested_slot_id': slotId,
              'expected_placement_revision': expectedPlacementRevision,
            },
          )
          .timeout(AppConfig.supabaseRpcTimeout);
    } on TimeoutException {
      throw const CoupleRecordingRepositoryException(
        CoupleRecordingFailureReason.requestTimeout,
      );
    } on PostgrestException catch (error) {
      throw _mapPostgrestError(error);
    }
  }

  void _ensureSupabaseConfigured() {
    if (!AppConfig.isSupabaseConfigured) {
      throw const CoupleRecordingRepositoryException(
        CoupleRecordingFailureReason.configMissing,
      );
    }
  }

  CoupleRecordingRepositoryException _mapPostgrestError(
    PostgrestException error,
  ) {
    return CoupleRecordingRepositoryException(
      _reasonFromMessage(error.message),
      error.message,
    );
  }

  CoupleRecordingFailureReason _reasonFromMessage(String message) {
    return switch (message) {
      'auth_required' => CoupleRecordingFailureReason.authRequired,
      'active_couple_required' =>
        CoupleRecordingFailureReason.activeCoupleRequired,
      'readable_couple_required' =>
        CoupleRecordingFailureReason.readableCoupleRequired,
      'invalid_recording_id' => CoupleRecordingFailureReason.invalidRecordingId,
      'invalid_recording_duration' =>
        CoupleRecordingFailureReason.invalidRecordingDuration,
      'invalid_recording_path' =>
        CoupleRecordingFailureReason.invalidRecordingPath,
      'recording_file_missing' =>
        CoupleRecordingFailureReason.recordingFileMissing,
      'current_recording_required' =>
        CoupleRecordingFailureReason.currentRecordingRequired,
      'invalid_recording_slot' =>
        CoupleRecordingFailureReason.invalidRecordingSlot,
      'invalid_recording_slot_index' =>
        CoupleRecordingFailureReason.invalidRecordingSlotIndex,
      'invalid_recording_slot_title' =>
        CoupleRecordingFailureReason.invalidRecordingSlotTitle,
      'recording_slot_locked' =>
        CoupleRecordingFailureReason.recordingSlotLocked,
      'recording_slot_conflict' =>
        CoupleRecordingFailureReason.recordingSlotConflict,
      'recording_slot_limit_reached' =>
        CoupleRecordingFailureReason.recordingSlotLimitReached,
      'invalid_recording_artwork' =>
        CoupleRecordingFailureReason.invalidRecordingArtwork,
      'recording_artwork_file_missing' =>
        CoupleRecordingFailureReason.recordingArtworkFileMissing,
      'recording_artwork_required' =>
        CoupleRecordingFailureReason.recordingArtworkRequired,
      'invalid_recording_placement' =>
        CoupleRecordingFailureReason.invalidRecordingPlacement,
      'recording_placement_conflict' =>
        CoupleRecordingFailureReason.recordingPlacementConflict,
      'recording_placement_limit_reached' =>
        CoupleRecordingFailureReason.recordingPlacementLimitReached,
      _ => CoupleRecordingFailureReason.unknown,
    };
  }
}
