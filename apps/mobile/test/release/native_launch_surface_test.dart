import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('native launch surfaces match the light-only Flutter theme', () {
    final app = File('lib/app/app.dart').readAsStringSync();
    final androidLaunch = File(
      'android/app/src/main/res/drawable/launch_background.xml',
    ).readAsStringSync();
    final androidLaunchV21 = File(
      'android/app/src/main/res/drawable-v21/launch_background.xml',
    ).readAsStringSync();
    final androidNightStyles = File(
      'android/app/src/main/res/values-night/styles.xml',
    ).readAsStringSync();
    final iosLaunch = File(
      'ios/Runner/Base.lproj/LaunchScreen.storyboard',
    ).readAsStringSync();

    expect(app, contains('themeMode: ThemeMode.light'));
    expect(androidLaunch, contains('@android:color/white'));
    expect(androidLaunchV21, contains('@android:color/white'));
    expect(
      _occurrences(
        androidNightStyles,
        'parent="@android:style/Theme.Light.NoTitleBar"',
      ),
      2,
    );
    expect(androidNightStyles, isNot(contains('Theme.Black')));
    expect(androidNightStyles, contains('@android:color/white'));
    expect(
      iosLaunch,
      contains(
        '<color key="backgroundColor" red="1" green="1" blue="1" '
        'alpha="1"',
      ),
    );
  });
}

int _occurrences(String source, String pattern) {
  return pattern.allMatches(source).length;
}
