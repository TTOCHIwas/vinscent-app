import 'dart:typed_data';

import 'package:image/image.dart' as image;

class StoryCardImageNormalizer {
  const StoryCardImageNormalizer();

  static const _maximumDimension = 2048;
  static const _minimumResizeDimension = 960;
  static const _maximumEncodedBytes = 5 * 1024 * 1024;

  Future<Uint8List> normalize(Uint8List source) async {
    final image.Image? decoded;
    try {
      decoded = image.decodeImage(source);
    } catch (_) {
      throw const FormatException('Unsupported image format.');
    }
    if (decoded == null) {
      throw const FormatException('Unsupported image format.');
    }

    var normalized = image.bakeOrientation(decoded);
    if (normalized.width > _maximumDimension ||
        normalized.height > _maximumDimension) {
      normalized = normalized.width >= normalized.height
          ? image.copyResize(normalized, width: _maximumDimension)
          : image.copyResize(normalized, height: _maximumDimension);
    }

    var encoded = Uint8List.fromList(image.encodeJpg(normalized, quality: 88));
    while (encoded.length > _maximumEncodedBytes &&
        normalized.width > _minimumResizeDimension &&
        normalized.height > _minimumResizeDimension) {
      normalized = image.copyResize(
        normalized,
        width: (normalized.width * 0.8).round(),
        height: (normalized.height * 0.8).round(),
      );
      encoded = Uint8List.fromList(image.encodeJpg(normalized, quality: 82));
    }

    if (encoded.length > _maximumEncodedBytes) {
      throw const FormatException('Image is too large.');
    }

    return encoded;
  }
}
