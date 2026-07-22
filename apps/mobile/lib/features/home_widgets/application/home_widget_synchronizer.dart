import 'dart:io';

import 'package:flutter/foundation.dart';

import '../data/home_widget_asset_validator.dart';
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
  const HomeWidgetSynchronizer({
    required HomeWidgetStore store,
    required HomeWidgetAssetDownloader downloader,
  }) : _store = store,
       _downloader = downloader;

  final HomeWidgetStore _store;
  final HomeWidgetAssetDownloader _downloader;

  Future<void> synchronize(HomeWidgetSnapshot? snapshot) async {
    final updates = await Future.wait([
      _synchronizeAsset(
        update:
            snapshot?.characterImage ?? const HomeWidgetAssetUpdate.remove(),
        pathKey: HomeWidgetStorage.characterImagePathKey,
        versionKey: HomeWidgetStorage.characterImageVersionKey,
      ),
      _synchronizeAsset(
        update:
            snapshot?.recordingAudio ?? const HomeWidgetAssetUpdate.remove(),
        pathKey: HomeWidgetStorage.recordingAudioPathKey,
        versionKey: HomeWidgetStorage.recordingAudioVersionKey,
      ),
      _synchronizeAsset(
        update:
            snapshot?.partnerCardImage ?? const HomeWidgetAssetUpdate.remove(),
        pathKey: HomeWidgetStorage.partnerCardImagePathKey,
        versionKey: HomeWidgetStorage.partnerCardImageVersionKey,
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

class HomeWidgetSynchronizationException implements Exception {
  const HomeWidgetSynchronizationException(this.failedOperations);

  final List<String> failedOperations;

  @override
  String toString() {
    return 'Home widget synchronization failed: '
        '${failedOperations.join(', ')}';
  }
}
