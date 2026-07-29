import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final appGradle = File('android/app/build.gradle.kts');

  test('release builds never fall back to the debug signing key', () {
    final gradle = appGradle.readAsStringSync();

    expect(
      gradle,
      isNot(contains('signingConfig = signingConfigs.getByName("debug")')),
    );
  });

  test('release signing accepts local and CI-only credentials', () {
    final gradle = appGradle.readAsStringSync();

    expect(gradle, contains('key.properties'));
    for (final variable in _ciSigningVariables) {
      expect(gradle, contains(variable));
    }
  });

  test('release builds fail clearly when signing is not configured', () {
    final gradle = appGradle.readAsStringSync();

    expect(gradle, contains('preReleaseBuild'));
    expect(gradle, contains('GradleException'));
  });
}

const _ciSigningVariables = <String>[
  'DANJJAN_UPLOAD_STORE_FILE',
  'DANJJAN_UPLOAD_STORE_PASSWORD',
  'DANJJAN_UPLOAD_KEY_ALIAS',
  'DANJJAN_UPLOAD_KEY_PASSWORD',
];
