import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/home_widgets/application/home_widget_sync_service.dart';
import 'package:vinscent/features/home_widgets/application/home_widget_synchronizer.dart';
import 'package:vinscent/features/home_widgets/data/home_widget_asset_validator.dart';
import 'package:vinscent/features/home_widgets/data/home_widget_recording_cache_repository.dart';
import 'package:vinscent/features/home_widgets/data/home_widget_recording_snapshot_repository.dart';
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

  test(
    'synchronizes only the required recording for a push notification',
    () async {
      final store = _MemoryHomeWidgetStore();
      final cacheRepository = HomeWidgetRecordingCacheRepository(store: store);
      await cacheRepository.markRequired(
        coupleId: 'couple-id',
        recordingId: 'recording-id',
      );
      final repository = _RecordingSnapshotRepository();
      final downloader = _RecordingDownloader();
      final service = HomeWidgetRecordingSyncService(
        snapshotRepository: repository,
        synchronizer: HomeWidgetSynchronizer(
          store: store,
          downloader: downloader,
          recordingCacheRepository: cacheRepository,
        ),
        retryDelay: Duration.zero,
        isSupportedPlatform: true,
      );

      final synchronized = await service.synchronizeSafely(
        expectedCoupleId: 'couple-id',
      );

      expect(synchronized, isTrue);
      expect(repository.expectedCoupleIds, ['couple-id']);
      expect(downloader.requestedUrls, ['https://example.com/recording.m4a']);
      expect(store.refreshedTargets, [HomeWidgetStorage.characterTarget]);
    },
  );

  test(
    'reports failure after targeted recording retries are exhausted',
    () async {
      final repository = _RecordingSnapshotRepository(
        update: const HomeWidgetAssetUpdate.preserve(),
      );
      final service = HomeWidgetRecordingSyncService(
        snapshotRepository: repository,
        synchronizer: HomeWidgetSynchronizer(
          store: _MemoryHomeWidgetStore(),
          downloader: _RecordingDownloader(),
        ),
        maxAttempts: 2,
        retryDelay: Duration.zero,
        isSupportedPlatform: true,
      );

      final synchronized = await service.synchronizeSafely(
        expectedCoupleId: 'couple-id',
      );

      expect(synchronized, isFalse);
      expect(repository.expectedCoupleIds, ['couple-id', 'couple-id']);
    },
  );

  test('rejects a recording snapshot fetched before a newer marker', () async {
    final store = _MemoryHomeWidgetStore();
    final cacheRepository = HomeWidgetRecordingCacheRepository(store: store);
    await cacheRepository.installVerified(
      coupleId: 'couple-id',
      recordingId: 'recording-a',
      revision: 1,
      bytes: _m4aBytes,
    );
    final repository = _RecordingSnapshotRepository(
      update: const HomeWidgetAssetUpdate.replace(
        HomeWidgetRecordingRemoteAsset(
          url: 'https://example.com/recording-a.m4a',
          coupleId: 'couple-id',
          recordingId: 'recording-a',
          revision: 1,
        ),
      ),
      onFetch: () => cacheRepository.markRequired(
        coupleId: 'couple-id',
        recordingId: 'recording-b',
      ),
    );
    final service = HomeWidgetRecordingSyncService(
      snapshotRepository: repository,
      synchronizer: HomeWidgetSynchronizer(
        store: store,
        downloader: _RecordingDownloader(),
        recordingCacheRepository: cacheRepository,
      ),
      maxAttempts: 1,
      retryDelay: Duration.zero,
      isSupportedPlatform: true,
    );

    final synchronized = await service.synchronizeSafely(
      expectedCoupleId: 'couple-id',
    );

    expect(synchronized, isFalse);
    final manifest = await cacheRepository.read();
    expect(manifest?.requiredRecordingId, 'recording-b');
    expect(manifest?.cachedRecordingId, 'recording-a');
  });

  test('rejects a recording removal fetched before a newer marker', () async {
    final store = _MemoryHomeWidgetStore();
    final cacheRepository = HomeWidgetRecordingCacheRepository(store: store);
    await cacheRepository.installVerified(
      coupleId: 'couple-id',
      recordingId: 'recording-a',
      revision: 1,
      bytes: _m4aBytes,
    );
    final repository = _RecordingSnapshotRepository(
      update: const HomeWidgetAssetUpdate.remove(),
      onFetch: () => cacheRepository.markRequired(
        coupleId: 'couple-id',
        recordingId: 'recording-b',
      ),
    );
    final service = HomeWidgetRecordingSyncService(
      snapshotRepository: repository,
      synchronizer: HomeWidgetSynchronizer(
        store: store,
        downloader: _RecordingDownloader(),
        recordingCacheRepository: cacheRepository,
      ),
      maxAttempts: 1,
      retryDelay: Duration.zero,
      isSupportedPlatform: true,
    );

    final synchronized = await service.synchronizeSafely(
      expectedCoupleId: 'couple-id',
    );

    expect(synchronized, isFalse);
    final manifest = await cacheRepository.read();
    expect(manifest?.requiredRecordingId, 'recording-b');
    expect(manifest?.cachedRecordingId, 'recording-a');
  });
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

class _RecordingSnapshotRepository
    implements HomeWidgetRecordingSnapshotRepository {
  _RecordingSnapshotRepository({
    this.update = const HomeWidgetAssetUpdate.replace(
      HomeWidgetRecordingRemoteAsset(
        url: 'https://example.com/recording.m4a',
        coupleId: 'couple-id',
        recordingId: 'recording-id',
        revision: 1,
      ),
    ),
    this.onFetch,
  });

  final HomeWidgetAssetUpdate update;
  final Future<void> Function()? onFetch;
  final expectedCoupleIds = <String>[];

  @override
  Future<HomeWidgetAssetUpdate> fetchRecordingAudio({
    required String expectedCoupleId,
  }) async {
    expectedCoupleIds.add(expectedCoupleId);
    await onFetch?.call();
    return update;
  }
}

class _RecordingDownloader implements HomeWidgetAssetDownloader {
  final requestedUrls = <String>[];

  @override
  Future<Uint8List> download(String url, {required int maxBytes}) async {
    requestedUrls.add(url);
    return _m4aBytes;
  }
}

class _MemoryHomeWidgetStore implements HomeWidgetStore {
  final values = <String, String>{};
  final files = <String, Uint8List>{};
  final refreshedTargets = <HomeWidgetTarget>[];

  @override
  Future<bool> isFileUsable(String path, {required String extension}) async {
    final bytes = files[path];
    return bytes != null && isValidHomeWidgetAsset(bytes, extension);
  }

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> refreshWidget(HomeWidgetTarget target) async {
    refreshedTargets.add(target);
  }

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
