import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/home_widgets/application/home_widget_synchronizer.dart';
import 'package:vinscent/features/home_widgets/data/home_widget_snapshot.dart';

void main() {
  test('새 자산만 내려받고 두 Android 위젯을 갱신한다', () async {
    final store = _FakeHomeWidgetStore();
    final downloader = _FakeHomeWidgetAssetDownloader();
    final synchronizer = HomeWidgetSynchronizer(
      store: store,
      downloader: downloader,
    );
    final snapshot = HomeWidgetSnapshot(
      characterImage: const HomeWidgetRemoteAsset(
        url: 'https://example.com/character.png',
        version: 'character-v1',
        extension: 'png',
      ),
      recordingAudio: const HomeWidgetRemoteAsset(
        url: 'https://example.com/recording.m4a',
        version: 'recording-v1',
        extension: 'm4a',
      ),
      partnerCardImage: const HomeWidgetRemoteAsset(
        url: 'https://example.com/card.png',
        version: 'card-v1',
        extension: 'png',
      ),
    );

    await synchronizer.synchronize(snapshot);
    await synchronizer.synchronize(snapshot);

    expect(downloader.requestedUrls, [
      'https://example.com/character.png',
      'https://example.com/recording.m4a',
      'https://example.com/card.png',
    ]);
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
      'recording-v1',
    );
    expect(
      store.values[HomeWidgetStorage.partnerCardImageVersionKey],
      'card-v1',
    );
  });

  test('연결 데이터가 없으면 기존 파일과 버전을 모두 제거한다', () async {
    final store = _FakeHomeWidgetStore()
      ..values.addAll({
        HomeWidgetStorage.characterImagePathKey: '/character.png',
        HomeWidgetStorage.characterImageVersionKey: 'character-v1',
        HomeWidgetStorage.recordingAudioPathKey: '/recording.m4a',
        HomeWidgetStorage.recordingAudioVersionKey: 'recording-v1',
        HomeWidgetStorage.partnerCardImagePathKey: '/card.png',
        HomeWidgetStorage.partnerCardImageVersionKey: 'card-v1',
      });
    final synchronizer = HomeWidgetSynchronizer(
      store: store,
      downloader: _FakeHomeWidgetAssetDownloader(),
    );

    await synchronizer.synchronize(null);

    expect(store.values, isEmpty);
    expect(store.removedFilePaths, {
      '/character.png',
      '/recording.m4a',
      '/card.png',
    });
  });
}

class _FakeHomeWidgetAssetDownloader implements HomeWidgetAssetDownloader {
  final requestedUrls = <String>[];

  @override
  Future<Uint8List> download(String url, {required int maxBytes}) async {
    requestedUrls.add(url);
    return Uint8List.fromList([1, 2, 3]);
  }
}

class _FakeHomeWidgetStore implements HomeWidgetStore {
  final values = <String, String>{};
  final removedFilePaths = <String>{};
  final refreshedTargets = <HomeWidgetTarget>[];

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> remove(String key) async {
    final previous = values.remove(key);
    if (previous != null && key.endsWith('_path')) {
      removedFilePaths.add(previous);
    }
  }

  @override
  Future<void> saveFile({
    required String key,
    required Uint8List bytes,
    required String extension,
  }) async {
    values[key] = '/$key.$extension';
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
