import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final workflow = File('../../.github/workflows/android-release.yml');

  test('Android release candidates are built only by an explicit request', () {
    expect(workflow.existsSync(), isTrue);
    final source = workflow.readAsStringSync();

    expect(source, contains('workflow_dispatch:'));
    expect(source, contains('build_number:'));
    expect(source, contains('environment: android-release'));
    expect(source, isNot(contains('pull_request:')));
    expect(source, isNot(matches(RegExp(r'^\s+push:', multiLine: true))));
  });

  test('release builds require signing and runtime configuration', () {
    final source = workflow.readAsStringSync();

    for (final variable in _requiredConfiguration) {
      expect(source, contains(variable));
    }
    expect(source, contains('base64 --decode'));
    expect(source, contains('flutter build appbundle'));
    expect(source, contains(r'--build-number "$BUILD_NUMBER"'));
    expect(source, contains('--dart-define=SUPABASE_URL='));
    expect(source, contains('--dart-define=SUPABASE_ANON_KEY='));
    expect(source, contains('--dart-define=KAKAO_NATIVE_APP_KEY='));
    expect(source, contains('--dart-define=POLICY_BASE_URL='));
    expect(source, contains(r'vars.DANJJAN_POLICY_BASE_URL'));
  });

  test('release evidence contains the bundle, mapping and checksums', () {
    final source = workflow.readAsStringSync();

    expect(source, contains('app-release.aab'));
    expect(source, contains('mapping/release/mapping.txt'));
    expect(source, contains('sha256sum'));
    expect(source, contains('actions/upload-artifact@'));
    expect(source, contains('if-no-files-found: error'));
    expect(
      source,
      isNot(matches(RegExp(r'path:\s+.*upload-keystore', multiLine: true))),
    );
  });

  test('release workflow uses least privilege and immutable actions', () {
    final source = workflow.readAsStringSync();
    final actionReferences = RegExp(
      r'^\s*-\s+uses:\s+[^@\s]+@([^\s#]+)',
      multiLine: true,
    ).allMatches(source);

    expect(source, matches(RegExp(r'permissions:\r?\n\s+contents:\s+read')));
    expect(actionReferences, isNotEmpty);
    for (final reference in actionReferences) {
      expect(reference.group(1), matches(RegExp(r'^[0-9a-f]{40}$')));
    }
    expect(source, isNot(contains('contents: write')));
    expect(source, isNot(contains('id-token: write')));
  });
}

const _requiredConfiguration = <String>[
  'DANJJAN_UPLOAD_KEYSTORE_BASE64',
  'DANJJAN_UPLOAD_STORE_PASSWORD',
  'DANJJAN_UPLOAD_KEY_ALIAS',
  'DANJJAN_UPLOAD_KEY_PASSWORD',
  'DANJJAN_SUPABASE_URL',
  'DANJJAN_SUPABASE_ANON_KEY',
  'DANJJAN_KAKAO_NATIVE_APP_KEY',
  'DANJJAN_POLICY_BASE_URL',
];
