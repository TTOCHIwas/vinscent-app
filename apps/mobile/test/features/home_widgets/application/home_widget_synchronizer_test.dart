import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/home_widgets/application/home_widget_synchronizer.dart';
import 'package:vinscent/features/home_widgets/data/home_widget_asset_validator.dart';
import 'package:vinscent/features/home_widgets/data/home_widget_recording_cache_manifest.dart';
import 'package:vinscent/features/home_widgets/data/home_widget_recording_cache_repository.dart';
import 'package:vinscent/features/home_widgets/data/home_widget_snapshot.dart';

void main() {
  test('downloads usable assets once and refreshes both widgets', () async {
    final store = _FakeHomeWidgetStore();
    final downloader = _FakeHomeWidgetAssetDownloader();
    final synchronizer = HomeWidgetSynchronizer(
      store: store,
      downloader: downloader,
    );
    final snapshot = _completeSnapshot();

    await synchronizer.synchronize(snapshot);
    await synchronizer.synchronize(snapshot);

    expect(
      downloader.requestedUrls,
      unorderedEquals([
        'https://example.com/character.png',
        'https://example.com/recording.m4a',
        'https://example.com/card.png',
        'https://example.com/event.webp',
      ]),
    );
    expect(store.refreshedTargets, [
      HomeWidgetStorage.characterTarget,
      HomeWidgetStorage.cardTarget,
      HomeWidgetStorage.characterTarget,
      HomeWidgetStorage.cardTarget,
    ]);
    expect(
      store.values[HomeWidgetStorage.characterImageVersionKey],
      'character-v1',
    );
    expect(
      store.values[HomeWidgetStorage.recordingAudioVersionKey],
      'recording-id:1',
    );
    expect(
      store.values[HomeWidgetStorage.partnerCardImageVersionKey],
      'card-v1',
    );
    expect(
      store.values[HomeWidgetStorage.calendarEventArtworkVersionKey],
      'event-v1',
    );
    expect(store.values[HomeWidgetStorage.calendarEventTitleKey], '한강 산책');
    expect(
      store.values[HomeWidgetStorage.calendarEventAdditionalCountKey],
      '2',
    );
  });

  test('removes stored assets when shared data is unavailable', () async {
    final store = _FakeHomeWidgetStore()
      ..seedFile(HomeWidgetStorage.characterImagePathKey, _pngBytes)
      ..values[HomeWidgetStorage.characterImageVersionKey] = 'character-v1'
      ..seedFile(HomeWidgetStorage.recordingAudioPathKey, _m4aBytes)
      ..values[HomeWidgetStorage.recordingAudioVersionKey] = 'recording-v1'
      ..seedFile(HomeWidgetStorage.partnerCardImagePathKey, _pngBytes)
      ..values[HomeWidgetStorage.partnerCardImageVersionKey] = 'card-v1'
      ..seedFile(
        HomeWidgetStorage.calendarEventArtworkPathKey,
        _webpBytes,
        extension: 'webp',
      )
      ..values[HomeWidgetStorage.calendarEventArtworkVersionKey] = 'event-v1'
      ..values[HomeWidgetStorage.calendarEventTitleKey] = '한강 산책'
      ..values[HomeWidgetStorage.calendarEventAdditionalCountKey] = '2';
    final synchronizer = HomeWidgetSynchronizer(
      store: store,
      downloader: _FakeHomeWidgetAssetDownloader(),
    );

    await synchronizer.synchronize(null);

    expect(store.values, isEmpty);
    expect(store.files, isEmpty);
  });

  test('redownloads an asset when its cached file disappeared', () async {
    final store = _FakeHomeWidgetStore()
      ..values.addAll({
        HomeWidgetStorage.characterImagePathKey: '/missing.png',
        HomeWidgetStorage.characterImageVersionKey: 'character-v1',
      });
    final downloader = _FakeHomeWidgetAssetDownloader();
    final synchronizer = HomeWidgetSynchronizer(
      store: store,
      downloader: downloader,
    );

    await synchronizer.synchronize(
      HomeWidgetSnapshot(
        characterImage: HomeWidgetAssetUpdate.replace(_characterAsset),
        recordingAudio: const HomeWidgetAssetUpdate.preserve(),
        partnerCardImage: const HomeWidgetAssetUpdate.preserve(),
      ),
    );

    expect(downloader.requestedUrls, ['https://example.com/character.png']);
    final savedPath = store.values[HomeWidgetStorage.characterImagePathKey];
    expect(savedPath, isNot('/missing.png'));
    expect(store.files[savedPath], _pngBytes);
  });

  test(
    'confirms a locally uploaded recording revision without downloading it',
    () async {
      final store = _FakeHomeWidgetStore();
      final cacheRepository = HomeWidgetRecordingCacheRepository(store: store);
      await cacheRepository.installVerified(
        coupleId: 'couple-id',
        recordingId: 'recording-id',
        revision: 0,
        bytes: _m4aBytes,
      );
      final downloader = _FakeHomeWidgetAssetDownloader();
      final synchronizer = HomeWidgetSynchronizer(
        store: store,
        downloader: downloader,
        recordingCacheRepository: cacheRepository,
      );

      await synchronizer.synchronize(
        HomeWidgetSnapshot(
          characterImage: const HomeWidgetAssetUpdate.preserve(),
          recordingAudio: HomeWidgetAssetUpdate.replace(_recordingAsset),
          partnerCardImage: const HomeWidgetAssetUpdate.preserve(),
        ),
      );

      expect(downloader.requestedUrls, isEmpty);
      final manifest = HomeWidgetRecordingCacheManifest.tryParse(
        store.values[HomeWidgetStorage.recordingCacheManifestKey],
      );
      expect(manifest?.cachedRevision, 1);
      expect(
        store.values[HomeWidgetStorage.recordingAudioVersionKey],
        'recording-id:1',
      );
    },
  );

  test(
    'verifies a refresh-required cache without downloading the same recording',
    () async {
      final store = _FakeHomeWidgetStore();
      final cacheRepository = HomeWidgetRecordingCacheRepository(store: store);
      await cacheRepository.installVerified(
        coupleId: 'couple-id',
        recordingId: 'recording-id',
        revision: 1,
        bytes: _m4aBytes,
      );
      await cacheRepository.markRefreshRequired();
      final downloader = _FakeHomeWidgetAssetDownloader();
      final synchronizer = HomeWidgetSynchronizer(
        store: store,
        downloader: downloader,
        recordingCacheRepository: cacheRepository,
      );

      await synchronizer.synchronize(
        HomeWidgetSnapshot(
          characterImage: const HomeWidgetAssetUpdate.preserve(),
          recordingAudio: HomeWidgetAssetUpdate.replace(_recordingAsset),
          partnerCardImage: const HomeWidgetAssetUpdate.preserve(),
        ),
      );

      expect(downloader.requestedUrls, isEmpty);
      final manifest = await cacheRepository.read();
      expect(manifest?.freshness, HomeWidgetRecordingCacheFreshness.verified);
      expect(manifest?.cachedRecordingId, 'recording-id');
    },
  );

  test(
    'downloads a required recording and publishes a verified manifest',
    () async {
      final store = _FakeHomeWidgetStore();
      final cacheRepository = HomeWidgetRecordingCacheRepository(store: store);
      await cacheRepository.markRequired(
        coupleId: 'couple-id',
        recordingId: 'recording-id',
      );
      final downloader = _FakeHomeWidgetAssetDownloader();
      final synchronizer = HomeWidgetSynchronizer(
        store: store,
        downloader: downloader,
        recordingCacheRepository: cacheRepository,
      );

      await synchronizer.synchronize(
        HomeWidgetSnapshot(
          characterImage: const HomeWidgetAssetUpdate.preserve(),
          recordingAudio: HomeWidgetAssetUpdate.replace(_recordingAsset),
          partnerCardImage: const HomeWidgetAssetUpdate.preserve(),
        ),
      );

      expect(downloader.requestedUrls, ['https://example.com/recording.m4a']);
      final manifest = HomeWidgetRecordingCacheManifest.tryParse(
        store.values[HomeWidgetStorage.recordingCacheManifestKey],
      );
      expect(manifest?.freshness, HomeWidgetRecordingCacheFreshness.verified);
      expect(manifest?.cachedRecordingId, 'recording-id');
      expect(manifest?.cachedRevision, 1);
    },
  );

  test('rejects invalid image bytes without caching their version', () async {
    final store = _FakeHomeWidgetStore();
    final downloader = _FakeHomeWidgetAssetDownloader(
      responses: {
        'https://example.com/character.png': Uint8List.fromList([1, 2, 3]),
      },
    );
    final synchronizer = HomeWidgetSynchronizer(
      store: store,
      downloader: downloader,
    );

    await expectLater(
      synchronizer.synchronize(
        HomeWidgetSnapshot(
          characterImage: HomeWidgetAssetUpdate.replace(_characterAsset),
          recordingAudio: const HomeWidgetAssetUpdate.preserve(),
          partnerCardImage: const HomeWidgetAssetUpdate.preserve(),
        ),
      ),
      throwsA(isA<HomeWidgetSynchronizationException>()),
    );

    expect(store.values[HomeWidgetStorage.characterImageVersionKey], isNull);
  });

  test('validates WebP widget assets by their container signature', () {
    expect(isValidHomeWidgetAsset(_webpBytes, 'webp'), isTrue);
    expect(
      isValidHomeWidgetAsset(Uint8List.fromList([1, 2, 3]), 'webp'),
      isFalse,
    );
  });

  test(
    'preserves an existing asset after a recoverable source failure',
    () async {
      final store = _FakeHomeWidgetStore()
        ..seedFile(HomeWidgetStorage.characterImagePathKey, _pngBytes)
        ..values[HomeWidgetStorage.characterImageVersionKey] = 'character-v1';
      final downloader = _FakeHomeWidgetAssetDownloader();
      final synchronizer = HomeWidgetSynchronizer(
        store: store,
        downloader: downloader,
      );

      await synchronizer.synchronize(
        const HomeWidgetSnapshot(
          characterImage: HomeWidgetAssetUpdate.preserve(),
          recordingAudio: HomeWidgetAssetUpdate.preserve(),
          partnerCardImage: HomeWidgetAssetUpdate.preserve(),
        ),
      );

      expect(downloader.requestedUrls, isEmpty);
      expect(
        store.values[HomeWidgetStorage.characterImageVersionKey],
        'character-v1',
      );
    },
  );

  test(
    'preserves an existing calendar summary after a source failure',
    () async {
      final store = _FakeHomeWidgetStore()
        ..seedFile(
          HomeWidgetStorage.calendarEventArtworkPathKey,
          _webpBytes,
          extension: 'webp',
        )
        ..values[HomeWidgetStorage.calendarEventArtworkVersionKey] = 'event-v1'
        ..values[HomeWidgetStorage.calendarEventTitleKey] = '한강 산책'
        ..values[HomeWidgetStorage.calendarEventAdditionalCountKey] = '2';
      final synchronizer = HomeWidgetSynchronizer(
        store: store,
        downloader: _FakeHomeWidgetAssetDownloader(),
      );

      await synchronizer.synchronize(
        const HomeWidgetSnapshot(
          characterImage: HomeWidgetAssetUpdate.preserve(),
          recordingAudio: HomeWidgetAssetUpdate.preserve(),
          partnerCardImage: HomeWidgetAssetUpdate.preserve(),
          calendarSummary: HomeWidgetCalendarSummaryUpdate.preserve(),
        ),
      );

      expect(
        store.values[HomeWidgetStorage.calendarEventArtworkVersionKey],
        'event-v1',
      );
      expect(store.values[HomeWidgetStorage.calendarEventTitleKey], '한강 산책');
      expect(
        store.values[HomeWidgetStorage.calendarEventAdditionalCountKey],
        '2',
      );
    },
  );
}

HomeWidgetSnapshot _completeSnapshot() {
  return HomeWidgetSnapshot(
    characterImage: HomeWidgetAssetUpdate.replace(_characterAsset),
    recordingAudio: HomeWidgetAssetUpdate.replace(_recordingAsset),
    partnerCardImage: HomeWidgetAssetUpdate.replace(_cardAsset),
    calendarSummary: HomeWidgetCalendarSummaryUpdate.replace(
      HomeWidgetCalendarSummary(
        title: '한강 산책',
        additionalCount: 2,
        artwork: _eventAsset,
      ),
    ),
  );
}

const _characterAsset = HomeWidgetRemoteAsset(
  url: 'https://example.com/character.png',
  version: 'character-v1',
  extension: 'png',
);
const _recordingAsset = HomeWidgetRecordingRemoteAsset(
  url: 'https://example.com/recording.m4a',
  coupleId: 'couple-id',
  recordingId: 'recording-id',
  revision: 1,
);
const _cardAsset = HomeWidgetRemoteAsset(
  url: 'https://example.com/card.png',
  version: 'card-v1',
  extension: 'png',
);
const _eventAsset = HomeWidgetRemoteAsset(
  url: 'https://example.com/event.webp',
  version: 'event-v1',
  extension: 'webp',
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
  0x00,
  0x00,
  0x00,
  0x0D,
]);
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
final _webpBytes = Uint8List.fromList([
  0x52,
  0x49,
  0x46,
  0x46,
  0x04,
  0x00,
  0x00,
  0x00,
  0x57,
  0x45,
  0x42,
  0x50,
]);

class _FakeHomeWidgetAssetDownloader implements HomeWidgetAssetDownloader {
  _FakeHomeWidgetAssetDownloader({Map<String, Uint8List>? responses})
    : responses =
          responses ??
          {
            'https://example.com/character.png': _pngBytes,
            'https://example.com/recording.m4a': _m4aBytes,
            'https://example.com/card.png': _pngBytes,
            'https://example.com/event.webp': _webpBytes,
          };

  final Map<String, Uint8List> responses;
  final requestedUrls = <String>[];

  @override
  Future<Uint8List> download(String url, {required int maxBytes}) async {
    requestedUrls.add(url);
    final bytes = responses[url];
    if (bytes == null) {
      throw StateError('No fake response for $url');
    }
    return bytes;
  }
}

class _FakeHomeWidgetStore implements HomeWidgetStore {
  final values = <String, String>{};
  final files = <String, Uint8List>{};
  final refreshedTargets = <HomeWidgetTarget>[];

  void seedFile(String key, Uint8List bytes, {String? extension}) {
    final resolvedExtension =
        extension ?? (key.contains('audio') ? 'm4a' : 'png');
    final path = '/seed/$key.$resolvedExtension';
    values[key] = path;
    files[path] = bytes;
  }

  @override
  Future<bool> isFileUsable(String path, {required String extension}) async {
    final bytes = files[path];
    return bytes != null && isValidHomeWidgetAsset(bytes, extension);
  }

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> remove(String key) async {
    final previous = values.remove(key);
    if (previous != null && key.endsWith('_path')) {
      files.remove(previous);
    }
  }

  @override
  Future<String> saveFile({
    required String key,
    required Uint8List bytes,
    required String extension,
  }) async {
    final path = '/saved/$key.$extension';
    values[key] = path;
    files[path] = bytes;
    return path;
  }

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> refreshWidget(HomeWidgetTarget target) async {
    refreshedTargets.add(target);
  }
}
