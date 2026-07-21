import 'couple_recording.dart';

typedef RecordingAssetUrlResolver = Future<String> Function(String path);

class CoupleRecordingReadMapper {
  const CoupleRecordingReadMapper();

  Future<CurrentCoupleRecording?> mapCurrentRecording(
    Map<String, dynamic> row, {
    required RecordingAssetUrlResolver resolveAudioUrl,
  }) async {
    final recordingId = row['current_recording_id'] as String?;
    final storagePath = row['current_recording_path'] as String?;

    if (recordingId == null || storagePath == null) {
      return null;
    }

    return CurrentCoupleRecording(
      recordingId: recordingId,
      senderUserId: row['current_sender_user_id'] as String,
      durationMs: _toInt(row['current_duration_ms']),
      recordedAt: _parseDateTime(row['current_recorded_at']),
      revision: _toInt(row['current_revision']),
      updatedAt: _parseDateTime(row['current_updated_at']),
      audioUrl: await resolveAudioUrl(storagePath),
    );
  }

  Future<CoupleRecordingSlot> mapSavedSlot(
    Map<String, dynamic> row, {
    required RecordingAssetUrlResolver resolveAudioUrl,
    required RecordingAssetUrlResolver resolveArtworkUrl,
  }) async {
    final artworkPreviewPath = row['artwork_preview_path'] as String?;
    final artworkDataPath = row['artwork_data_path'] as String?;
    final artworkRevision = row['artwork_revision'] as num?;
    final hasArtwork =
        artworkPreviewPath != null &&
        artworkDataPath != null &&
        artworkRevision != null;
    final urls = await Future.wait([
      resolveAudioUrl(row['recording_path'] as String),
      if (hasArtwork) resolveArtworkUrl(artworkPreviewPath),
    ]);

    final placementX = row['placement_normalized_x'] as num?;
    final placementY = row['placement_normalized_y'] as num?;
    final placementRevision = row['placement_revision'] as num?;
    final placementZIndex = row['placement_z_index'] as num?;

    return CoupleRecordingSlot(
      slotId: row['slot_id'] as String,
      slotIndex: _toInt(row['slot_index']),
      title: row['title'] as String,
      recordingId: row['recording_id'] as String,
      senderUserId: row['sender_user_id'] as String,
      durationMs: _toInt(row['duration_ms']),
      recordedAt: _parseDateTime(row['recorded_at']),
      slotRevision: _toInt(row['slot_revision']),
      createdByUserId: row['created_by_user_id'] as String?,
      updatedByUserId: row['updated_by_user_id'] as String?,
      createdAt: _parseDateTime(row['created_at']),
      updatedAt: _parseDateTime(row['updated_at']),
      audioUrl: urls.first,
      artwork: hasArtwork
          ? CoupleRecordingSlotArtwork(
              previewPath: artworkPreviewPath,
              previewUrl: urls[1],
              drawingDataPath: artworkDataPath,
              revision: artworkRevision.toInt(),
            )
          : null,
      placement:
          placementX != null && placementY != null && placementRevision != null
          ? CoupleRecordingSlotPlacement(
              normalizedX: placementX.toDouble(),
              normalizedY: placementY.toDouble(),
              revision: placementRevision.toInt(),
              zIndex: placementZIndex?.toInt() ?? 0,
            )
          : null,
    );
  }

  DateTime _parseDateTime(Object? value) {
    return DateTime.parse(value as String);
  }

  int _toInt(Object? value) {
    return (value as num).toInt();
  }
}
