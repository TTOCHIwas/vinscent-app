import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final manifest = File('android/app/src/main/AndroidManifest.xml');
  final legacyBackupRules = File(
    'android/app/src/main/res/xml/backup_rules.xml',
  );
  final dataExtractionRules = File(
    'android/app/src/main/res/xml/data_extraction_rules.xml',
  );

  test('release manifest declares its own network permission', () {
    final xml = manifest.readAsStringSync();

    expect(
      xml,
      contains(
        '<uses-permission android:name="android.permission.INTERNET" />',
      ),
    );
  });

  test('device calendar sync declares read and write permissions', () {
    final xml = manifest.readAsStringSync();

    for (final permission in _calendarPermissions) {
      expect(xml, contains('<uses-permission android:name="$permission" />'));
    }
  });

  test('optional capture hardware does not filter Play devices', () {
    final xml = manifest.readAsStringSync();

    for (final feature in _optionalHardwareFeatures) {
      expect(
        xml,
        contains(
          '<uses-feature android:name="$feature" android:required="false" />',
        ),
      );
    }
  });

  test('legacy gallery access keeps write-only storage permission', () {
    final xml = manifest.readAsStringSync();

    expect(
      xml,
      contains(
        'android:name="android.permission.WRITE_EXTERNAL_STORAGE"\n'
        '        android:maxSdkVersion="29"',
      ),
    );
    expect(
      xml,
      contains(
        'android:name="android.permission.READ_EXTERNAL_STORAGE"\n'
        '        tools:node="remove"',
      ),
    );
  });

  test('local sessions and drafts are excluded from device backup', () {
    final xml = manifest.readAsStringSync();

    expect(xml, contains('android:allowBackup="false"'));
    expect(xml, contains('android:fullBackupContent="@xml/backup_rules"'));
    expect(
      xml,
      contains('android:dataExtractionRules="@xml/data_extraction_rules"'),
    );
    expect(legacyBackupRules.existsSync(), isTrue);
    expect(dataExtractionRules.existsSync(), isTrue);

    final legacy = legacyBackupRules.readAsStringSync();
    final current = dataExtractionRules.readAsStringSync();
    for (final domain in _backupDomains) {
      expect(legacy, contains('<exclude domain="$domain" path="." />'));
      expect(_occurrences(current, '<exclude domain="$domain" path="." />'), 2);
    }
  });
}

const _optionalHardwareFeatures = <String>[
  'android.hardware.camera.any',
  'android.hardware.camera',
  'android.hardware.camera.autofocus',
  'android.hardware.microphone',
];

const _calendarPermissions = <String>[
  'android.permission.READ_CALENDAR',
  'android.permission.WRITE_CALENDAR',
];

const _backupDomains = <String>[
  'root',
  'file',
  'database',
  'sharedpref',
  'external',
];

int _occurrences(String source, String pattern) {
  return pattern.allMatches(source).length;
}
