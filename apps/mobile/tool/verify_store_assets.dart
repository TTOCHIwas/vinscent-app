import 'dart:io';

import 'mobile_tool_paths.dart';
import 'store_asset_validator.dart';
import 'store_asset_verification_options.dart';

Future<void> main(List<String> arguments) async {
  late final StoreAssetVerificationOptions options;
  try {
    options = StoreAssetVerificationOptions.parse(arguments);
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    stderr.writeln(StoreAssetVerificationOptions.usage);
    exitCode = 2;
    return;
  }

  final paths = MobileToolPaths.fromScript(Platform.script);
  final report = await StoreAssetValidator(
    repositoryRoot: paths.repositoryRoot,
  ).validate(appVersion: options.appVersion, buildNumber: options.buildNumber);

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
