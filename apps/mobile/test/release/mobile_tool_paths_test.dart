import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/mobile_tool_paths.dart';

void main() {
  test('resolves mobile and repository paths from the tool script', () {
    final repository = Directory.systemTemp.uri.resolve(
      'danjjan-release-path-test/',
    );
    final script = repository.resolve(
      'apps/mobile/tool/verify_store_assets.dart',
    );
    final paths = MobileToolPaths.fromScript(script);

    expect(paths.mobileProject.uri, repository.resolve('apps/mobile/'));
    expect(paths.repositoryRoot.uri, repository);
    expect(
      paths.mobileFile('pubspec.yaml').uri,
      repository.resolve('apps/mobile/pubspec.yaml'),
    );
    expect(
      paths.repositoryFile('store-assets/google-play/app-icon-512.png').uri,
      repository.resolve('store-assets/google-play/app-icon-512.png'),
    );
  });
}
