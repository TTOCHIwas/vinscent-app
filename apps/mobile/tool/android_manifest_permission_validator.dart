import 'package:xml/xml.dart';

const androidReleasePermissionContract = <String, int?>{
  'android.permission.ACCESS_COARSE_LOCATION': null,
  'android.permission.ACCESS_NETWORK_STATE': null,
  'android.permission.CAMERA': null,
  'android.permission.FOREGROUND_SERVICE': null,
  'android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK': null,
  'android.permission.FOREGROUND_SERVICE_MICROPHONE': null,
  'android.permission.INTERNET': null,
  'android.permission.POST_NOTIFICATIONS': null,
  'android.permission.RECEIVE_BOOT_COMPLETED': null,
  'android.permission.RECORD_AUDIO': null,
  'android.permission.READ_CALENDAR': null,
  'android.permission.VIBRATE': null,
  'android.permission.WAKE_LOCK': null,
  'android.permission.WRITE_EXTERNAL_STORAGE': 29,
  'android.permission.WRITE_CALENDAR': null,
  'com.google.android.c2dm.permission.RECEIVE': null,
  'com.vinscent.vinscent.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION': null,
};

class AndroidManifestPermissionValidator {
  const AndroidManifestPermissionValidator();

  void validate(String source) {
    final document = XmlDocument.parse(source);
    final root = document.rootElement;
    if (root.name.local != 'manifest') {
      throw const AndroidManifestPermissionValidationException([
        'Android manifest root element is missing.',
      ]);
    }

    final issues = <String>[];
    final actual = <String, int?>{};
    final permissionElements = root.childElements.where(
      (element) =>
          element.name.local == 'uses-permission' ||
          element.name.local == 'uses-permission-sdk-23',
    );

    for (final element in permissionElements) {
      final name = element.getAttribute(
        'name',
        namespaceUri: _androidNamespace,
      );
      if (name == null || name.isEmpty) {
        issues.add('A uses-permission element has no android:name.');
        continue;
      }
      if (actual.containsKey(name)) {
        issues.add('Duplicate Android permission: $name');
        continue;
      }

      final maxSdkSource = element.getAttribute(
        'maxSdkVersion',
        namespaceUri: _androidNamespace,
      );
      final maxSdk = maxSdkSource == null ? null : int.tryParse(maxSdkSource);
      if (maxSdkSource != null && maxSdk == null) {
        issues.add('Permission $name has an invalid maxSdkVersion.');
        continue;
      }
      actual[name] = maxSdk;
    }

    final missing =
        androidReleasePermissionContract.keys
            .where((permission) => !actual.containsKey(permission))
            .toList()
          ..sort();
    final unexpected =
        actual.keys
            .where(
              (permission) =>
                  !androidReleasePermissionContract.containsKey(permission),
            )
            .toList()
          ..sort();
    for (final permission in missing) {
      issues.add('Missing Android release permission: $permission');
    }
    for (final permission in unexpected) {
      issues.add('Unexpected Android release permission: $permission');
    }

    for (final permission in actual.keys) {
      if (!androidReleasePermissionContract.containsKey(permission)) {
        continue;
      }
      final expectedMaxSdk = androidReleasePermissionContract[permission];
      final actualMaxSdk = actual[permission];
      if (actualMaxSdk != expectedMaxSdk) {
        issues.add(
          'Permission $permission must have maxSdkVersion '
          '${expectedMaxSdk ?? 'unset'}; found ${actualMaxSdk ?? 'unset'}.',
        );
      }
    }

    if (issues.isNotEmpty) {
      throw AndroidManifestPermissionValidationException(issues);
    }
  }
}

class AndroidManifestPermissionValidationException implements Exception {
  const AndroidManifestPermissionValidationException(this.issues);

  final List<String> issues;

  @override
  String toString() => issues.join('\n');
}

const _androidNamespace = 'http://schemas.android.com/apk/res/android';
