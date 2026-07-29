import 'package:flutter_test/flutter_test.dart';

import '../../tool/store_asset_verification_options.dart';

void main() {
  test('uses the pubspec identity when no override is provided', () {
    final options = StoreAssetVerificationOptions.parse(const []);

    expect(options.appVersion, isNull);
    expect(options.buildNumber, isNull);
  });

  test('parses an explicit release candidate identity in either order', () {
    final versionFirst = StoreAssetVerificationOptions.parse(const [
      '--app-version',
      '1.2.3',
      '--build-number',
      '42',
    ]);
    final buildFirst = StoreAssetVerificationOptions.parse(const [
      '--build-number',
      '42',
      '--app-version',
      '1.2.3',
    ]);

    expect(versionFirst.appVersion, '1.2.3');
    expect(versionFirst.buildNumber, 42);
    expect(buildFirst.appVersion, '1.2.3');
    expect(buildFirst.buildNumber, 42);
  });

  test('rejects partial, invalid and unknown release options', () {
    expect(
      () =>
          StoreAssetVerificationOptions.parse(const ['--app-version', '1.2.3']),
      throwsFormatException,
    );
    expect(
      () => StoreAssetVerificationOptions.parse(const [
        '--app-version',
        '1.2',
        '--build-number',
        '1',
      ]),
      throwsFormatException,
    );
    expect(
      () => StoreAssetVerificationOptions.parse(const [
        '--app-version',
        '1.2.3',
        '--build-number',
        '0',
      ]),
      throwsFormatException,
    );
    expect(
      () => StoreAssetVerificationOptions.parse(const [
        '--app-version',
        '1.2.3',
        '--other',
        '1',
      ]),
      throwsFormatException,
    );
  });
}
