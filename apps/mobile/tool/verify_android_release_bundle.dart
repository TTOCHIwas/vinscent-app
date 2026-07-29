import 'dart:convert';
import 'dart:io';

import 'android_release_bundle_validator.dart';

void main(List<String> arguments) {
  if (arguments.length != 2) {
    stderr.writeln(
      'Usage: dart run tool/verify_android_release_bundle.dart '
      '<app-release.aab> <report.json>',
    );
    exitCode = 64;
    return;
  }

  final bundle = File(arguments[0]);
  final reportFile = File(arguments[1]);

  try {
    final report = const AndroidReleaseBundleValidator().validate(bundle);
    reportFile.parent.createSync(recursive: true);
    reportFile.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(report.toJson())}\n',
    );
    stdout.writeln(
      'Android release bundle verification passed '
      '(${report.nativeLibraries.length} native libraries).',
    );
  } on AndroidReleaseBundleValidationException catch (error) {
    stderr.writeln(error.message);
    exitCode = 1;
  } on FileSystemException catch (error) {
    stderr.writeln(error.message);
    exitCode = 1;
  }
}
