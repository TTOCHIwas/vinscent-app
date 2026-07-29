import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final runnerManifest = File('ios/Runner/PrivacyInfo.xcprivacy');
  final widgetManifest = File('ios/VinscentWidgets/PrivacyInfo.xcprivacy');
  final xcodeProject = File('ios/Runner.xcodeproj/project.pbxproj');

  test('iOS app and widget bundle their own privacy manifests', () {
    expect(runnerManifest.existsSync(), isTrue);
    expect(widgetManifest.existsSync(), isTrue);

    final project = xcodeProject.readAsStringSync();
    expect(_occurrences(project, 'PrivacyInfo.xcprivacy in Resources'), 4);
    expect(_occurrences(project, 'path = PrivacyInfo.xcprivacy;'), 2);
  });

  test('Runner declares collected data without tracking', () {
    final manifest = runnerManifest.readAsStringSync();

    expect(manifest, contains('<key>NSPrivacyTracking</key>'));
    expect(manifest, contains('<false/>'));
    for (final dataType in _runnerCollectedDataTypes) {
      expect(manifest, contains('<string>$dataType</string>'));
    }
    expect(
      _occurrences(manifest, '<key>NSPrivacyCollectedDataTypeTracking</key>'),
      _runnerCollectedDataTypes.length,
    );
  });

  test('required reason APIs match native app and widget usage', () {
    final runner = runnerManifest.readAsStringSync();
    final widget = widgetManifest.readAsStringSync();

    expect(runner, contains('<string>C617.1</string>'));
    expect(runner, contains('<string>CA92.1</string>'));
    expect(runner, contains('<string>1C8F.1</string>'));
    expect(widget, contains('<string>C617.1</string>'));
    expect(widget, contains('<string>1C8F.1</string>'));
    expect(widget, isNot(contains('<string>CA92.1</string>')));
  });
}

const _runnerCollectedDataTypes = <String>[
  'NSPrivacyCollectedDataTypeName',
  'NSPrivacyCollectedDataTypeEmailAddress',
  'NSPrivacyCollectedDataTypeCoarseLocation',
  'NSPrivacyCollectedDataTypePhotosorVideos',
  'NSPrivacyCollectedDataTypeAudioData',
  'NSPrivacyCollectedDataTypeOtherUserContent',
  'NSPrivacyCollectedDataTypeSearchHistory',
  'NSPrivacyCollectedDataTypeUserID',
  'NSPrivacyCollectedDataTypeDeviceID',
  'NSPrivacyCollectedDataTypeProductInteraction',
  'NSPrivacyCollectedDataTypeOtherDiagnosticData',
  'NSPrivacyCollectedDataTypeOtherDataTypes',
];

int _occurrences(String source, String pattern) {
  return pattern.allMatches(source).length;
}
