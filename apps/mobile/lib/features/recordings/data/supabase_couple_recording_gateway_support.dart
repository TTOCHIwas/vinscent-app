import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import 'couple_recording_failure.dart';
import 'recording_slot_artwork_path.dart';

class SupabaseCoupleRecordingGatewaySupport {
  const SupabaseCoupleRecordingGatewaySupport();

  static const recordingBucketId = 'couple-recordings';
  static const signedUrlExpiresInSeconds = 60 * 60;

  SupabaseClient get client => Supabase.instance.client;

  StorageFileApi get recordingBucket {
    return client.storage.from(recordingBucketId);
  }

  StorageFileApi get artworkBucket {
    return client.storage.from(RecordingSlotArtworkPath.bucketId);
  }

  void ensureConfigured() {
    if (!AppConfig.isSupabaseConfigured) {
      throw const CoupleRecordingRepositoryException(
        CoupleRecordingFailureReason.configMissing,
      );
    }
  }

  Future<String> createRecordingSignedUrl(String path) {
    return recordingBucket
        .createSignedUrl(path, signedUrlExpiresInSeconds)
        .timeout(AppConfig.supabaseRpcTimeout);
  }

  Future<String> createArtworkSignedUrl(String path) {
    return artworkBucket
        .createSignedUrl(path, signedUrlExpiresInSeconds)
        .timeout(AppConfig.supabaseRpcTimeout);
  }

  Map<String, dynamic>? asSingleRow(Object? data) {
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

  List<Map<String, dynamic>> asRows(Object? data) {
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

    final row = asSingleRow(data);
    if (row == null) {
      return const [];
    }

    return [row];
  }

  CoupleRecordingRepositoryException mapPostgrestError(
    PostgrestException error,
  ) {
    return CoupleRecordingRepositoryException(
      _reasonFromMessage(error.message),
      error.message,
    );
  }

  CoupleRecordingRepositoryException mapStorageError(StorageException error) {
    return CoupleRecordingRepositoryException(
      CoupleRecordingFailureReason.storage,
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
