import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';

import 'story_card_download_failure.dart';

final storyCardGalleryWriterProvider = Provider<StoryCardGalleryWriter>((ref) {
  return const GalStoryCardGalleryWriter();
});

abstract interface class StoryCardGalleryWriter {
  Future<void> save({required Uint8List bytes, required String fileName});
}

class GalStoryCardGalleryWriter implements StoryCardGalleryWriter {
  const GalStoryCardGalleryWriter();

  @override
  Future<void> save({
    required Uint8List bytes,
    required String fileName,
  }) async {
    try {
      final hasAccess = await Gal.hasAccess();
      final canSave = hasAccess || await Gal.requestAccess();
      if (!canSave) {
        throw const StoryCardDownloadException(
          StoryCardDownloadFailureReason.accessDenied,
        );
      }

      await Gal.putImageBytes(bytes, name: fileName);
    } on StoryCardDownloadException {
      rethrow;
    } on GalException catch (error) {
      throw StoryCardDownloadException(
        _mapGalFailure(error.type),
        error.toString(),
      );
    } catch (error) {
      throw StoryCardDownloadException(
        StoryCardDownloadFailureReason.unknown,
        error.toString(),
      );
    }
  }

  StoryCardDownloadFailureReason _mapGalFailure(GalExceptionType type) {
    if (type == GalExceptionType.accessDenied) {
      return StoryCardDownloadFailureReason.accessDenied;
    }
    if (type == GalExceptionType.notEnoughSpace) {
      return StoryCardDownloadFailureReason.notEnoughSpace;
    }
    if (type == GalExceptionType.notSupportedFormat) {
      return StoryCardDownloadFailureReason.notSupported;
    }
    return StoryCardDownloadFailureReason.unknown;
  }
}
