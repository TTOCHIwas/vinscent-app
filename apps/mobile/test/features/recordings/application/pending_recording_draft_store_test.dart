import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vinscent/features/recordings/application/pending_recording_draft_store.dart';

void main() {
  late Directory supportDirectory;
  late SharedPreferencesPendingRecordingDraftStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    supportDirectory = await Directory.systemTemp.createTemp(
      'vinscent-recording-draft-',
    );
    store = SharedPreferencesPendingRecordingDraftStore(
      preferences: SharedPreferencesAsync(),
      supportDirectoryLoader: () async => supportDirectory,
    );
  });

  tearDown(() async {
    if (await supportDirectory.exists()) {
      await supportDirectory.delete(recursive: true);
    }
  });

  test('persists and restores a pending recording with its audio file', () async {
    const draft = PendingRecordingDraft(
      recordingId: '30000000-0000-0000-0000-000000000001',
      coupleId: '20000000-0000-0000-0000-000000000001',
      durationMs: 1200,
    );
    final filePath = await store.createFilePath(draft.recordingId);
    await File(filePath).writeAsBytes([1, 2, 3]);

    await store.persist(draft);

    expect(await store.load(), draft);
    expect(await store.readAudioBytes(draft), [1, 2, 3]);
  });

  test('remove deletes both pending metadata and its audio file', () async {
    const draft = PendingRecordingDraft(
      recordingId: '30000000-0000-0000-0000-000000000002',
      coupleId: '20000000-0000-0000-0000-000000000001',
      durationMs: 800,
    );
    final filePath = await store.createFilePath(draft.recordingId);
    await File(filePath).writeAsBytes([4, 5, 6]);
    await store.persist(draft);

    await store.remove(draft);

    expect(await File(filePath).exists(), isFalse);
    expect(await store.load(), isNull);
  });

  test('load clears stale metadata when the audio file is missing', () async {
    const draft = PendingRecordingDraft(
      recordingId: '30000000-0000-0000-0000-000000000003',
      coupleId: '20000000-0000-0000-0000-000000000001',
      durationMs: 500,
    );
    await store.persist(draft);

    expect(await store.load(), isNull);
    expect(await store.load(), isNull);
  });
}
