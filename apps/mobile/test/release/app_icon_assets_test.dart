import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Android app icons', () {
    test('legacy launcher icons match Android density sizes', () {
      for (final entry in _androidLegacyIconSizes.entries) {
        final icon = File(
          'android/app/src/main/res/mipmap-${entry.key}/ic_launcher.png',
        );

        expect(icon.existsSync(), isTrue, reason: icon.path);
        expect(_readPng(icon).size, (
          width: entry.value,
          height: entry.value,
        ), reason: icon.path);
      }
    });

    test('adaptive launcher icon has complete density layers', () {
      final adaptiveIcon = File(
        'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml',
      );
      final xml = adaptiveIcon.readAsStringSync();

      expect(xml, contains('@color/ic_launcher_background'));
      expect(xml, contains('@drawable/ic_launcher_foreground'));
      expect(xml, contains('@drawable/ic_launcher_monochrome'));

      for (final entry in _androidAdaptiveIconSizes.entries) {
        for (final layer in ['foreground', 'monochrome']) {
          final icon = File(
            'android/app/src/main/res/drawable-${entry.key}/'
            'ic_launcher_$layer.png',
          );

          expect(icon.existsSync(), isTrue, reason: icon.path);
          expect(_readPng(icon).size, (
            width: entry.value,
            height: entry.value,
          ), reason: icon.path);
        }
      }
    });

    test('adaptive launcher icon keeps the intended white background', () {
      final colors = File(
        'android/app/src/main/res/values/colors.xml',
      ).readAsStringSync();

      expect(
        colors,
        contains('<color name="ic_launcher_background">#FFFFFF</color>'),
      );
    });
  });

  test('Google Play icon matches store asset requirements', () {
    final icon = File('../../store-assets/google-play/app-icon-512.png');

    expect(icon.existsSync(), isTrue, reason: icon.path);
    final png = _readPng(icon);
    expect(png.size, (width: 512, height: 512));
    expect(png.colorType, _truecolorWithAlpha);
    expect(icon.lengthSync(), lessThanOrEqualTo(1024 * 1024));
  });

  group('iOS app icons', () {
    final iconDirectory = Directory(
      'ios/Runner/Assets.xcassets/AppIcon.appiconset',
    );
    final contents =
        jsonDecode(
              File('${iconDirectory.path}/Contents.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    final images = (contents['images'] as List<dynamic>)
        .cast<Map<String, dynamic>>();

    test('every AppIcon slot references an image with the expected size', () {
      for (final image in images) {
        final filename = image['filename'] as String?;

        expect(filename, isNotNull, reason: image.toString());
        final icon = File('${iconDirectory.path}/$filename');
        expect(icon.existsSync(), isTrue, reason: icon.path);

        final expected = _expectedIosIconSize(image);
        expect(_readPng(icon).size, expected, reason: icon.path);
      }
    });

    test('App Store marketing icon is opaque', () {
      final marketingSlot = images.singleWhere(
        (image) => image['idiom'] == 'ios-marketing',
      );
      final icon = File('${iconDirectory.path}/${marketingSlot['filename']}');
      final png = _readPng(icon);

      expect(png.size, (width: 1024, height: 1024));
      expect(png.hasTransparency, isFalse);
    });
  });
}

const _androidLegacyIconSizes = <String, int>{
  'mdpi': 48,
  'hdpi': 72,
  'xhdpi': 96,
  'xxhdpi': 144,
  'xxxhdpi': 192,
};

const _androidAdaptiveIconSizes = <String, int>{
  'mdpi': 108,
  'hdpi': 162,
  'xhdpi': 216,
  'xxhdpi': 324,
  'xxxhdpi': 432,
};

({int width, int height}) _expectedIosIconSize(Map<String, dynamic> image) {
  final logicalSize = (image['size'] as String).split('x');
  final scale = double.parse((image['scale'] as String).replaceFirst('x', ''));

  return (
    width: (double.parse(logicalSize[0]) * scale).round(),
    height: (double.parse(logicalSize[1]) * scale).round(),
  );
}

_PngInfo _readPng(File file) {
  final bytes = file.readAsBytesSync();
  const signature = <int>[137, 80, 78, 71, 13, 10, 26, 10];

  if (bytes.length < 33 ||
      !_listEquals(bytes.sublist(0, signature.length), signature)) {
    throw FormatException('Invalid PNG: ${file.path}');
  }

  final data = ByteData.sublistView(bytes);
  final colorType = bytes[25];
  var offset = 8;
  var hasTransparencyChunk = false;

  while (offset + 12 <= bytes.length) {
    final length = data.getUint32(offset);
    final type = ascii.decode(bytes.sublist(offset + 4, offset + 8));

    if (type == 'tRNS') {
      hasTransparencyChunk = true;
    }
    offset += 12 + length;
    if (type == 'IEND') {
      break;
    }
  }

  return _PngInfo(
    width: data.getUint32(16),
    height: data.getUint32(20),
    colorType: colorType,
    hasTransparency:
        colorType == _grayscaleWithAlpha ||
        colorType == _truecolorWithAlpha ||
        hasTransparencyChunk,
  );
}

bool _listEquals(List<int> left, List<int> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}

const _grayscaleWithAlpha = 4;
const _truecolorWithAlpha = 6;

final class _PngInfo {
  const _PngInfo({
    required this.width,
    required this.height,
    required this.colorType,
    required this.hasTransparency,
  });

  final int width;
  final int height;
  final int colorType;
  final bool hasTransparency;

  ({int width, int height}) get size => (width: width, height: height);
}
