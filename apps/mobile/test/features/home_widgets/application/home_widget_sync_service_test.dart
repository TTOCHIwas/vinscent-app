import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/home_widgets/application/home_widget_sync_service.dart';
import 'package:vinscent/features/home_widgets/application/home_widget_synchronizer.dart';
import 'package:vinscent/features/home_widgets/data/home_widget_asset_validator.dart';
import 'package:vinscent/features/home_widgets/data/home_widget_snapshot.dart';
import 'package:vinscent/features/home_widgets/data/home_widget_snapshot_repository.dart';

void main() {
  test(
    'retries once when a snapshot source is temporarily unavailable',
    () async {
      final repository = _SequenceSnapshotRepository([
        const HomeWidgetSnapshot(
          characterImage: HomeWidgetAssetUpdate.preserve(),
          recordingAudio: HomeWidgetAssetUpdate.remove(),
          partnerCardImage: HomeWidgetAssetUpdate.remove(),
        ),
        HomeWidgetSnapshot(
          characterImage: HomeWidgetAssetUpdate.replace(_characterAsset),
          recordingAudio: const HomeWidgetAssetUpdate.remove(),
          partnerCardImage: const HomeWidgetAssetUpdate.remove(),
        ),
      ]);
      final store = _MemoryHomeWidgetStore();
      final service = HomeWidgetSyncService(
        snapshotRepository: repository,
        synchronizer: HomeWidgetSynchronizer(
          store: store,
          downloader: const _PngDownloader(),
        ),
        retryDelay: Duration.zero,
        isSupportedPlatform: true,
      );

      await service.synchronizeSafely();

      expect(repository.fetchCount, 2);
      expect(
        store.values[HomeWidgetStorage.characterImageVersionKey],
        _characterAsset.version,
      );
    },
  );
}

const _characterAsset = HomeWidgetRemoteAsset(
  url: 'https://example.com/character.png',
  version: 'character-v1',
  extension: 'png',
);

final _pngBytes = Uint8List.fromList([
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
]);

class _SequenceSnapshotRepository implements HomeWidgetSnapshotRepository {
  _SequenceSnapshotRepository(this.snapshots);

  final List<HomeWidgetSnapshot?> snapshots;
  var fetchCount = 0;

  @override
  Future<HomeWidgetSnapshot?> fetchSnapshot() async {
    final index = fetchCount;
    fetchCount += 1;
    return snapshots[index];
  }
}

class _PngDownloader implements HomeWidgetAssetDownloader {
  const _PngDownloader();

  @override
  Future<Uint8List> download(String url, {required int maxBytes}) async {
    return _pngBytes;
  }
}

class _MemoryHomeWidgetStore implements HomeWidgetStore {
  final values = <String, String>{};
  final files = <String, Uint8List>{};

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
  }

  @override
  Future<String> saveFile({
    required String key,
    required Uint8List bytes,
    required String extension,
  }) async {
    final path = '/$key.$extension';
    values[key] = path;
    files[path] = bytes;
    return path;
  }

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}
