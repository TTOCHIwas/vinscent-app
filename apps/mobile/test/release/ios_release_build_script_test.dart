import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final script = File('../../scripts/build_ios_release_candidate.sh');

  test('iOS release script validates its platform and runtime inputs', () {
    expect(script.existsSync(), isTrue);
    final source = script.readAsStringSync();

    expect(source, contains('set -euo pipefail'));
    expect(source, contains(r'"$(uname -s)" != "Darwin"'));
    expect(source, contains('positive-build-number'));
    for (final variable in _requiredConfiguration) {
      expect(source, contains(variable));
    }
    expect(source, contains('validate_https_url "DANJJAN_SUPABASE_URL"'));
    expect(source, contains('validate_https_url "DANJJAN_POLICY_BASE_URL"'));
    expect(source, contains(r'local authority="${value#https://}"'));
    expect(source, contains(r'-z "$authority"'));
    expect(source, contains(r'"$value" == *[[:space:]]*'));
    expect(source, contains('xcodebuild -version'));
    expect(source, contains('xcrun --sdk iphoneos --show-sdk-version'));
    expect(
      source,
      contains('validate_minimum_major_version "Xcode" "\$xcode_version" 26'),
    );
    expect(
      source,
      contains(
        'validate_minimum_major_version '
        '"iPhoneOS SDK" "\$iphoneos_sdk_version" 26',
      ),
    );
  });

  test('iOS release script builds a verified archive without uploading it', () {
    final source = script.readAsStringSync();

    expect(
      source,
      contains(
        r'"$dart_binary" format --output=none --set-exit-if-changed lib test',
      ),
    );
    expect(source, contains(r'"$flutter_binary" analyze --no-pub'));
    expect(source, contains(r'"$flutter_binary" test --no-pub'));
    expect(source, contains(r'"$flutter_binary" build ipa'));
    expect(source, contains('--release'));
    expect(source, contains(r'--build-number "$build_number"'));
    expect(source, contains('--dart-define="SUPABASE_URL='));
    expect(source, contains('--dart-define="SUPABASE_ANON_KEY='));
    expect(source, contains('--dart-define="KAKAO_NATIVE_APP_KEY='));
    expect(source, contains('--dart-define="POLICY_BASE_URL='));
    expect(source, contains('shopt -s nullglob'));
    expect(source, contains(r'${#archive_candidates[@]} -ne 1'));
    expect(source, contains(r'${#ipa_candidates[@]} -ne 1'));
    expect(source, contains('codesign --verify --deep --strict'));
    expect(source, contains('CFBundleIdentifier'));
    expect(source, contains('CFBundleShortVersionString'));
    expect(source, contains('CFBundleVersion'));
    expect(source, contains('com.vinscent.vinscent.widgets'));
    expect(source, contains('PrivacyInfo.xcprivacy'));
    expect(source, contains('codesign -d --entitlements :-'));
    expect(source, contains('aps-environment'));
    expect(source, contains('Push environment'));
    expect(source, contains('production'));
    expect(source, contains('group.com.vinscent.vinscent'));
    expect(source, contains('com.apple.developer.applesignin:0'));
    expect(source, contains('privacy-manifests.txt'));
    expect(source, contains('ditto -c -k'));
    expect(source, contains('shasum -a 256'));
    expect(source, contains(r'git -C "$repository_root" rev-parse HEAD'));
    expect(source, contains(r"printf 'xcode_version=%s\n'"));
    expect(source, contains(r"printf 'iphoneos_sdk_version=%s\n'"));
    expect(
      source,
      contains(r'mktemp -d "$evidence_parent/.ios-build-${build_number}.'),
    );
    expect(source, contains(r'ipa_output="$staged_evidence/'));
    expect(source, contains(r'mv "$staged_evidence" "$evidence_directory"'));
    expect(source, isNot(contains(r'mkdir -p "$evidence_directory"')));
    expect(source, isNot(contains('altool')));
    expect(source, isNot(contains('transporter')));
    expect(source, isNot(contains('app-store-connect')));
  });
}

const _requiredConfiguration = <String>[
  'DANJJAN_SUPABASE_URL',
  'DANJJAN_SUPABASE_ANON_KEY',
  'DANJJAN_KAKAO_NATIVE_APP_KEY',
  'DANJJAN_POLICY_BASE_URL',
];
