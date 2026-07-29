import 'dart:convert';
import 'dart:io';

final class StoreAssetCaptureManifestValidator {
  const StoreAssetCaptureManifestValidator();

  static const manifestPath = 'store-assets/capture-manifest.json';

  List<String> validate(
    File file, {
    required String appVersion,
    required int buildNumber,
    required Set<String> screenshotPaths,
  }) {
    if (screenshotPaths.isEmpty && !file.existsSync()) {
      return const [];
    }
    if (!file.existsSync()) {
      return [_issue('missing', 'Required capture manifest is missing.')];
    }

    late final Object? decoded;
    try {
      decoded = jsonDecode(file.readAsStringSync());
    } on Object {
      return [_issue('format', 'Capture manifest must be valid JSON.')];
    }
    if (decoded is! Map<String, Object?>) {
      return [_issue('format', 'Capture manifest must be a JSON object.')];
    }

    final errors = <String>[];
    _validateKeys(
      decoded,
      const {
        'schemaVersion',
        'appVersion',
        'buildNumber',
        'releaseCommit',
        'captures',
      },
      'root',
      errors,
    );
    _validateIdentity(decoded, appVersion, buildNumber, errors);
    final releaseCommit = _readReleaseCommit(decoded, errors);
    final capturedPaths = _validateCaptures(
      decoded['captures'],
      screenshotPaths,
      errors,
    );
    for (final path in screenshotPaths.difference(capturedPaths)) {
      errors.add(_issue('missing', 'Missing capture metadata: $path.'));
    }
    if (releaseCommit != null) {
      final suffix = RegExp(
        '-${RegExp.escape(appVersion)}-${RegExp.escape(releaseCommit)}'
        r'\.(png|jpe?g)$',
        caseSensitive: false,
      );
      for (final path in screenshotPaths.where(
        (path) => !suffix.hasMatch(path),
      )) {
        errors.add(
          _issue(
            'commit',
            'Screenshot filename does not match releaseCommit: $path.',
          ),
        );
      }
    }
    return errors;
  }

  void _validateIdentity(
    Map<String, Object?> values,
    String appVersion,
    int buildNumber,
    List<String> errors,
  ) {
    if (values['schemaVersion'] != 1) {
      errors.add(_issue('schema', 'schemaVersion must be 1.'));
    }
    if (values['appVersion'] != appVersion) {
      errors.add(_issue('version', 'appVersion must be $appVersion.'));
    }
    if (values['buildNumber'] != buildNumber) {
      errors.add(_issue('build', 'buildNumber must be $buildNumber.'));
    }
  }

  String? _readReleaseCommit(Map<String, Object?> values, List<String> errors) {
    final value = values['releaseCommit'];
    if (value is! String ||
        !RegExp(r'^[0-9a-f]{7,40}$', caseSensitive: false).hasMatch(value)) {
      errors.add(
        _issue('commit', 'releaseCommit must be a 7-40 character Git SHA.'),
      );
      return null;
    }
    return value;
  }

  Set<String> _validateCaptures(
    Object? value,
    Set<String> screenshotPaths,
    List<String> errors,
  ) {
    if (value is! List<Object?>) {
      errors.add(_issue('format', 'captures must be a JSON array.'));
      return const {};
    }

    final capturedPaths = <String>{};
    for (var index = 0; index < value.length; index += 1) {
      final entry = value[index];
      final label = 'captures[$index]';
      if (entry is! Map<String, Object?>) {
        errors.add(_issue('format', '$label must be a JSON object.'));
        continue;
      }
      _validateKeys(entry, const {'file', 'device', 'os'}, label, errors);
      final path = entry['file'];
      if (path is! String || path.trim().isEmpty) {
        errors.add(_issue('content', '$label.file must not be empty.'));
      } else {
        final normalized = path.replaceAll(r'\', '/');
        if (!capturedPaths.add(normalized)) {
          errors.add(_issue('duplicate', 'Duplicate capture: $normalized.'));
        }
        if (!screenshotPaths.contains(normalized)) {
          errors.add(
            _issue('file', 'Capture does not match a screenshot: $normalized.'),
          );
        }
      }
      _validateText(entry['device'], '$label.device', errors);
      _validateText(entry['os'], '$label.os', errors);
    }
    return capturedPaths;
  }

  void _validateKeys(
    Map<String, Object?> values,
    Set<String> expectedKeys,
    String group,
    List<String> errors,
  ) {
    final actualKeys = values.keys.toSet();
    for (final key in expectedKeys.difference(actualKeys)) {
      errors.add(_issue('missing', 'Missing key: $group.$key.'));
    }
    for (final key in actualKeys.difference(expectedKeys)) {
      errors.add(_issue('key', 'Unknown key: $group.$key.'));
    }
  }

  void _validateText(Object? value, String key, List<String> errors) {
    if (value is! String || value.trim().isEmpty) {
      errors.add(_issue('content', '$key must not be empty.'));
    }
  }

  String _issue(String code, String message) =>
      '$manifestPath [$code] $message';
}
