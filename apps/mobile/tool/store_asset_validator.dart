import 'dart:io';

import 'package:image/image.dart' as image;

import 'store_asset_alt_text_validator.dart';

typedef RasterReader = Future<RasterInfo> Function(File file);

final class RasterInfo {
  const RasterInfo({
    required this.format,
    required this.width,
    required this.height,
    required this.hasAlpha,
    required this.byteLength,
  });

  final String format;
  final int width;
  final int height;
  final bool hasAlpha;
  final int byteLength;
}

final class StoreAssetReport {
  const StoreAssetReport({
    required this.errors,
    required this.validatedFileCount,
  });

  final List<String> errors;
  final int validatedFileCount;

  bool get isReady => errors.isEmpty;
}

final class StoreAssetValidator {
  StoreAssetValidator({
    required Directory repositoryRoot,
    RasterReader? rasterReader,
  }) : _root = repositoryRoot,
       _readRaster = rasterReader ?? readRasterInfo;

  final Directory _root;
  final RasterReader _readRaster;

  Future<StoreAssetReport> validate({String? appVersion}) async {
    final version = appVersion ?? await _readAppVersion();
    final errors = <String>[];
    var count = 0;

    count += await _validateSingle(
      const ['store-assets/google-play/app-icon-512.png'],
      _playIconRule,
      errors,
    );
    count += await _validateSingle(
      const [
        'store-assets/google-play/feature-graphic.png',
        'store-assets/google-play/feature-graphic.jpg',
        'store-assets/google-play/feature-graphic.jpeg',
      ],
      _playFeatureRule,
      errors,
    );
    final altTextFile = _file(StoreAssetAltTextValidator.manifestPath);
    if (altTextFile.existsSync()) {
      count += 1;
    }
    errors.addAll(const StoreAssetAltTextValidator().validate(altTextFile));
    for (final group in _groups) {
      count += await _validateGroup(group, version, errors);
    }

    errors.sort();
    return StoreAssetReport(
      errors: List.unmodifiable(errors),
      validatedFileCount: count,
    );
  }

  Future<int> _validateSingle(
    List<String> candidates,
    _ImageRule rule,
    List<String> errors,
  ) async {
    final files = candidates
        .map(_file)
        .where((file) => file.existsSync())
        .toList();
    if (files.isEmpty) {
      errors.add(
        _issue(candidates.first, 'missing', 'Required asset is missing.'),
      );
      return 0;
    }
    if (files.length > 1) {
      errors.add(
        _issue(candidates.first, 'duplicate', 'Keep one supported file only.'),
      );
    }
    await _validateImage(files.first, _relative(files.first), rule, errors);
    return 1;
  }

  Future<int> _validateGroup(
    _GroupSpec group,
    String version,
    List<String> errors,
  ) async {
    final directory = _directory(group.directory);
    final files = directory.existsSync()
        ? directory
              .listSync(followLinks: false)
              .whereType<File>()
              .where(_isRaster)
              .toList()
        : <File>[];
    files.sort((left, right) => _name(left).compareTo(_name(right)));

    if (files.length < group.minimum || files.length > group.maximum) {
      errors.add(
        _issue(
          group.directory,
          'count',
          'Expected ${group.minimum}-${group.maximum}, found ${files.length}.',
        ),
      );
    }

    final pattern = RegExp(
      '^${RegExp.escape(group.prefix)}-'
      r'(\d{2})-([a-z0-9-]+)-'
      '${RegExp.escape(version)}-'
      r'[0-9a-f]{7,40}\.(png|jpe?g)$',
      caseSensitive: false,
    );
    final sequences = <int>[];
    final scenes = <String>[];

    for (final file in files) {
      final relativePath = '${group.directory}/${_name(file)}';
      final match = pattern.firstMatch(_name(file));
      if (match == null) {
        errors.add(
          _issue(
            relativePath,
            'filename',
            'Use ${group.prefix}-NN-scene-$version-commit.ext.',
          ),
        );
      } else {
        sequences.add(int.parse(match.group(1)!));
        scenes.add(match.group(2)!);
      }
      await _validateImage(file, relativePath, group.rule, errors);
    }

    if (files.isNotEmpty && sequences.length == files.length) {
      final ordered = [...sequences]..sort();
      if (ordered.asMap().entries.any(
        (entry) => entry.value != entry.key + 1,
      )) {
        errors.add(
          _issue(
            group.directory,
            'sequence',
            'Number files from 01 without gaps.',
          ),
        );
      }
      if (sequences.toSet().length != sequences.length) {
        errors.add(
          _issue(
            group.directory,
            'sequence',
            'Sequence numbers must be unique.',
          ),
        );
      }
      if (scenes.toSet().length != scenes.length) {
        errors.add(_issue(group.directory, 'scene', 'Scenes must be unique.'));
      }
      for (final scene in scenes.where((scene) => !_scenes.contains(scene))) {
        errors.add(_issue(group.directory, 'scene', 'Unknown scene: $scene.'));
      }
      for (final scene in group.requiredScenes.where(
        (scene) => !scenes.contains(scene),
      )) {
        errors.add(_issue(group.directory, 'scene', 'Missing scene: $scene.'));
      }
    }
    return files.length;
  }

  Future<void> _validateImage(
    File file,
    String relativePath,
    _ImageRule rule,
    List<String> errors,
  ) async {
    late final RasterInfo raster;
    try {
      raster = await _readRaster(file);
    } on Object {
      errors.add(_issue(relativePath, 'decode', 'Invalid PNG or JPEG file.'));
      return;
    }

    final extension = _name(file).toLowerCase().split('.').last;
    final expectedFormat = extension == 'png' ? 'png' : 'jpeg';
    if (raster.format != expectedFormat) {
      errors.add(_issue(relativePath, 'format', 'Extension and data differ.'));
    }
    if (rule.pngOnly && raster.format != 'png') {
      errors.add(_issue(relativePath, 'format', 'PNG is required.'));
    }
    if (rule.opaque && raster.hasAlpha) {
      errors.add(
        _issue(relativePath, 'alpha', 'Alpha channel is not allowed.'),
      );
    }
    if (rule.maximumBytes != null && raster.byteLength > rule.maximumBytes!) {
      errors.add(_issue(relativePath, 'size', 'File is too large.'));
    }
    if (rule.allowedSizes.isNotEmpty &&
        !rule.allowedSizes.contains((raster.width, raster.height))) {
      errors.add(
        _issue(
          relativePath,
          'dimensions',
          'Unexpected ${raster.width}x${raster.height} dimensions.',
        ),
      );
    }
    if (rule.playScreenshot) {
      final shortest = raster.width < raster.height
          ? raster.width
          : raster.height;
      final longest = raster.width > raster.height
          ? raster.width
          : raster.height;
      if (shortest < 320 || longest > 3840 || longest > shortest * 2) {
        errors.add(
          _issue(
            relativePath,
            'dimensions',
            'Play screenshots require 320-3840 px and at most 2:1.',
          ),
        );
      }
    }
    if (rule.portrait && raster.height <= raster.width) {
      errors.add(_issue(relativePath, 'orientation', 'Portrait is required.'));
    }
  }

  Future<String> _readAppVersion() async {
    final source = await _file('apps/mobile/pubspec.yaml').readAsString();
    final match = RegExp(
      r'^version:\s*(\d+\.\d+\.\d+)(?:\+\d+)?\s*$',
      multiLine: true,
    ).firstMatch(source);
    if (match == null) {
      throw StateError('Unable to read the Flutter release version.');
    }
    return match.group(1)!;
  }

  File _file(String relativePath) => File(_resolve(relativePath));

  Directory _directory(String relativePath) =>
      Directory(_resolve(relativePath));

  String _resolve(String relativePath) =>
      '${_root.path}${Platform.pathSeparator}'
      '${relativePath.replaceAll('/', Platform.pathSeparator)}';

  String _relative(File file) => file.absolute.path
      .substring(_root.absolute.path.length)
      .replaceAll(Platform.pathSeparator, '/')
      .replaceFirst(RegExp(r'^/+'), '');
}

Future<RasterInfo> readRasterInfo(File file) async {
  final bytes = await file.readAsBytes();
  final decoded = image.decodeImage(bytes);
  if (decoded == null) {
    throw const FormatException('Unable to decode image.');
  }
  final isPng =
      bytes.length >= 8 &&
      const [
        137,
        80,
        78,
        71,
        13,
        10,
        26,
        10,
      ].asMap().entries.every((entry) => bytes[entry.key] == entry.value);
  final isJpeg = bytes.length >= 2 && bytes[0] == 0xff && bytes[1] == 0xd8;
  if (!isPng && !isJpeg) {
    throw const FormatException('Unsupported image format.');
  }
  return RasterInfo(
    format: isPng ? 'png' : 'jpeg',
    width: decoded.width,
    height: decoded.height,
    hasAlpha: decoded.hasAlpha,
    byteLength: bytes.length,
  );
}

bool _isRaster(File file) {
  final name = _name(file).toLowerCase();
  return name.endsWith('.png') ||
      name.endsWith('.jpg') ||
      name.endsWith('.jpeg');
}

String _name(File file) => file.uri.pathSegments.last;

String _issue(String path, String code, String message) =>
    '$path [$code] $message';

final class _ImageRule {
  const _ImageRule({
    this.allowedSizes = const {},
    this.opaque = true,
    this.pngOnly = false,
    this.maximumBytes,
    this.playScreenshot = false,
    this.portrait = false,
  });

  final Set<(int, int)> allowedSizes;
  final bool opaque;
  final bool pngOnly;
  final int? maximumBytes;
  final bool playScreenshot;
  final bool portrait;
}

final class _GroupSpec {
  const _GroupSpec({
    required this.directory,
    required this.prefix,
    required this.minimum,
    required this.maximum,
    required this.requiredScenes,
    required this.rule,
  });

  final String directory;
  final String prefix;
  final int minimum;
  final int maximum;
  final Set<String> requiredScenes;
  final _ImageRule rule;
}

const _scenes = <String>{
  'home',
  'card-editor',
  'question-answer',
  'calendar',
  'recording-library',
  'ai',
  'widgets',
  'settings',
};

const _playIconRule = _ImageRule(
  allowedSizes: {(512, 512)},
  opaque: false,
  pngOnly: true,
  maximumBytes: 1024 * 1024,
);
const _playFeatureRule = _ImageRule(allowedSizes: {(1024, 500)});
const _playPhoneRule = _ImageRule(playScreenshot: true, portrait: true);
const _playTabletRule = _ImageRule(playScreenshot: true);
const _iphoneRule = _ImageRule(
  allowedSizes: {(1260, 2736), (1290, 2796), (1320, 2868)},
);
const _ipadRule = _ImageRule(allowedSizes: {(2064, 2752), (2048, 2732)});

const _groups = <_GroupSpec>[
  _GroupSpec(
    directory: 'store-assets/google-play/phone',
    prefix: 'android-phone',
    minimum: 8,
    maximum: 8,
    requiredScenes: _scenes,
    rule: _playPhoneRule,
  ),
  _GroupSpec(
    directory: 'store-assets/google-play/tablet',
    prefix: 'android-tablet',
    minimum: 4,
    maximum: 8,
    requiredScenes: {'home', 'calendar', 'ai', 'settings'},
    rule: _playTabletRule,
  ),
  _GroupSpec(
    directory: 'store-assets/app-store/iphone-6.9',
    prefix: 'ios-iphone-6.9',
    minimum: 8,
    maximum: 8,
    requiredScenes: _scenes,
    rule: _iphoneRule,
  ),
  _GroupSpec(
    directory: 'store-assets/app-store/ipad-13',
    prefix: 'ios-ipad-13',
    minimum: 8,
    maximum: 8,
    requiredScenes: _scenes,
    rule: _ipadRule,
  ),
];
