import 'dart:async';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../recording_debug_log.dart';
import 'couple_recording_data_gateways.dart';
import 'couple_recording_failure.dart';
import 'recording_id_generator.dart';
import 'recording_upload_failure_policy.dart';
import 'supabase_couple_recording_gateway_support.dart';

class SupabaseCurrentCoupleRecordingWriter
    implements CurrentCoupleRecordingWriter {
  const SupabaseCurrentCoupleRecordingWriter({
    SupabaseCoupleRecordingGatewaySupport support =
        const SupabaseCoupleRecordingGatewaySupport(),
  }) : _support = support;

  final SupabaseCoupleRecordingGatewaySupport _support;

  @override
  Future<void> uploadCurrentRecording({
    required String coupleId,
    required Uint8List audioBytes,
    required int durationMs,
    String? recordingId,
    bool resumeExistingUpload = false,
  }) async {
    _support.ensureConfigured();

    final resolvedRecordingId = recordingId ?? generateRecordingId();
    final storagePath = '$coupleId/recordings/$resolvedRecordingId.m4a';

    debugRecordingLog(
      'Current recording upload started: '
      'coupleId=$coupleId, recordingId=$resolvedRecordingId, '
      'bytes=${audioBytes.length}, durationMs=$durationMs',
    );

    try {
      await _support.recordingBucket
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
        'recordingId=$resolvedRecordingId, path=$storagePath',
      );
    } on TimeoutException {
      if (resumeExistingUpload &&
          await _isCurrentRecording(resolvedRecordingId)) {
        debugRecordingLog(
          'Timed out widget upload was already finalized: '
          'recordingId=$resolvedRecordingId',
        );
        return;
      }
      debugRecordingLog(
        'Storage upload timed out: '
        'recordingId=$resolvedRecordingId, path=$storagePath',
      );
      throw const CoupleRecordingRepositoryException(
        CoupleRecordingFailureReason.requestTimeout,
      );
    } on StorageException catch (error) {
      if (resumeExistingUpload && _isExistingStorageObject(error)) {
        if (await _isCurrentRecording(resolvedRecordingId)) {
          debugRecordingLog(
            'Existing widget upload already finalized: '
            'recordingId=$resolvedRecordingId',
          );
          return;
        }
        debugRecordingLog(
          'Existing widget upload will resume finalization: '
          'recordingId=$resolvedRecordingId',
        );
      } else {
        final mappedError = _support.mapStorageError(error);
        debugRecordingLog(
          'Storage upload failed: '
          'recordingId=$resolvedRecordingId, error=$mappedError',
        );
        throw mappedError;
      }
    }

    try {
      debugRecordingLog(
        'Finalize RPC started: recordingId=$resolvedRecordingId',
      );
      await _support.client
          .rpc(
            'replace_current_couple_recording',
            params: {
              'requested_recording_id': resolvedRecordingId,
              'requested_storage_path': storagePath,
              'requested_duration_ms': durationMs,
            },
          )
          .timeout(AppConfig.supabaseRpcTimeout);
      debugRecordingLog(
        'Finalize RPC completed: recordingId=$resolvedRecordingId',
      );
    } on TimeoutException {
      if (resumeExistingUpload &&
          await _isCurrentRecording(resolvedRecordingId)) {
        debugRecordingLog(
          'Timed out recording finalize was already completed: '
          'recordingId=$resolvedRecordingId',
        );
        return;
      }
      debugRecordingLog(
        'Finalize RPC timed out: recordingId=$resolvedRecordingId',
      );
      throw const CoupleRecordingRepositoryException(
        CoupleRecordingFailureReason.requestTimeout,
      );
    } on PostgrestException catch (error) {
      if (resumeExistingUpload &&
          await _isCurrentRecording(resolvedRecordingId)) {
        debugRecordingLog(
          'Widget upload finalize retry already completed: '
          'recordingId=$resolvedRecordingId',
        );
        return;
      }
      final mappedError = _support.mapPostgrestError(error);
      debugRecordingLog(
        'Finalize RPC failed: '
        'recordingId=$resolvedRecordingId, error=$mappedError',
      );
      await _discardUploadedRecordingIfNeeded(
        recordingId: resolvedRecordingId,
        storagePath: storagePath,
        error: mappedError,
      );
      throw mappedError;
    } catch (error) {
      debugRecordingLog(
        'Finalize RPC failed with unexpected error: '
        'recordingId=$resolvedRecordingId, error=$error',
      );
      rethrow;
    }
  }

  bool _isExistingStorageObject(StorageException error) {
    final normalized = '${error.error} ${error.message}'.toLowerCase();
    return error.statusCode == '409' ||
        normalized.contains('duplicate') ||
        normalized.contains('already exists');
  }

  Future<bool> _isCurrentRecording(String recordingId) async {
    try {
      final data = await _support.client
          .rpc('get_current_couple_recording')
          .timeout(AppConfig.supabaseRpcTimeout);
      final row = _support.asSingleRow(data);
      return row?['current_recording_id'] == recordingId;
    } catch (_) {
      return false;
    }
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
      await _support.client
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
}
