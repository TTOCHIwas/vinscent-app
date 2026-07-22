import 'dart:async';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../recording_debug_log.dart';
import 'couple_recording_data_gateways.dart';
import 'couple_recording_failure.dart';
import 'recording_id_generator.dart';
import 'recording_slot_artwork_path.dart';
import 'supabase_couple_recording_gateway_support.dart';

class SupabaseCoupleRecordingSlotArtworkStore
    implements CoupleRecordingSlotArtworkStore {
  const SupabaseCoupleRecordingSlotArtworkStore({
    SupabaseCoupleRecordingGatewaySupport support =
        const SupabaseCoupleRecordingGatewaySupport(),
  }) : _support = support;

  static const _maxArtworkObjectBytes = 256 * 1024;

  final SupabaseCoupleRecordingGatewaySupport _support;

  @override
  Future<Uint8List> fetchSlotArtworkDrawingData({
    required String drawingDataPath,
  }) async {
    _support.ensureConfigured();

    try {
      return await _support.artworkBucket
          .download(drawingDataPath)
          .timeout(AppConfig.supabaseRpcTimeout);
    } on TimeoutException {
      throw const CoupleRecordingRepositoryException(
        CoupleRecordingFailureReason.requestTimeout,
      );
    } on StorageException catch (error) {
      throw _support.mapStorageError(error);
    }
  }

  @override
  Future<void> saveSlotArtwork({
    required String coupleId,
    required String slotId,
    required int expectedSlotRevision,
    required Uint8List previewBytes,
    required Uint8List drawingDataBytes,
  }) async {
    _support.ensureConfigured();
    if (previewBytes.isEmpty ||
        drawingDataBytes.isEmpty ||
        previewBytes.length > _maxArtworkObjectBytes ||
        drawingDataBytes.length > _maxArtworkObjectBytes) {
      throw const CoupleRecordingRepositoryException(
        CoupleRecordingFailureReason.invalidRecordingArtwork,
      );
    }

    final artifactId = generateRecordingId();
    final paths = RecordingSlotArtworkPath(
      coupleId: coupleId,
      slotId: slotId,
      artifactId: artifactId,
    );
    var uploadAttempted = false;

    try {
      uploadAttempted = true;
      await _support.artworkBucket
          .uploadBinary(
            paths.previewPath,
            previewBytes,
            fileOptions: const FileOptions(
              upsert: false,
              contentType: 'image/webp',
              cacheControl: '31536000',
            ),
          )
          .timeout(AppConfig.supabaseRpcTimeout);
      await _support.artworkBucket
          .uploadBinary(
            paths.drawingDataPath,
            drawingDataBytes,
            fileOptions: const FileOptions(
              upsert: false,
              contentType: 'application/gzip',
              cacheControl: '31536000',
            ),
          )
          .timeout(AppConfig.supabaseRpcTimeout);
      await _support.client
          .rpc(
            'save_couple_recording_slot_artwork',
            params: {
              'requested_slot_id': slotId,
              'requested_artifact_id': artifactId,
              'expected_slot_revision': expectedSlotRevision,
            },
          )
          .timeout(AppConfig.supabaseRpcTimeout);
    } on TimeoutException {
      await _discardUploadedSlotArtwork(
        uploadAttempted: uploadAttempted,
        slotId: slotId,
        artifactId: artifactId,
      );
      throw const CoupleRecordingRepositoryException(
        CoupleRecordingFailureReason.requestTimeout,
      );
    } on PostgrestException catch (error) {
      await _discardUploadedSlotArtwork(
        uploadAttempted: uploadAttempted,
        slotId: slotId,
        artifactId: artifactId,
      );
      throw _support.mapPostgrestError(error);
    } on StorageException catch (error) {
      debugRecordingLog(
        'Slot artwork storage request failed: '
        'statusCode=${error.statusCode}, error=${error.error}, '
        'message=${error.message}',
      );
      await _discardUploadedSlotArtwork(
        uploadAttempted: uploadAttempted,
        slotId: slotId,
        artifactId: artifactId,
      );
      throw _support.mapStorageError(error);
    } catch (_) {
      await _discardUploadedSlotArtwork(
        uploadAttempted: uploadAttempted,
        slotId: slotId,
        artifactId: artifactId,
      );
      rethrow;
    }
  }

  Future<void> _discardUploadedSlotArtwork({
    required bool uploadAttempted,
    required String slotId,
    required String artifactId,
  }) async {
    if (!uploadAttempted) {
      return;
    }

    try {
      await _support.client
          .rpc(
            'discard_uploaded_couple_recording_slot_artwork',
            params: {
              'requested_slot_id': slotId,
              'requested_artifact_id': artifactId,
            },
          )
          .timeout(AppConfig.supabaseRpcTimeout);
    } catch (error) {
      debugRecordingLog('Slot artwork cleanup failed: $error');
    }
  }
}
