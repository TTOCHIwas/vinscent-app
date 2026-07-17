import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../recording_debug_log.dart';
import 'couple_recording.dart';
import 'couple_recording_failure.dart';
import 'recording_id_generator.dart';
import 'recording_slot_artwork_path.dart';
import 'recording_upload_failure_policy.dart';

final coupleRecordingRepositoryProvider = Provider<CoupleRecordingRepository>((
  ref,
) {
  return const SupabaseCoupleRecordingRepository();
});

abstract interface class CoupleRecordingRepository {
  Future<CoupleRecordingOverview> fetchOverview();

  Future<void> uploadCurrentRecording({
    required String coupleId,
    required Uint8List audioBytes,
    required int durationMs,
  });

  Future<void> saveCurrentRecordingToSlot({
    required int slotIndex,
    required String title,
    required int? expectedSlotRevision,
  });

  Future<void> deleteSlot({
    required String slotId,
    required int expectedSlotRevision,
  });

  Future<void> openNextSlot();

  Future<Uint8List> fetchSlotArtworkDrawingData({
    required String drawingDataPath,
  });

  Future<void> saveSlotArtwork({
    required String coupleId,
    required String slotId,
    required int expectedSlotRevision,
    required Uint8List previewBytes,
    required Uint8List drawingDataBytes,
  });

  Future<void> upsertSlotPlacement({
    required String slotId,
    required double normalizedX,
    required double normalizedY,
    required int? expectedPlacementRevision,
  });

  Future<void> deleteSlotPlacement({
    required String slotId,
    required int expectedPlacementRevision,
  });
}

class SupabaseCoupleRecordingRepository implements CoupleRecordingRepository {
  const SupabaseCoupleRecordingRepository();

  static const _bucketId = 'couple-recordings';
  static const _signedUrlExpiresInSeconds = 60 * 60;
  static const _maxArtworkObjectBytes = 256 * 1024;

  @override
  Future<CoupleRecordingOverview> fetchOverview() async {
    _ensureSupabaseConfigured();

    try {
      final currentData = await Supabase.instance.client
          .rpc('get_current_couple_recording')
          .timeout(AppConfig.supabaseRpcTimeout);
      final currentRow = _asSingleRow(currentData);
      if (currentRow == null) {
        throw const CoupleRecordingRepositoryException(
          CoupleRecordingFailureReason.unknown,
        );
      }

      final slotData = await Supabase.instance.client
          .rpc('list_couple_recording_slots')
          .timeout(AppConfig.supabaseRpcTimeout);
      final slotRows = _asRows(slotData);

      final currentRecording = await _parseCurrentRecording(currentRow);
      final savedSlots = await Future.wait(slotRows.map(_parseSavedSlot));

      return CoupleRecordingOverview(
        slotLimit: currentRow['slot_limit'] as int,
        currentRecording: currentRecording,
        savedSlots: savedSlots,
      );
    } on TimeoutException {
      throw const CoupleRecordingRepositoryException(
        CoupleRecordingFailureReason.requestTimeout,
      );
    } on PostgrestException catch (error) {
      throw _mapPostgrestError(error);
    } on StorageException catch (error) {
      throw _mapStorageError(error);
    }
  }

  @override
  Future<void> uploadCurrentRecording({
    required String coupleId,
    required Uint8List audioBytes,
    required int durationMs,
  }) async {
    _ensureSupabaseConfigured();

    final recordingId = generateRecordingId();
    final storagePath = '$coupleId/recordings/$recordingId.m4a';

    debugRecordingLog(
      'Current recording upload started: '
      'coupleId=$coupleId, recordingId=$recordingId, '
      'bytes=${audioBytes.length}, durationMs=$durationMs',
    );

    try {
      await _bucket
          .uploadBinary(
            storagePath,
            audioBytes,
            fileOptions: const FileOptions(
              upsert: false,
              contentType: 'audio/mp4',
              cacheControl: '60',
            ),
          )
          .timeout(AppConfig.supabaseRpcTimeout);
      debugRecordingLog(
        'Storage upload completed: '
        'recordingId=$recordingId, path=$storagePath',
      );
    } on TimeoutException {
      debugRecordingLog(
        'Storage upload timed out: recordingId=$recordingId, path=$storagePath',
      );
      throw const CoupleRecordingRepositoryException(
        CoupleRecordingFailureReason.requestTimeout,
      );
    } on StorageException catch (error) {
      final mappedError = _mapStorageError(error);
      debugRecordingLog(
        'Storage upload failed: recordingId=$recordingId, error=$mappedError',
      );
      throw mappedError;
    }

    try {
      debugRecordingLog('Finalize RPC started: recordingId=$recordingId');
      await Supabase.instance.client
          .rpc(
            'replace_current_couple_recording',
            params: {
              'requested_recording_id': recordingId,
              'requested_storage_path': storagePath,
              'requested_duration_ms': durationMs,
            },
          )
          .timeout(AppConfig.supabaseRpcTimeout);
      debugRecordingLog('Finalize RPC completed: recordingId=$recordingId');
    } on TimeoutException {
      debugRecordingLog('Finalize RPC timed out: recordingId=$recordingId');
      throw const CoupleRecordingRepositoryException(
        CoupleRecordingFailureReason.requestTimeout,
      );
    } on PostgrestException catch (error) {
      final mappedError = _mapPostgrestError(error);
      debugRecordingLog(
        'Finalize RPC failed: recordingId=$recordingId, error=$mappedError',
      );
      await _discardUploadedRecordingIfNeeded(
        recordingId: recordingId,
        storagePath: storagePath,
        error: mappedError,
      );
      throw mappedError;
    } catch (error) {
      debugRecordingLog(
        'Finalize RPC failed with unexpected error: '
        'recordingId=$recordingId, error=$error',
      );
      rethrow;
    }
  }

  @override
  Future<void> saveCurrentRecordingToSlot({
    required int slotIndex,
    required String title,
    required int? expectedSlotRevision,
  }) async {
    _ensureSupabaseConfigured();

    try {
      await Supabase.instance.client
          .rpc(
            'save_current_couple_recording_to_slot',
            params: {
              'requested_slot_index': slotIndex,
              'requested_title': title,
              'expected_slot_revision': expectedSlotRevision,
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
  Future<void> deleteSlot({
    required String slotId,
    required int expectedSlotRevision,
  }) async {
    _ensureSupabaseConfigured();

    try {
      await Supabase.instance.client
          .rpc(
            'delete_couple_recording_slot',
            params: {
              'requested_slot_id': slotId,
              'expected_slot_revision': expectedSlotRevision,
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
  Future<void> openNextSlot() async {
    _ensureSupabaseConfigured();

    try {
      debugRecordingLog('Open slot RPC started');
      final response = await Supabase.instance.client
          .rpc('open_next_couple_recording_slot')
          .timeout(AppConfig.supabaseRpcTimeout);
      debugRecordingLog('Open slot RPC completed: response=$response');
    } on TimeoutException {
      debugRecordingLog('Open slot RPC timed out');
      throw const CoupleRecordingRepositoryException(
        CoupleRecordingFailureReason.requestTimeout,
      );
    } on PostgrestException catch (error) {
      final mappedError = _mapPostgrestError(error);
      debugRecordingLog(
        'Open slot RPC failed: '
        'code=${error.code}, message=${error.message}, details=${error.details}, '
        'hint=${error.hint}, mappedError=$mappedError',
      );
      throw mappedError;
    } catch (error) {
      debugRecordingLog('Open slot RPC failed with unexpected error: $error');
      rethrow;
    }
  }

  @override
  Future<Uint8List> fetchSlotArtworkDrawingData({
    required String drawingDataPath,
  }) async {
    _ensureSupabaseConfigured();

    try {
      return await _artworkBucket
          .download(drawingDataPath)
          .timeout(AppConfig.supabaseRpcTimeout);
    } on TimeoutException {
      throw const CoupleRecordingRepositoryException(
        CoupleRecordingFailureReason.requestTimeout,
      );
    } on StorageException catch (error) {
      throw _mapStorageError(error);
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
    _ensureSupabaseConfigured();
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
      await _artworkBucket
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
      await _artworkBucket
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
      await Supabase.instance.client
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
      throw _mapPostgrestError(error);
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
      throw _mapStorageError(error);
    } catch (_) {
      await _discardUploadedSlotArtwork(
        uploadAttempted: uploadAttempted,
        slotId: slotId,
        artifactId: artifactId,
      );
      rethrow;
    }
  }

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

  StorageFileApi get _bucket =>
      Supabase.instance.client.storage.from(_bucketId);

  StorageFileApi get _artworkBucket =>
      Supabase.instance.client.storage.from(RecordingSlotArtworkPath.bucketId);

  void _ensureSupabaseConfigured() {
    if (!AppConfig.isSupabaseConfigured) {
      throw const CoupleRecordingRepositoryException(
        CoupleRecordingFailureReason.configMissing,
      );
    }
  }

  Future<CurrentCoupleRecording?> _parseCurrentRecording(
    Map<String, dynamic> row,
  ) async {
    final recordingId = row['current_recording_id'] as String?;
    final storagePath = row['current_recording_path'] as String?;

    if (recordingId == null || storagePath == null) {
      return null;
    }

    final audioUrl = await _createSignedUrl(storagePath);
    return CurrentCoupleRecording(
      recordingId: recordingId,
      senderUserId: row['current_sender_user_id'] as String,
      durationMs: row['current_duration_ms'] as int,
      recordedAt: DateTime.parse(row['current_recorded_at'] as String),
      revision: row['current_revision'] as int,
      updatedAt: DateTime.parse(row['current_updated_at'] as String),
      audioUrl: audioUrl,
    );
  }

  Future<CoupleRecordingSlot> _parseSavedSlot(Map<String, dynamic> row) async {
    final artworkPreviewPath = row['artwork_preview_path'] as String?;
    final urlFutures = <Future<String>>[
      _createSignedUrl(row['recording_path'] as String),
      if (artworkPreviewPath != null)
        _createArtworkSignedUrl(artworkPreviewPath),
    ];
    final urls = await Future.wait(urlFutures);
    final artworkDataPath = row['artwork_data_path'] as String?;
    final artworkRevision = row['artwork_revision'] as int?;
    final placementX = row['placement_normalized_x'] as num?;
    final placementY = row['placement_normalized_y'] as num?;
    final placementRevision = row['placement_revision'] as int?;

    return CoupleRecordingSlot(
      slotId: row['slot_id'] as String,
      slotIndex: row['slot_index'] as int,
      title: row['title'] as String,
      recordingId: row['recording_id'] as String,
      senderUserId: row['sender_user_id'] as String,
      durationMs: row['duration_ms'] as int,
      recordedAt: DateTime.parse(row['recorded_at'] as String),
      slotRevision: row['slot_revision'] as int,
      createdByUserId: row['created_by_user_id'] as String?,
      updatedByUserId: row['updated_by_user_id'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
      audioUrl: urls.first,
      artwork:
          artworkPreviewPath != null &&
              artworkDataPath != null &&
              artworkRevision != null
          ? CoupleRecordingSlotArtwork(
              previewPath: artworkPreviewPath,
              previewUrl: urls[1],
              drawingDataPath: artworkDataPath,
              revision: artworkRevision,
            )
          : null,
      placement:
          placementX != null && placementY != null && placementRevision != null
          ? CoupleRecordingSlotPlacement(
              normalizedX: placementX.toDouble(),
              normalizedY: placementY.toDouble(),
              revision: placementRevision,
            )
          : null,
    );
  }

  Future<String> _createSignedUrl(String path) {
    return _bucket
        .createSignedUrl(path, _signedUrlExpiresInSeconds)
        .timeout(AppConfig.supabaseRpcTimeout);
  }

  Future<String> _createArtworkSignedUrl(String path) {
    return _artworkBucket
        .createSignedUrl(path, _signedUrlExpiresInSeconds)
        .timeout(AppConfig.supabaseRpcTimeout);
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
      await Supabase.instance.client
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

  Map<String, dynamic>? _asSingleRow(Object? data) {
    if (data == null) {
      return null;
    }

    if (data is Map<String, dynamic>) {
      return data;
    }

    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }

    if (data is List) {
      if (data.isEmpty) {
        return null;
      }

      final first = data.first;
      if (first is Map<String, dynamic>) {
        return first;
      }

      if (first is Map) {
        return Map<String, dynamic>.from(first);
      }
    }

    throw const CoupleRecordingRepositoryException(
      CoupleRecordingFailureReason.unknown,
    );
  }

  List<Map<String, dynamic>> _asRows(Object? data) {
    if (data == null) {
      return const [];
    }

    if (data is List<Map<String, dynamic>>) {
      return data;
    }

    if (data is List) {
      return data
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false);
    }

    final row = _asSingleRow(data);
    if (row == null) {
      return const [];
    }

    return [row];
  }

  CoupleRecordingRepositoryException _mapPostgrestError(
    PostgrestException error,
  ) {
    return CoupleRecordingRepositoryException(
      _reasonFromMessage(error.message),
      error.message,
    );
  }

  CoupleRecordingRepositoryException _mapStorageError(StorageException error) {
    return CoupleRecordingRepositoryException(
      CoupleRecordingFailureReason.storage,
      error.message,
    );
  }

  Future<void> _discardUploadedRecordingIfNeeded({
    required String recordingId,
    required String storagePath,
    required CoupleRecordingRepositoryException error,
  }) async {
    if (!shouldDiscardUploadedRecording(error)) {
      debugRecordingLog(
        'Cleanup skipped: recordingId=$recordingId, reason=${error.reason}',
      );
      return;
    }

    debugRecordingLog(
      'Cleanup RPC started: '
      'recordingId=$recordingId, path=$storagePath, reason=${error.reason}',
    );

    try {
      await Supabase.instance.client
          .rpc(
            'discard_uploaded_couple_recording',
            params: {
              'requested_recording_id': recordingId,
              'requested_storage_path': storagePath,
            },
          )
          .timeout(AppConfig.supabaseRpcTimeout);
      debugRecordingLog('Cleanup RPC completed: recordingId=$recordingId');
    } on TimeoutException {
      debugRecordingLog('Cleanup RPC timed out: recordingId=$recordingId');
    } on PostgrestException catch (cleanupError) {
      debugRecordingLog(
        'Cleanup RPC failed: '
        'recordingId=$recordingId, error=${cleanupError.message}',
      );
    } catch (cleanupError) {
      debugRecordingLog(
        'Cleanup RPC failed with unexpected error: '
        'recordingId=$recordingId, error=$cleanupError',
      );
    }
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
