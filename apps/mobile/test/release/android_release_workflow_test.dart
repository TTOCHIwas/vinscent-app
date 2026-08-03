import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final workflow = File('../../.github/workflows/android-release.yml');

  test('Android release candidates are built only by an explicit request', () {
    expect(workflow.existsSync(), isTrue);
    final source = workflow.readAsStringSync();

    expect(source, contains('workflow_dispatch:'));
    expect(source, contains('commit_sha_confirmation:'));
    expect(source, contains('build_number:'));
    expect(source, contains('environment: android-release'));
    expect(source, isNot(contains('pull_request:')));
    expect(source, isNot(matches(RegExp(r'^\s+push:', multiLine: true))));
  });

  test('release candidates require the exact main commit', () {
    final source = workflow.readAsStringSync();

    expect(source, contains(r'$GITHUB_REF" != "refs/heads/main'));
    expect(source, contains(r'^[0-9a-f]{40}$'));
    expect(source, contains(r'$CONFIRMED_COMMIT_SHA" != "$GITHUB_SHA'));
    expect(source, contains('inputs.commit_sha_confirmation'));

    final sourceGateIndex = source.indexOf(
      '- name: Require an exact main commit',
    );
    final configurationIndex = source.indexOf(
      '- name: Validate release configuration',
    );
    expect(sourceGateIndex, greaterThanOrEqualTo(0));
    expect(configurationIndex, greaterThan(sourceGateIndex));
  });

  test('release builds require signing and runtime configuration', () {
    final source = workflow.readAsStringSync();

    for (final variable in _requiredConfiguration) {
      expect(source, contains(variable));
    }
    expect(source, contains('base64 --decode'));
    expect(
      source,
      contains(
        'dart format --output=none --set-exit-if-changed '
        'lib test integration_test',
      ),
    );
    expect(source, contains('flutter build appbundle'));
    expect(source, contains(r'--build-number "$BUILD_NUMBER"'));
    expect(source, contains('--dart-define=SUPABASE_URL='));
    expect(source, contains('--dart-define=SUPABASE_ANON_KEY='));
    expect(source, contains('--dart-define=KAKAO_NATIVE_APP_KEY='));
    expect(source, contains('--dart-define=POLICY_BASE_URL='));
    expect(source, contains(r'vars.DANJJAN_POLICY_BASE_URL'));
    expect(source, contains(r'vars.DANJJAN_PLAY_UPLOAD_CERT_SHA256'));
    expect(source, contains('validate_https_url "DANJJAN_SUPABASE_URL"'));
    expect(source, contains('validate_https_url "DANJJAN_POLICY_BASE_URL"'));
    expect(source, contains(r'"$value" == *"?"*'));
    expect(source, contains(r'"$value" == *"#"*'));
    expect(source, contains(r'"$value" == *"@"*'));
    expect(source, contains(r'local authority="${value#https://}"'));
    expect(source, contains(r'-z "$authority"'));
    expect(source, contains(r'"$value" == *[[:space:]]*'));
  });

  test('release builds regenerate plugins after running tests', () {
    final source = workflow.readAsStringSync();
    final releaseBuilds = RegExp(
      r'flutter build appbundle \\\r?\n(?:(?!^\s*- name:)[\s\S])*?(?=^\s*- name:)',
      multiLine: true,
    ).allMatches(source);

    expect(releaseBuilds, hasLength(2));
    for (final build in releaseBuilds) {
      expect(build.group(0), isNot(contains('--no-pub')));
    }
  });

  test('release evidence remains bound to the triggering source commit', () {
    final source = workflow.readAsStringSync();
    const verifierCommand =
        r'../../scripts/verify_release_source.sh "$GITHUB_SHA"';

    expect(source, contains('- name: Verify resolved release source'));
    expect(source, contains('- name: Verify final release source'));
    expect(
      RegExp(
        '^\\s*run:\\s+${RegExp.escape(verifierCommand)}\$',
        multiLine: true,
      ).allMatches(source),
      hasLength(2),
    );

    final dependencyIndex = source.indexOf(
      '- name: Resolve Flutter dependencies',
    );
    final resolvedSourceIndex = source.indexOf(
      '- name: Verify resolved release source',
    );
    final sizeAnalysisIndex = source.indexOf(
      '- name: Analyze Android app size',
    );
    final finalSourceIndex = source.indexOf(
      '- name: Verify final release source',
    );
    final uploadIndex = source.indexOf('- name: Upload release evidence');

    expect(resolvedSourceIndex, greaterThan(dependencyIndex));
    expect(finalSourceIndex, greaterThan(sizeAnalysisIndex));
    expect(uploadIndex, greaterThan(finalSourceIndex));
  });

  test('release evidence contains build, symbol and SDK proof', () {
    final source = workflow.readAsStringSync();

    expect(source, contains('app-release.aab'));
    expect(source, contains('mapping/release/mapping.txt'));
    expect(source, contains('merged_manifests/release'));
    expect(source, contains(r'"$manifest_package" != "com.vinscent.vinscent"'));
    expect(source, contains(r'"$version_code" != "$BUILD_NUMBER"'));
    expect(source, contains(r'"$version_name" != "$app_version"'));
    expect(source, contains(r'"$min_sdk" != "24"'));
    expect(source, contains(r'(( target_sdk < 36 ))'));
    expect(source, contains('verify_android_manifest_permissions.dart'));
    expect(source, contains('verify_android_release_bundle.dart'));
    expect(source, contains('jarsigner -verify -verbose'));
    expect(source, contains('jar verified.'));
    expect(source, contains('keytool'));
    expect(source, contains('-printcert'));
    expect(source, contains('-exportcert'));
    expect(source, contains('openssl x509'));
    expect(source, contains('2033-10-23T00:00:00Z'));
    expect(source, contains('aab-signature.txt'));
    expect(source, contains('aab-signature.txt.sha256'));
    expect(source, contains('16kb-page-support.json'));
    expect(source, contains('page_alignment=16KB'));
    expect(source, contains('upload_signature=verified'));
    expect(source, contains('upload_certificate_match=verified'));
    expect(source, contains('upload_certificate_validity=verified'));
    expect(source, contains('play_upload_certificate_match=verified'));
    expect(source, contains('AndroidManifest.xml.sha256'));
    expect(source, contains('Analyze Android app size'));
    expect(source, contains('--analyze-size'));
    expect(source, contains('--target-platform android-arm64'));
    expect(source, contains(r'size_report_dir="$HOME/.flutter-devtools"'));
    expect(source, contains("'aab-code-size-analysis*.json'"));
    expect(source, contains(r'${#size_reports[@]} != 1'));
    expect(
      source,
      contains(r'sha256sum "${release_name}-code-size-analysis.json"'),
    );
    expect(
      source,
      contains(r'> "${release_name}-code-size-analysis.json.sha256"'),
    );
    expect(source, contains('size_analysis=flutter-code-size'));
    for (final metadataKey in const [
      'commit_sha',
      'package_name',
      'app_version',
      'build_number',
      'min_sdk',
      'target_sdk',
    ]) {
      expect(source, contains("$metadataKey=%s"));
    }
    expect(
      source,
      contains('BUNDLE-METADATA/com.android.tools.build.debugsymbols/'),
    );
    expect(source, contains('native_debug_symbols=embedded'));
    expect(source, contains('aab-contents.txt'));
    expect(source, contains('sha256sum'));
    expect(source, contains('actions/upload-artifact@'));
    expect(source, contains('if-no-files-found: error'));
    expect(
      source,
      isNot(matches(RegExp(r'path:\s+.*upload-keystore', multiLine: true))),
    );

    final evidenceIndex = source.indexOf('- name: Prepare release evidence');
    final sizeAnalysisIndex = source.indexOf(
      '- name: Analyze Android app size',
    );
    final uploadIndex = source.indexOf('- name: Upload release evidence');
    expect(evidenceIndex, greaterThanOrEqualTo(0));
    expect(sizeAnalysisIndex, greaterThan(evidenceIndex));
    expect(uploadIndex, greaterThan(sizeAnalysisIndex));
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
  'DANJJAN_PLAY_UPLOAD_CERT_SHA256',
];
