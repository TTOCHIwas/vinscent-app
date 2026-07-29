import 'package:flutter_test/flutter_test.dart';

import '../../tool/android_manifest_permission_validator.dart';

void main() {
  const validator = AndroidManifestPermissionValidator();

  test('accepts the exact Android release permission contract', () {
    expect(() => validator.validate(_manifest()), returnsNormally);
  });

  test('rejects missing, unexpected and broadened permissions', () {
    final permissions = Map<String, int?>.from(androidReleasePermissionContract)
      ..remove('android.permission.CAMERA')
      ..['android.permission.READ_EXTERNAL_STORAGE'] = null
      ..['android.permission.WRITE_EXTERNAL_STORAGE'] = null;

    expect(
      () => validator.validate(_manifest(permissions: permissions)),
      throwsA(
        isA<AndroidManifestPermissionValidationException>().having(
          (error) => error.issues,
          'issues',
          containsAll([
            'Missing Android release permission: android.permission.CAMERA',
            'Unexpected Android release permission: '
                'android.permission.READ_EXTERNAL_STORAGE',
            'Permission android.permission.WRITE_EXTERNAL_STORAGE must have '
                'maxSdkVersion 29; found unset.',
          ]),
        ),
      ),
    );
  });

  test('rejects duplicate permission declarations', () {
    final duplicate =
        '<uses-permission '
        'android:name="android.permission.INTERNET" />';

    expect(
      () => validator.validate(_manifest(extraElement: duplicate)),
      throwsA(
        isA<AndroidManifestPermissionValidationException>().having(
          (error) => error.issues,
          'issues',
          contains('Duplicate Android permission: android.permission.INTERNET'),
        ),
      ),
    );
  });
}

String _manifest({
  Map<String, int?> permissions = androidReleasePermissionContract,
  String extraElement = '',
}) {
  final elements = permissions.entries.map((entry) {
    final maxSdk = entry.value == null
        ? ''
        : ' android:maxSdkVersion="${entry.value}"';
    return '<uses-permission android:name="${entry.key}"$maxSdk />';
  }).join();
  return '''
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
  $elements
  $extraElement
</manifest>
''';
}
