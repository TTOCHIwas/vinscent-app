import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/recordings/data/couple_recording_read_mapper.dart';

void main() {
  const mapper = CoupleRecordingReadMapper();

  test('maps the current recording and resolves its audio URL', () async {
    final requestedPaths = <String>[];

    final recording = await mapper.mapCurrentRecording(
      {
        'current_recording_id': 'recording-1',
        'current_recording_path': 'couple/recordings/recording-1.m4a',
        'current_sender_user_id': 'user-1',
        'current_duration_ms': 15000,
        'current_recorded_at': '2026-07-21T08:00:00Z',
        'current_revision': 2,
        'current_updated_at': '2026-07-21T08:01:00Z',
      },
      resolveAudioUrl: (path) async {
        requestedPaths.add(path);
        return 'https://example.com/audio';
      },
    );

    expect(requestedPaths, ['couple/recordings/recording-1.m4a']);
    expect(recording?.recordingId, 'recording-1');
    expect(recording?.durationMs, 15000);
    expect(recording?.revision, 2);
    expect(recording?.audioUrl, 'https://example.com/audio');
  });

  test(
    'does not resolve an audio URL when current recording is empty',
    () async {
      var resolverCalled = false;

      final recording = await mapper.mapCurrentRecording(
        {'current_recording_id': null, 'current_recording_path': null},
        resolveAudioUrl: (path) async {
          resolverCalled = true;
          return path;
        },
      );

      expect(recording, isNull);
      expect(resolverCalled, isFalse);
    },
  );

  test('maps a saved slot with artwork and home placement', () async {
    final requestedAudioPaths = <String>[];
    final requestedArtworkPaths = <String>[];

    final slot = await mapper.mapSavedSlot(
      {
        'slot_id': 'slot-1',
        'slot_index': 1,
        'title': '첫 녹음',
        'recording_id': 'recording-1',
        'recording_path': 'couple/recordings/recording-1.m4a',
        'sender_user_id': 'user-1',
        'duration_ms': 12000,
        'recorded_at': '2026-07-21T08:00:00Z',
        'slot_revision': 3,
        'created_by_user_id': 'user-1',
        'updated_by_user_id': 'user-2',
        'created_at': '2026-07-21T08:01:00Z',
        'updated_at': '2026-07-21T08:02:00Z',
        'artwork_preview_path': 'couple/artwork/preview.webp',
        'artwork_data_path': 'couple/artwork/drawing.json.gz',
        'artwork_revision': 4,
        'placement_normalized_x': 0.25,
        'placement_normalized_y': 0.75,
        'placement_revision': 5,
        'placement_z_index': 6,
      },
      resolveAudioUrl: (path) async {
        requestedAudioPaths.add(path);
        return 'https://example.com/audio';
      },
      resolveArtworkUrl: (path) async {
        requestedArtworkPaths.add(path);
        return 'https://example.com/artwork';
      },
    );

    expect(requestedAudioPaths, ['couple/recordings/recording-1.m4a']);
    expect(requestedArtworkPaths, ['couple/artwork/preview.webp']);
    expect(slot.slotId, 'slot-1');
    expect(slot.title, '첫 녹음');
    expect(slot.audioUrl, 'https://example.com/audio');
    expect(slot.artwork?.previewUrl, 'https://example.com/artwork');
    expect(slot.artwork?.drawingDataPath, 'couple/artwork/drawing.json.gz');
    expect(slot.artwork?.revision, 4);
    expect(slot.placement?.normalizedX, 0.25);
    expect(slot.placement?.normalizedY, 0.75);
    expect(slot.placement?.revision, 5);
    expect(slot.placement?.zIndex, 6);
  });

  test('omits absent artwork and placement from a saved slot', () async {
    var artworkResolverCalled = false;

    final slot = await mapper.mapSavedSlot(
      {
        'slot_id': 'slot-2',
        'slot_index': 2,
        'title': '두 번째 녹음',
        'recording_id': 'recording-2',
        'recording_path': 'couple/recordings/recording-2.m4a',
        'sender_user_id': 'user-2',
        'duration_ms': 9000,
        'recorded_at': '2026-07-21T09:00:00Z',
        'slot_revision': 1,
        'created_by_user_id': null,
        'updated_by_user_id': null,
        'created_at': '2026-07-21T09:01:00Z',
        'updated_at': '2026-07-21T09:01:00Z',
        'artwork_preview_path': null,
        'artwork_data_path': null,
        'artwork_revision': null,
        'placement_normalized_x': null,
        'placement_normalized_y': null,
        'placement_revision': null,
        'placement_z_index': null,
      },
      resolveAudioUrl: (path) async => 'https://example.com/audio-2',
      resolveArtworkUrl: (path) async {
        artworkResolverCalled = true;
        return path;
      },
    );

    expect(slot.artwork, isNull);
    expect(slot.placement, isNull);
    expect(artworkResolverCalled, isFalse);
  });
}
