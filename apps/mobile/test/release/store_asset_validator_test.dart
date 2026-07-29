import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

import '../../tool/store_asset_alt_text_validator.dart';
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
    expect(report.validatedFileCount, 31);
  });

  test('reports missing asset groups without duplicate scene errors', () async {
    final report = await StoreAssetValidator(
      repositoryRoot: root,
      rasterReader: _fixtureRaster,
    ).validate(appVersion: '1.0.0');

    expect(report.errors, hasLength(7));
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

  test('rejects incomplete or overlong Play alt text', () async {
    final manifest = _file(root, StoreAssetAltTextValidator.manifestPath);
    await manifest.create(recursive: true);
    final overlongText = List.filled(141, '가').join();
    await manifest.writeAsString('''
{
  "featureGraphic": "$overlongText",
  "phone": {},
  "tablet": {
    "home": "홈",
    "calendar": "캘린더",
    "ai": "AI",
    "settings": "설정",
    "card-editor": "태블릿 카드 편집",
    "unknown": "잘못된 키"
  }
}
''');

    final errors = const StoreAssetAltTextValidator().validate(manifest);

    expect(errors.join('\n'), contains('[length]'));
    expect(errors.join('\n'), contains('phone.home'));
    expect(errors.join('\n'), contains('tablet.unknown'));
    expect(errors.join('\n'), isNot(contains('tablet.card-editor')));
  });

  test('requires alt text for optional Play tablet scenes in use', () async {
    await _createCompleteLayout(root);
    await _touch(
      root,
      'store-assets/google-play/tablet/'
      'android-tablet-05-card-editor-1.0.0-abcdef0.png',
    );

    final report = await StoreAssetValidator(
      repositoryRoot: root,
      rasterReader: _fixtureRaster,
    ).validate(appVersion: '1.0.0');

    expect(
      report.errors.join('\n'),
      contains('Missing alt text: tablet.card-editor.'),
    );
    expect(
      report.errors.join('\n'),
      isNot(contains('Unknown alt-text key: tablet.card-editor.')),
    );
  });

  test(
    'rejects Play tablet images outside the large-screen contract',
    () async {
      await _createCompleteLayout(root);

      final report = await StoreAssetValidator(
        repositoryRoot: root,
        rasterReader: (file) {
          final path = file.path.replaceAll(Platform.pathSeparator, '/');
          if (path.contains('/google-play/tablet/')) {
            return Future.value(_raster(1600, 2560));
          }
          return _fixtureRaster(file);
        },
      ).validate(appVersion: '1.0.0');

      expect(
        report.errors.join('\n'),
        contains(
          'Play tablet screenshots require 1080-7680 px and 16:9 or 9:16.',
        ),
      );
    },
  );

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
  await _writeAltTextManifest(root);
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

Future<void> _writeAltTextManifest(Directory root) async {
  final file = _file(root, StoreAssetAltTextValidator.manifestPath);
  await file.create(recursive: true);
  await file.writeAsString('''
{
  "featureGraphic": "기능 그래픽",
  "phone": {
    "home": "홈",
    "card-editor": "카드 편집",
    "question-answer": "질문과 답변",
    "calendar": "캘린더",
    "recording-library": "녹음 보관함",
    "ai": "AI",
    "widgets": "위젯",
    "settings": "설정"
  },
  "tablet": {
    "home": "태블릿 홈",
    "calendar": "태블릿 캘린더",
    "ai": "태블릿 AI",
    "settings": "태블릿 설정"
  }
}
''');
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
  final file = _file(root, relativePath);
  await file.create(recursive: true);
  await file.writeAsBytes(const [0]);
}

File _file(Directory root, String relativePath) => File(
  '${root.path}${Platform.pathSeparator}'
  '${relativePath.replaceAll('/', Platform.pathSeparator)}',
);

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
