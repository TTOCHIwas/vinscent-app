import 'dart:typed_data';

import '../data/home_widget_snapshot.dart';

abstract interface class HomeWidgetAssetDownloader {
  Future<Uint8List> download(String url, {required int maxBytes});
}

abstract interface class HomeWidgetStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> remove(String key);

  Future<void> saveFile({
    required String key,
    required Uint8List bytes,
    required String extension,
  });

  Future<void> updateAndroidWidget(String qualifiedProviderName);
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
    await Future.wait([
      _synchronizeAsset(
        asset: snapshot?.characterImage,
        pathKey: HomeWidgetStorage.characterImagePathKey,
        versionKey: HomeWidgetStorage.characterImageVersionKey,
      ),
      _synchronizeAsset(
        asset: snapshot?.recordingAudio,
        pathKey: HomeWidgetStorage.recordingAudioPathKey,
        versionKey: HomeWidgetStorage.recordingAudioVersionKey,
      ),
      _synchronizeAsset(
        asset: snapshot?.partnerCardImage,
        pathKey: HomeWidgetStorage.partnerCardImagePathKey,
        versionKey: HomeWidgetStorage.partnerCardImageVersionKey,
      ),
    ]);

    await _store.updateAndroidWidget(
      HomeWidgetStorage.characterAndroidProvider,
    );
    await _store.updateAndroidWidget(HomeWidgetStorage.cardAndroidProvider);
  }

  Future<void> _synchronizeAsset({
    required HomeWidgetRemoteAsset? asset,
    required String pathKey,
    required String versionKey,
  }) async {
    if (asset == null) {
      await _store.remove(pathKey);
      await _store.remove(versionKey);
      return;
    }

    final currentVersion = await _store.read(versionKey);
    final currentPath = await _store.read(pathKey);
    if (currentVersion == asset.version && currentPath != null) {
      return;
    }

    try {
      final bytes = await _downloader.download(
        asset.url,
        maxBytes: asset.maxBytes,
      );
      await _store.saveFile(
        key: pathKey,
        bytes: bytes,
        extension: asset.extension,
      );
      await _store.write(versionKey, asset.version);
    } catch (_) {
      return;
    }
  }
}
