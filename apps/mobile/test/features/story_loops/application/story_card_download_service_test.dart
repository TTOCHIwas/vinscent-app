import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/story_loops/application/story_card_download_service.dart';
import 'package:vinscent/features/story_loops/application/story_card_high_resolution_renderer.dart';
import 'package:vinscent/features/story_loops/data/story_card_download_repository.dart';
import 'package:vinscent/features/story_loops/data/story_card_download_source.dart';
import 'package:vinscent/features/story_loops/data/story_card_gallery_writer.dart';
import 'package:vinscent/features/story_loops/data/story_card_scene.dart';

void main() {
  test('downloads source, renders it, then saves the rendered bytes', () async {
    final source = StoryCardDownloadSource(
      scene: StoryCardScene.empty(),
      backgroundImageBytes: null,
    );
    final repository = _FakeDownloadRepository(source);
    final renderer = _FakeImageRenderer(Uint8List.fromList([1, 2, 3]));
    final galleryWriter = _FakeGalleryWriter();
    final service = StoryCardDownloadService(
      repository: repository,
      renderer: renderer,
      galleryWriter: galleryWriter,
    );

    await service.download('card-1');

    expect(repository.cardIds, ['card-1']);
    expect(renderer.sources, [same(source)]);
    expect(galleryWriter.savedBytes, [renderer.output]);
    expect(galleryWriter.fileNames, ['vinscent-card-card-1']);
  });
}

class _FakeDownloadRepository implements StoryCardDownloadRepository {
  _FakeDownloadRepository(this.source);

  final StoryCardDownloadSource source;
  final cardIds = <String>[];

  @override
  Future<StoryCardDownloadSource> fetch(String cardId) async {
    cardIds.add(cardId);
    return source;
  }
}

class _FakeImageRenderer implements StoryCardImageRenderer {
  _FakeImageRenderer(this.output);

  final Uint8List output;
  final sources = <StoryCardDownloadSource>[];

  @override
  Future<Uint8List> render(StoryCardDownloadSource source) async {
    sources.add(source);
    return output;
  }
}

class _FakeGalleryWriter implements StoryCardGalleryWriter {
  final savedBytes = <Uint8List>[];
  final fileNames = <String>[];

  @override
  Future<void> save({
    required Uint8List bytes,
    required String fileName,
  }) async {
    savedBytes.add(bytes);
    fileNames.add(fileName);
  }
}
