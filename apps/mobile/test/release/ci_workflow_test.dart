import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final workflow = File('../../.github/workflows/ci.yml');
  final mobileVerification = File('../../scripts/verify_mobile_local.ps1');
  final iosVerification = File('../../scripts/verify_ios_local.sh');
  final databaseVerification = File('../../scripts/verify_database_local.ps1');

  test('CI validates every lightweight project boundary', () {
    expect(workflow.existsSync(), isTrue);
    final source = workflow.readAsStringSync();

    for (final job in _requiredCiJobs) {
      expect(source, contains('  $job:'));
    }
    for (final command in _requiredCiCommands) {
      expect(source, contains(command));
    }
    for (final job in _localOnlyJobs) {
      expect(source, isNot(contains('  $job:')));
    }
  });

  test('iOS native validation stays in the local macOS gate', () {
    expect(iosVerification.existsSync(), isTrue);
    final source = iosVerification.readAsStringSync();

    expect(source, contains('flutter test --no-pub'));
    expect(
      source,
      contains('flutter build ios --simulator --debug --no-codesign --no-pub'),
    );
  });

  test('Android native and integration validation stay in the local gate', () {
    expect(mobileVerification.existsSync(), isTrue);
    final source = mobileVerification.readAsStringSync();

    expect(source, contains(':app:testDebugUnitTest'));
    expect(source, contains('integration_test/app_startup_test.dart'));
    expect(source, contains('@("build", "apk", "--debug", "--no-pub")'));
  });

  test('database validation stays in the local Docker gate', () {
    expect(databaseVerification.existsSync(), isTrue);
    final source = databaseVerification.readAsStringSync();

    expect(source, contains('@("db", "reset", "--local", "--no-seed")'));
    expect(source, contains('@("test", "db")'));
    expect(source, contains('@("db", "lint", "--local", "--level", "error")'));
  });

  test(
    'CI uses least privilege and immutable actions without deployment secrets',
    () {
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
      expect(source, isNot(contains(r'${{ secrets.')));
      expect(source, isNot(contains('supabase db push')));
      expect(source, isNot(contains('supabase functions deploy')));
    },
  );
}

const _requiredCiJobs = <String>[
  'changes',
  'mobile',
  'node-services',
  'edge-functions',
];

const _requiredCiCommands = <String>[
  'dart format --output=none --set-exit-if-changed lib test integration_test',
  'flutter analyze --no-pub',
  'flutter test --no-pub',
  'node --test "tests/release/*.test.mjs"',
  'node scripts/verify_tracked_secrets.mjs',
  'npm test',
  'node scripts/test_supabase_functions.mjs',
  'deno check',
];

const _localOnlyJobs = <String>['android-integration', 'ios-build', 'database'];
