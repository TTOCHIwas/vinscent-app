import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Flutter and native targets expose the Danjjan product name', () {
    final flutterApp = File('lib/app/app.dart').readAsStringSync();
    final androidManifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final androidStrings = File(
      'android/app/src/main/res/values/strings.xml',
    ).readAsStringSync();
    final iosInfo = _readNormalized(File('ios/Runner/Info.plist'));
    final widgetInfo = _readNormalized(File('ios/VinscentWidgets/Info.plist'));

    expect(flutterApp, contains("title: '단짠'"));
    expect(androidManifest, contains('android:label="@string/app_name"'));
    expect(androidStrings, contains('<string name="app_name">단짠</string>'));
    expect(
      iosInfo,
      contains('<key>CFBundleDisplayName</key>\n\t<string>단짠</string>'),
    );
    expect(iosInfo, contains('<key>CFBundleName</key>\n\t<string>단짠</string>'));
    expect(
      widgetInfo,
      contains('<key>CFBundleDisplayName</key>\n\t<string>단짠 위젯</string>'),
    );
  });

  test('release bundle identifiers remain stable across platforms', () {
    final androidBuild = File(
      'android/app/build.gradle.kts',
    ).readAsStringSync();
    final iosProject = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();

    expect(androidBuild, contains('applicationId = "com.vinscent.vinscent"'));
    expect(
      iosProject,
      contains('PRODUCT_BUNDLE_IDENTIFIER = com.vinscent.vinscent;'),
    );
    expect(
      iosProject,
      contains('PRODUCT_BUNDLE_IDENTIFIER = com.vinscent.vinscent.widgets;'),
    );
  });
}

String _readNormalized(File file) =>
    file.readAsStringSync().replaceAll(RegExp(r'\r\n?'), '\n');
