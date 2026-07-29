import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

import '../../tool/store_asset_validator.dart';

void main() {
  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('store-assets-'));
  tearDown(() => root.deleteSync(recursive: true));

  test('accepts the complete canonical store asset layout', () async {
    await _createCompleteLayout(root);

    final report = await StoreAssetValidator(
      repositoryRoot: root,
      rasterReader: _fixtureRaster,
    ).validate(appVersion: '1.0.0');

    expect(report.errors, isEmpty);
    expect(report.validatedFileCount, 30);
  });

  test('reports missing asset groups without duplicate scene errors', () async {
    final report = await StoreAssetValidator(
      repositoryRoot: root,
      rasterReader: _fixtureRaster,
    ).validate(appVersion: '1.0.0');

    expect(report.errors, hasLength(6));
    expect(report.errors.where((error) => error.contains('[scene]')), isEmpty);
    expect(report.errors.join('\n'), contains('feature-graphic.png [missing]'));
    expect(report.errors.join('\n'), contains('google-play/phone [count]'));
    expect(report.errors.join('\n'), contains('app-store/ipad-13 [count]'));
  });

  test('rejects invalid screenshot naming and alpha channels', () async {
    await _touch(root, 'store-assets/google-play/phone/phone.png');

    final report = await StoreAssetValidator(
      repositoryRoot: root,
      rasterReader: (_) async => const RasterInfo(
        format: 'png',
        width: 1080,
        height: 1920,
        hasAlpha: true,
        byteLength: 1,
      ),
    ).validate(appVersion: '1.0.0');

    expect(report.errors.join('\n'), contains('[filename]'));
    expect(report.errors.join('\n'), contains('[alpha]'));
  });

  test('reads PNG dimensions and alpha-channel information', () async {
    final opaque = File('${root.path}/opaque.png')
      ..writeAsBytesSync(
        image.encodePng(image.Image(width: 2, height: 3, numChannels: 3)),
      );
    final alpha = File('${root.path}/alpha.png')
      ..writeAsBytesSync(
        image.encodePng(image.Image(width: 4, height: 5, numChannels: 4)),
      );

    final opaqueInfo = await readRasterInfo(opaque);
    final alphaInfo = await readRasterInfo(alpha);

    expect((opaqueInfo.width, opaqueInfo.height), (2, 3));
    expect(opaqueInfo.hasAlpha, isFalse);
    expect(alphaInfo.hasAlpha, isTrue);
  });
}

Future<void> _createCompleteLayout(Directory root) async {
  await _touch(root, 'store-assets/google-play/app-icon-512.png');
  await _touch(root, 'store-assets/google-play/feature-graphic.png');
  await _createGroup(root, 'google-play/phone', 'android-phone', _scenes);
  await _createGroup(root, 'google-play/tablet', 'android-tablet', const [
    'home',
    'calendar',
    'ai',
    'settings',
  ]);
  await _createGroup(root, 'app-store/iphone-6.9', 'ios-iphone-6.9', _scenes);
  await _createGroup(root, 'app-store/ipad-13', 'ios-ipad-13', _scenes);
}

Future<void> _createGroup(
  Directory root,
  String directory,
  String prefix,
  List<String> scenes,
) async {
  for (var index = 0; index < scenes.length; index += 1) {
    final order = (index + 1).toString().padLeft(2, '0');
    await _touch(
      root,
      'store-assets/$directory/'
      '$prefix-$order-${scenes[index]}-1.0.0-abcdef1.png',
    );
  }
}

Future<void> _touch(Directory root, String relativePath) async {
  final file = File(
    '${root.path}${Platform.pathSeparator}'
    '${relativePath.replaceAll('/', Platform.pathSeparator)}',
  );
  await file.create(recursive: true);
  await file.writeAsBytes(const [0]);
}

Future<RasterInfo> _fixtureRaster(File file) async {
  final path = file.path.replaceAll(Platform.pathSeparator, '/');
  if (path.endsWith('app-icon-512.png')) {
    return _raster(512, 512, hasAlpha: true);
  }
  if (path.endsWith('feature-graphic.png')) {
    return _raster(1024, 500);
  }
  if (path.contains('/google-play/phone/')) {
    return _raster(1080, 1920);
  }
  if (path.contains('/google-play/tablet/')) {
    return _raster(1920, 1080);
  }
  if (path.contains('/app-store/iphone-6.9/')) {
    return _raster(1260, 2736);
  }
  return _raster(2048, 2732);
}

RasterInfo _raster(int width, int height, {bool hasAlpha = false}) {
  return RasterInfo(
    format: 'png',
    width: width,
    height: height,
    hasAlpha: hasAlpha,
    byteLength: 1,
  );
}

const _scenes = <String>[
  'home',
  'card-editor',
  'question-answer',
  'calendar',
  'recording-library',
  'ai',
  'widgets',
  'settings',
];
