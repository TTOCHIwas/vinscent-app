import 'dart:typed_data';

bool isValidHomeWidgetAsset(Uint8List bytes, String extension) {
  if (bytes.isEmpty) {
    return false;
  }

  return switch (extension.toLowerCase()) {
    'png' => _hasPrefix(bytes, const [
      0x89,
      0x50,
      0x4E,
      0x47,
      0x0D,
      0x0A,
      0x1A,
      0x0A,
    ]),
    'webp' =>
      bytes.length >= 12 &&
          _hasPrefix(bytes, const [0x52, 0x49, 0x46, 0x46]) &&
          bytes[8] == 0x57 &&
          bytes[9] == 0x45 &&
          bytes[10] == 0x42 &&
          bytes[11] == 0x50,
    'm4a' =>
      bytes.length >= 12 &&
          bytes[4] == 0x66 &&
          bytes[5] == 0x74 &&
          bytes[6] == 0x79 &&
          bytes[7] == 0x70,
    _ => false,
  };
}

bool _hasPrefix(Uint8List bytes, List<int> prefix) {
  if (bytes.length < prefix.length) {
    return false;
  }

  for (var index = 0; index < prefix.length; index++) {
    if (bytes[index] != prefix[index]) {
      return false;
    }
  }
  return true;
}
