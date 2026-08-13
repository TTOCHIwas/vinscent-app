import 'dart:io';

import 'package:flutter/foundation.dart';

import '../data/home_widget_asset_validator.dart';
import '../data/home_widget_recording_cache_manifest.dart';
import '../data/home_widget_recording_cache_repository.dart';
import '../data/home_widget_snapshot.dart';

abstract interface class HomeWidgetAssetDownloader {
  Future<Uint8List> download(String url, {required int maxBytes});
}

abstract interface class HomeWidgetStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> remove(String key);

  Future<String> saveFile({
    required String key,
    required Uint8List bytes,
    required String extension,
  });

  Future<bool> isFileUsable(String path, {required String extension});

  Future<void> refreshWidget(HomeWidgetTarget target);
}

class HomeWidgetSynchronizer {
  HomeWidgetSynchronizer({
    required HomeWidgetStore store,
    required HomeWidgetAssetDownloader downloader,
    HomeWidgetRecordingCacheRepository? recordingCacheRepository,
  }) : _store = store,
       _downloader = downloader,
       _recordingCacheRepository =
           recordingCacheRepository ??
           HomeWidgetRecordingCacheRepository(store: store);

  final HomeWidgetStore _store;
  final HomeWidgetAssetDownloader _downloader;
  final HomeWidgetRecordingCacheRepository _recordingCacheRepository;

  Future<HomeWidgetRecordingReadFence> captureRecordingReadFence() async {
    return HomeWidgetRecordingReadFence(await _recordingCacheRepository.read());
  }

  Future<void> synchronize(
    HomeWidgetSnapshot? snapshot, {
    HomeWidgetRecordingReadFence? recordingReadFence,
  }) async {
    final updates = await Future.wait([
      _synchronizeAsset(
        update:
            snapshot?.characterImage ?? const HomeWidgetAssetUpdate.remove(),
        pathKey: HomeWidgetStorage.characterImagePathKey,
        versionKey: HomeWidgetStorage.characterImageVersionKey,
      ),
      _synchronizeRecordingAsset(
        update:
            snapshot?.recordingAudio ?? const HomeWidgetAssetUpdate.remove(),
        readFence: recordingReadFence,
      ),
      _synchronizeAsset(
        update:
            snapshot?.partnerCardImage ?? const HomeWidgetAssetUpdate.remove(),
        pathKey: HomeWidgetStorage.partnerCardImagePathKey,
        versionKey: HomeWidgetStorage.partnerCardImageVersionKey,
      ),
      _synchronizeCalendarSummary(
        snapshot?.calendarSummary ??
            const HomeWidgetCalendarSummaryUpdate.remove(),
      ),
    ]);

    final refreshes = await Future.wait([
      _refreshWidget(HomeWidgetStorage.characterTarget),
      _refreshWidget(HomeWidgetStorage.cardTarget),
    ]);
    final failedOperations = <String>[
      for (var index = 0; index < updates.length; index++)
        if (!updates[index]) 'asset-$index',
      for (var index = 0; index < refreshes.length; index++)
        if (!refreshes[index]) 'refresh-$index',
    ];
    if (failedOperations.isNotEmpty) {
      throw HomeWidgetSynchronizationException(failedOperations);
    }
  }

  Future<void> synchronizeRecording(
    HomeWidgetAssetUpdate update, {
    HomeWidgetRecordingReadFence? recordingReadFence,
  }) async {
    final updated = await _synchronizeRecordingAsset(
      update: update,
      readFence: recordingReadFence,
    );
    final refreshed = await _refreshWidget(HomeWidgetStorage.characterTarget);
    final failedOperations = <String>[
      if (!updated) 'recording-asset',
      if (!refreshed) 'recording-refresh',
    ];
    if (failedOperations.isNotEmpty) {
      throw HomeWidgetSynchronizationException(failedOperations);
    }
  }

  Future<bool> _synchronizeCalendarSummary(
    HomeWidgetCalendarSummaryUpdate update,
  ) async {
    if (update.type == HomeWidgetCalendarSummaryUpdateType.preserve) {
      return true;
    }

    try {
      if (update.type == HomeWidgetCalendarSummaryUpdateType.remove) {
        final artworkRemoved = await _synchronizeAsset(
          update: const HomeWidgetAssetUpdate.remove(),
          pathKey: HomeWidgetStorage.calendarEventArtworkPathKey,
          versionKey: HomeWidgetStorage.calendarEventArtworkVersionKey,
        );
        await _store.remove(HomeWidgetStorage.calendarEventTitleKey);
        await _store.remove(HomeWidgetStorage.calendarEventAdditionalCountKey);
        return artworkRemoved;
      }

      final summary = update.summary!;
      final artworkUpdated = await _synchronizeAsset(
        update: summary.artwork == null
            ? const HomeWidgetAssetUpdate.remove()
            : HomeWidgetAssetUpdate.replace(summary.artwork),
        pathKey: HomeWidgetStorage.calendarEventArtworkPathKey,
        versionKey: HomeWidgetStorage.calendarEventArtworkVersionKey,
      );
      if (!artworkUpdated) {
        return false;
      }
      await _store.write(
        HomeWidgetStorage.calendarEventTitleKey,
        summary.title,
      );
      await _store.write(
        HomeWidgetStorage.calendarEventAdditionalCountKey,
        summary.additionalCount.toString(),
      );
      return true;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[widget] calendar summary synchronization failed: $error');
      }
      return false;
    }
  }

  Future<bool> _synchronizeRecordingAsset({
    required HomeWidgetAssetUpdate update,
    HomeWidgetRecordingReadFence? readFence,
  }) async {
    if (update.type == HomeWidgetAssetUpdateType.preserve) {
      return true;
    }

    try {
      if (update.type == HomeWidgetAssetUpdateType.remove) {
        if (readFence == null) {
          await _recordingCacheRepository.clear();
          return true;
        }
        return _recordingCacheRepository.clearIfUnchanged(
          expected: readFence.manifest,
        );
      }

      final asset = update.asset;
      if (asset is! HomeWidgetRecordingRemoteAsset) {
        throw const FormatException('Recording widget asset metadata missing');
      }

      if (await _recordingCacheRepository.confirmVerifiedRevision(
        coupleId: asset.coupleId,
        recordingId: asset.recordingId,
        revision: asset.revision,
      )) {
        return true;
      }

      final expected =
          readFence?.manifest ?? await _recordingCacheRepository.read();
      final bytes = await _downloader.download(
        asset.url,
        maxBytes: asset.maxBytes,
      );
      return _recordingCacheRepository.installFetched(
        coupleId: asset.coupleId,
        recordingId: asset.recordingId,
        revision: asset.revision,
        bytes: bytes,
        expected: expected,
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[widget] recording synchronization failed: $error');
      }
      return false;
    }
  }

  Future<bool> _synchronizeAsset({
    required HomeWidgetAssetUpdate update,
    required String pathKey,
    required String versionKey,
  }) async {
    if (update.type == HomeWidgetAssetUpdateType.preserve) {
      return true;
    }

    try {
      if (update.type == HomeWidgetAssetUpdateType.remove) {
        await _store.remove(pathKey);
        await _store.remove(versionKey);
        return true;
      }

      final asset = update.asset!;
      final currentVersion = await _store.read(versionKey);
      final currentPath = await _store.read(pathKey);
      if (currentVersion == asset.version &&
          currentPath != null &&
          await _store.isFileUsable(currentPath, extension: asset.extension)) {
        return true;
      }

      final bytes = await _downloader.download(
        asset.url,
        maxBytes: asset.maxBytes,
      );
      if (!isValidHomeWidgetAsset(bytes, asset.extension)) {
        throw FormatException(
          'Invalid ${asset.extension} payload for $pathKey',
        );
      }
      final savedPath = await _store.saveFile(
        key: pathKey,
        bytes: bytes,
        extension: asset.extension,
      );
      if (!await _store.isFileUsable(savedPath, extension: asset.extension)) {
        throw FileSystemException('Saved widget asset is unusable', savedPath);
      }
      await _store.write(versionKey, asset.version);
      return true;
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          '[widget] asset synchronization failed for $pathKey: $error',
        );
      }
      return false;
    }
  }

  Future<bool> _refreshWidget(HomeWidgetTarget target) async {
    try {
      await _store.refreshWidget(target);
      return true;
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          '[widget] widget refresh failed for ${target.iOSName}: $error',
        );
      }
      return false;
    }
  }
}

class HomeWidgetRecordingReadFence {
  const HomeWidgetRecordingReadFence(this.manifest);

  final HomeWidgetRecordingCacheManifest? manifest;
}

class HomeWidgetSynchronizationException implements Exception {
  const HomeWidgetSynchronizationException(this.failedOperations);

  final List<String> failedOperations;

  @override
  String toString() {
    return 'Home widget synchronization failed: '
        '${failedOperations.join(', ')}';
  }
}
