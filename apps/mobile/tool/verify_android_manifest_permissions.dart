import 'dart:io';

import 'package:xml/xml.dart';

import 'android_manifest_permission_validator.dart';

void main(List<String> arguments) {
  if (arguments.length != 1) {
    stderr.writeln(
      'Usage: dart run tool/verify_android_manifest_permissions.dart '
      '<merged-AndroidManifest.xml>',
    );
    exitCode = 64;
    return;
  }

  final manifest = File(arguments.single);
  try {
    const AndroidManifestPermissionValidator().validate(
      manifest.readAsStringSync(),
    );
    stdout.writeln('Android release permission verification passed.');
  } on AndroidManifestPermissionValidationException catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  } on FileSystemException catch (error) {
    stderr.writeln(error.message);
    exitCode = 1;
  } on XmlParserException catch (error) {
    stderr.writeln(error.message);
    exitCode = 1;
  }
}
