import 'dart:io';

import 'store_asset_validator.dart';

Future<void> main() async {
  final report = await StoreAssetValidator(
    repositoryRoot: Directory('../..'),
  ).validate();

  if (!report.isReady) {
    stderr.writeln('Store asset verification failed:');
    for (final error in report.errors) {
      stderr.writeln('- $error');
    }
    exitCode = 1;
    return;
  }

  stdout.writeln(
    'Store asset verification passed '
    '(${report.validatedFileCount} files).',
  );
}
