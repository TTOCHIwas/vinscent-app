import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final workflow = File('../../.github/workflows/ci.yml');

  test('CI validates every release-critical project boundary', () {
    expect(workflow.existsSync(), isTrue);
    final source = workflow.readAsStringSync();

    for (final job in _requiredJobs) {
      expect(source, contains('  $job:'));
    }
    for (final command in _requiredCommands) {
      expect(source, contains(command));
    }
  });

  test('CI uses least privilege and immutable actions without deployment secrets', () {
    final source = workflow.readAsStringSync();
    final actionReferences = RegExp(
      r'^\s*-\s+uses:\s+[^@\s]+@([^\s#]+)',
      multiLine: true,
    ).allMatches(source);

    expect(
      source,
      matches(RegExp(r'permissions:\r?\n\s+contents:\s+read')),
    );
    expect(actionReferences, isNotEmpty);
    for (final reference in actionReferences) {
      expect(reference.group(1), matches(RegExp(r'^[0-9a-f]{40}$')));
    }
    expect(source, isNot(contains(r'${{ secrets.')));
    expect(source, isNot(contains('supabase db push')));
    expect(source, isNot(contains('supabase functions deploy')));
  });
}

const _requiredJobs = <String>[
  'mobile',
  'node-services',
  'edge-functions',
  'database',
];

const _requiredCommands = <String>[
  'flutter analyze --no-pub',
  'flutter test --no-pub',
  'flutter build apk --debug --no-pub',
  'npm test',
  'node scripts/test_supabase_functions.mjs',
  'deno check',
  'supabase db start',
  'supabase test db',
];
