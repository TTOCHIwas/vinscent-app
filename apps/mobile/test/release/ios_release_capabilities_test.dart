import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final runnerEntitlements = File('ios/Runner/Runner.entitlements');
  final widgetEntitlements = File(
    'ios/VinscentWidgets/VinscentWidgets.entitlements',
  );
  final infoPlist = File('ios/Runner/Info.plist');

  test('Runner declares push notifications and Sign in with Apple', () {
    final runner = runnerEntitlements.readAsStringSync();

    expect(runner, contains('<key>aps-environment</key>'));
    expect(runner, contains('<key>com.apple.developer.applesignin</key>'));
    expect(runner, contains('<string>Default</string>'));
  });

  test('widget keeps only the capabilities it uses', () {
    final widget = widgetEntitlements.readAsStringSync();

    expect(widget, isNot(contains('<key>aps-environment</key>')));
    expect(
      widget,
      isNot(contains('<key>com.apple.developer.applesignin</key>')),
    );
  });

  test('Runner enables every background mode required by its services', () {
    final plist = infoPlist.readAsStringSync();

    for (final mode in _backgroundModes) {
      expect(plist, contains('<string>$mode</string>'));
    }
  });

  test('Runner declares that it only uses exempt encryption', () {
    final plist = infoPlist.readAsStringSync();

    expect(
      plist,
      contains('<key>ITSAppUsesNonExemptEncryption</key>\n\t<false/>'),
    );
  });
}

const _backgroundModes = <String>[
  'audio',
  'processing',
  'fetch',
  'remote-notification',
];
