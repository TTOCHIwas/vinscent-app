import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/home_widgets/application/home_widget_synchronizer.dart';
import 'package:vinscent/features/home_widgets/data/home_widget_asset_validator.dart';
import 'package:vinscent/features/home_widgets/data/home_widget_recording_cache_manifest.dart';
import 'package:vinscent/features/home_widgets/data/home_widget_recording_cache_repository.dart';
import 'package:vinscent/features/home_widgets/data/home_widget_snapshot.dart';

void main() {
  test(
    'installs a versioned recording before publishing its manifest',
    () async {
      final store = _RecordingCacheStore();
      final repository = HomeWidgetRecordingCacheRepository(store: store);

      final installed = await repository.installVerified(
        coupleId: 'couple-a',
        recordingId: 'recording-a',
        revision: 3,
        bytes: _m4aBytes,
      );

      expect(installed, isTrue);
      final manifest = await repository.read();
      expect(manifest?.cachedRecordingId, 'recording-a');
      expect(manifest?.cachedRevision, 3);
      expect(manifest?.freshness, HomeWidgetRecordingCacheFreshness.verified);
      expect(manifest?.fileKey, contains('recording-a'));
      expect(store.events, [
        startsWith('save-file:'),
        startsWith('write:${HomeWidgetStorage.recordingCacheManifestKey}:'),
        startsWith('write:${HomeWidgetStorage.recordingAudioPathKey}:'),
        'write:${HomeWidgetStorage.recordingAudioVersionKey}:recording-a:3',
      ]);
    },
  );

  test(
    'discards a fetched file when a newer marker changed generation',
    () async {
      final store = _RecordingCacheStore();
      final repository = HomeWidgetRecordingCacheRepository(store: store);
      await repository.markRequired(
        coupleId: 'couple-a',
        recordingId: 'recording-a',
      );
      final expected = await repository.read();
      await repository.markRequired(
        coupleId: 'couple-a',
        recordingId: 'recording-b',
      );

      final installed = await repository.installVerified(
        coupleId: 'couple-a',
        recordingId: 'recording-a',
        revision: 1,
        bytes: _m4aBytes,
        expected: expected,
      );

      expect(installed, isFalse);
      expect((await repository.read())?.requiredRecordingId, 'recording-b');
      expect(store.files, isEmpty);
    },
  );

  test(
    'clears the manifest, compatibility keys, and managed audio file',
    () async {
      final store = _RecordingCacheStore();
      final repository = HomeWidgetRecordingCacheRepository(store: store);
      await repository.installVerified(
        coupleId: 'couple-a',
        recordingId: 'recording-a',
        revision: 1,
        bytes: _m4aBytes,
      );

      await repository.clear();

      expect(await repository.read(), isNull);
      expect(store.values[HomeWidgetStorage.recordingAudioPathKey], isNull);
      expect(store.values[HomeWidgetStorage.recordingAudioVersionKey], isNull);
      expect(store.files, isEmpty);
    },
  );
}

final _m4aBytes = Uint8List.fromList([
  0x00,
  0x00,
  0x00,
  0x18,
  0x66,
  0x74,
  0x79,
  0x70,
  0x4D,
  0x34,
  0x41,
  0x20,
]);

class _RecordingCacheStore implements HomeWidgetStore {
  final values = <String, String>{};
  final files = <String, Uint8List>{};
  final events = <String>[];

  @override
  Future<bool> isFileUsable(String path, {required String extension}) async {
    final bytes = files[path];
    return bytes != null && isValidHomeWidgetAsset(bytes, extension);
  }

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> refreshWidget(HomeWidgetTarget target) async {}

  @override
  Future<void> remove(String key) async {
    final path = values.remove(key);
    if (path != null) {
      files.remove(path);
    }
    events.add('remove:$key');
  }

  @override
  Future<String> saveFile({
    required String key,
    required Uint8List bytes,
    required String extension,
  }) async {
    final path = '/home_widget/$key.$extension';
    files[path] = bytes;
    values[key] = path;
    events.add('save-file:$key');
    return path;
  }

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
    events.add('write:$key:$value');
  }
}
