import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

import 'story_card_image_normalizer.dart';

class StoryCardGalleryPicker {
  StoryCardGalleryPicker({
    ImagePicker? imagePicker,
    StoryCardImageNormalizer imageNormalizer = const StoryCardImageNormalizer(),
  }) : _imagePicker = imagePicker ?? ImagePicker(),
       _imageNormalizer = imageNormalizer;

  final ImagePicker _imagePicker;
  final StoryCardImageNormalizer _imageNormalizer;

  Future<List<Uint8List>> pickNormalizedImages({required int limit}) async {
    if (limit < 1) {
      return const [];
    }
    final files = await _imagePicker.pickMultiImage(
      limit: limit,
      imageQuality: 90,
      maxWidth: 2048,
      maxHeight: 2048,
      requestFullMetadata: false,
    );
    final images = <Uint8List>[];
    for (final file in files) {
      images.add(await _imageNormalizer.normalize(await file.readAsBytes()));
    }
    return images;
  }
}
