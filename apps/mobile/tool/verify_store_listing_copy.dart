import 'dart:io';

import 'mobile_tool_paths.dart';
import 'store_listing_copy_validator.dart';

const _listingPath = 'docs/release/store-listing-copy-ko.md';

void main() {
  try {
    final paths = MobileToolPaths.fromScript(Platform.script);
    final file = paths.repositoryFile(_listingPath);
    if (!file.existsSync()) {
      throw StateError('Missing store listing copy: ${file.path}');
    }

    final copy = StoreListingCopy.parse(file.readAsStringSync());
    final errors = const StoreListingCopyValidator().validate(copy);
    if (errors.isNotEmpty) {
      stderr.writeln('Store listing copy verification failed:');
      for (final error in errors) {
        stderr.writeln('- $error');
      }
      exitCode = 1;
      return;
    }

    final metrics = copy.metrics;
    stdout.writeln('Store listing copy verification passed:');
    stdout.writeln('- app name: ${metrics.appNameCharacters}/30 characters');
    stdout.writeln(
      '- Play short description: '
      '${metrics.playShortDescriptionCharacters}/80 characters',
    );
    stdout.writeln(
      '- Play full description: '
      '${metrics.playFullDescriptionCharacters}/4000 characters',
    );
    stdout.writeln(
      '- App Store subtitle: '
      '${metrics.appStoreSubtitleCharacters}/30 characters',
    );
    stdout.writeln(
      '- App Store promotional text: '
      '${metrics.appStorePromotionalTextCharacters}/170 characters',
    );
    stdout.writeln(
      '- App Store keywords: '
      '${metrics.appStoreKeywordsBytes}/100 UTF-8 bytes',
    );
    stdout.writeln(
      '- App Store description: '
      '${metrics.appStoreDescriptionCharacters}/4000 characters',
    );
  } on Object catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  }
}
