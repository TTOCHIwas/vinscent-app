import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final verifier = File('../../scripts/verify_release_source.sh');

  test('release source verifier binds artifacts to an exact clean commit', () {
    expect(verifier.existsSync(), isTrue);

    final source = verifier.readAsStringSync();

    expect(source, startsWith('#!/usr/bin/env bash'));
    expect(source, contains('set -euo pipefail'));
    expect(source, contains(r'[[ $# -ne 1 ||'));
    expect(source, contains(r'^[0-9a-f]{40}$'));
    expect(source, contains(r'git -C "$repository_root" rev-parse HEAD'));
    expect(
      source,
      contains(
        r'git -C "$repository_root" status --porcelain --untracked-files=all',
      ),
    );
    expect(source, contains('Release source commit'));
    expect(source, contains('Release source worktree must be clean.'));
    expect(source, contains(r'dirty_worktree="$('));
    expect(
      source,
      contains(r'''printf '%s\n' "$dirty_worktree" >&2'''),
    );
    expect(source, isNot(contains('git status --short')));
    expect(source, isNot(contains('dirname')));
  });
}
