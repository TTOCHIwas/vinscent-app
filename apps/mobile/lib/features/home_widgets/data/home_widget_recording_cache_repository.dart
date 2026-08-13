import 'dart:async';
import 'dart:typed_data';

import '../application/home_widget_synchronizer.dart';
import 'home_widget_asset_validator.dart';
import 'home_widget_recording_cache_manifest.dart';
import 'home_widget_snapshot.dart';

class HomeWidgetRecordingCacheRepository {
  HomeWidgetRecordingCacheRepository({required HomeWidgetStore store})
    : _store = store;

  final HomeWidgetStore _store;
  Future<void> _pendingMutation = Future<void>.value();

  Future<HomeWidgetRecordingCacheManifest?> read() async {
    final value = await _store.read(
      HomeWidgetStorage.recordingCacheManifestKey,
    );
    return HomeWidgetRecordingCacheManifest.tryParse(value);
  }

  Future<HomeWidgetRecordingCacheManifest> markRequired({
    required String coupleId,
    required String recordingId,
  }) {
    return _serialize(() async {
      final current = await read();
      final next = HomeWidgetRecordingCachePolicy.markRequired(
        current: current,
        coupleId: coupleId,
        recordingId: recordingId,
      );
      await _writeManifest(next);
      if (current?.coupleId != null && current?.coupleId != coupleId) {
        await _removeManagedFile(current!);
        await _store.remove(HomeWidgetStorage.recordingAudioPathKey);
        await _store.remove(HomeWidgetStorage.recordingAudioVersionKey);
      }
      return next;
    });
  }

  Future<bool> installVerified({
    required String coupleId,
    required String recordingId,
    required int revision,
    required Uint8List bytes,
    HomeWidgetRecordingCacheManifest? expected,
  }) {
    return _serialize(() async {
      if (coupleId.trim().isEmpty ||
          recordingId.trim().isEmpty ||
          revision < 0 ||
          !isValidHomeWidgetAsset(bytes, 'm4a')) {
        throw const FormatException('Invalid widget recording cache input');
      }

      final fileKey = _fileKey(recordingId, revision);
      final savedPath = await _store.saveFile(
        key: fileKey,
        bytes: bytes,
        extension: 'm4a',
      );
      if (!await _store.isFileUsable(savedPath, extension: 'm4a')) {
        await _store.remove(fileKey);
        throw StateError('Saved widget recording cache is unusable');
      }

      final current = await read();
      if (expected != null &&
          !HomeWidgetRecordingCachePolicy.canCommitFetched(
            expected: expected,
            current: current,
          )) {
        if (current?.fileKey != fileKey) {
          await _store.remove(fileKey);
        }
        return false;
      }

      final manifest = HomeWidgetRecordingCacheManifest.verified(
        coupleId: coupleId,
        recordingId: recordingId,
        revision: revision,
        audioPath: savedPath,
        fileKey: fileKey,
        generation: (current?.generation ?? 0) + 1,
      );
      await _writeManifest(manifest);
      await _store.write(HomeWidgetStorage.recordingAudioPathKey, savedPath);
      await _store.write(
        HomeWidgetStorage.recordingAudioVersionKey,
        '$recordingId:$revision',
      );
      return true;
    });
  }

  Future<void> clear() {
    return _serialize(() async {
      final current = await read();
      await _store.remove(HomeWidgetStorage.recordingCacheManifestKey);
      await _store.remove(HomeWidgetStorage.recordingAudioPathKey);
      await _store.remove(HomeWidgetStorage.recordingAudioVersionKey);
      if (current != null) {
        await _removeManagedFile(current);
      }
    });
  }

  Future<void> _writeManifest(HomeWidgetRecordingCacheManifest manifest) {
    return _store.write(
      HomeWidgetStorage.recordingCacheManifestKey,
      manifest.toJsonString(),
    );
  }

  Future<void> _removeManagedFile(
    HomeWidgetRecordingCacheManifest manifest,
  ) async {
    final fileKey = manifest.fileKey;
    if (fileKey != null) {
      await _store.remove(fileKey);
    }
  }

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final completer = Completer<T>();
    _pendingMutation = _pendingMutation.then((_) async {
      try {
        completer.complete(await operation());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  String _fileKey(String recordingId, int revision) {
    final normalizedId = recordingId.replaceAll(RegExp('[^A-Za-z0-9_-]'), '_');
    return 'widget_recording_audio_${normalizedId}_r$revision';
  }
}
