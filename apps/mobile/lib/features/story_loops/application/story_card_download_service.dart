import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/story_card_download_repository.dart';
import '../data/story_card_gallery_writer.dart';
import 'story_card_high_resolution_renderer.dart';

final storyCardImageRendererProvider = Provider<StoryCardImageRenderer>((ref) {
  return const StoryCardHighResolutionRenderer();
});

final storyCardDownloaderProvider = Provider<StoryCardDownloader>((ref) {
  return StoryCardDownloadService(
    repository: ref.watch(storyCardDownloadRepositoryProvider),
    renderer: ref.watch(storyCardImageRendererProvider),
    galleryWriter: ref.watch(storyCardGalleryWriterProvider),
  );
});

abstract interface class StoryCardDownloader {
  Future<void> download(String cardId);
}

class StoryCardDownloadService implements StoryCardDownloader {
  const StoryCardDownloadService({
    required this.repository,
    required this.renderer,
    required this.galleryWriter,
  });

  final StoryCardDownloadRepository repository;
  final StoryCardImageRenderer renderer;
  final StoryCardGalleryWriter galleryWriter;

  @override
  Future<void> download(String cardId) async {
    final source = await repository.fetch(cardId);
    final output = await renderer.render(source);
    final safeCardId = cardId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    await galleryWriter.save(
      bytes: output,
      fileName: 'vinscent-card-$safeCardId',
    );
  }
}
