import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final workflow = File('../../.github/workflows/store-assets.yml');

  test('store assets are verified only by an explicit request', () {
    expect(workflow.existsSync(), isTrue);
    final source = workflow.readAsStringSync();

    expect(source, contains('workflow_dispatch:'));
    expect(source, isNot(contains('pull_request:')));
    expect(source, isNot(matches(RegExp(r'^\s+push:', multiLine: true))));
    expect(source, contains('app_version:'));
    expect(source, contains('build_number:'));
  });

  test('workflow validates the release identity and repository assets', () {
    final source = workflow.readAsStringSync();

    expect(source, contains(r'^[0-9]+\.[0-9]+\.[0-9]+$'));
    expect(source, contains(r'^[1-9][0-9]*$'));
    expect(source, contains('flutter pub get'));
    expect(source, contains('dart run tool/verify_store_listing_copy.dart'));
    expect(source, contains('dart run tool/verify_store_assets.dart'));
    expect(source, contains('--app-version "\$APP_VERSION"'));
    expect(source, contains('--build-number "\$BUILD_NUMBER"'));
  });

  test('verified assets remain bound to the triggering source commit', () {
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
    final assetIndex = source.indexOf('- name: Verify store assets');
    final finalSourceIndex = source.indexOf(
      '- name: Verify final release source',
    );
    final summaryIndex = source.indexOf('- name: Summarize verified assets');

    expect(resolvedSourceIndex, greaterThan(dependencyIndex));
    expect(finalSourceIndex, greaterThan(assetIndex));
    expect(summaryIndex, greaterThan(finalSourceIndex));
  });

  test('workflow uses least privilege and immutable actions', () {
    final source = workflow.readAsStringSync();
    final actionReferences = RegExp(
      r'^\s*-\s+uses:\s+[^@\s]+@([^\s#]+)',
      multiLine: true,
    ).allMatches(source);

    expect(source, matches(RegExp(r'permissions:\r?\n\s+contents:\s+read')));
    expect(source, contains('persist-credentials: false'));
    expect(source, contains('timeout-minutes: 15'));
    expect(actionReferences, isNotEmpty);
    for (final reference in actionReferences) {
      expect(reference.group(1), matches(RegExp(r'^[0-9a-f]{40}$')));
    }
    expect(source, isNot(contains(r'${{ secrets.')));
  });
}
