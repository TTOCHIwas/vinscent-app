class AndroidReleaseIdentity {
  const AndroidReleaseIdentity({
    required this.commitSha,
    required this.packageName,
    required this.appVersion,
    required this.buildNumber,
    required this.minSdk,
    required this.targetSdk,
  });

  factory AndroidReleaseIdentity.parse(String source) {
    final values = <String, String>{};
    for (final rawLine in source.split(RegExp(r'\r?\n'))) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        continue;
      }

      final separatorIndex = line.indexOf('=');
      if (separatorIndex <= 0) {
        throw const FormatException(
          'Release metadata contains a malformed entry.',
        );
      }

      final key = line.substring(0, separatorIndex).trim();
      final value = line.substring(separatorIndex + 1).trim();
      if (value.isEmpty) {
        throw FormatException('Release metadata value is empty: $key');
      }
      if (values.containsKey(key)) {
        throw FormatException('Release metadata key is duplicated: $key');
      }
      values[key] = value;
    }

    return AndroidReleaseIdentity(
      commitSha: _requiredValue(values, 'commit_sha'),
      packageName: _requiredValue(values, 'package_name'),
      appVersion: _requiredValue(values, 'app_version'),
      buildNumber: _requiredPositiveInteger(values, 'build_number'),
      minSdk: _requiredPositiveInteger(values, 'min_sdk'),
      targetSdk: _requiredPositiveInteger(values, 'target_sdk'),
    );
  }

  final String commitSha;
  final String packageName;
  final String appVersion;
  final int buildNumber;
  final int minSdk;
  final int targetSdk;

  void validateAgainstSource({
    required String checkoutCommitSha,
    required String sourceAppVersion,
    required String expectedPackageName,
    required int expectedMinSdk,
    required int minimumTargetSdk,
  }) {
    if (!RegExp(r'^[0-9a-f]{40}$').hasMatch(commitSha)) {
      throw StateError('Release metadata contains an invalid commit SHA.');
    }
    if (commitSha != checkoutCommitSha.trim().toLowerCase()) {
      throw StateError(
        'Release metadata commit does not match the current checkout.',
      );
    }
    if (packageName != expectedPackageName) {
      throw StateError(
        'Release metadata package does not match $expectedPackageName.',
      );
    }

    final sourceVersionName = sourceAppVersion.split('+').first;
    if (appVersion != sourceVersionName) {
      throw StateError(
        'Release metadata version does not match the current source.',
      );
    }
    if (minSdk != expectedMinSdk) {
      throw StateError('Release metadata minimum SDK must be $expectedMinSdk.');
    }
    if (targetSdk < minimumTargetSdk) {
      throw StateError(
        'Release metadata target SDK must be $minimumTargetSdk or later.',
      );
    }
  }

  Map<String, Object> toJson() => <String, Object>{
    'commitSha': commitSha,
    'packageName': packageName,
    'appVersion': appVersion,
    'buildNumber': buildNumber,
    'minSdk': minSdk,
    'targetSdk': targetSdk,
  };
}

Map<String, Object?> parseInstalledPackageMetadata(String packageDump) {
  String? valueFor(String name) {
    return RegExp(
      '(?:^|\\s)${RegExp.escape(name)}=(\\S+)',
      multiLine: true,
    ).firstMatch(packageDump)?.group(1);
  }

  return <String, Object?>{
    'versionName': valueFor('versionName'),
    'versionCode': int.tryParse(valueFor('versionCode') ?? ''),
    'minSdk': int.tryParse(valueFor('minSdk') ?? ''),
    'targetSdk': int.tryParse(valueFor('targetSdk') ?? ''),
    'debuggable': RegExp(
      r'^\s*flags=\[[^\]]*\bDEBUGGABLE\b',
      multiLine: true,
    ).hasMatch(packageDump),
  };
}

void validateInstalledReleasePackage(
  Map<String, Object?> metadata, {
  required AndroidReleaseIdentity releaseIdentity,
}) {
  if (metadata['versionName'] != releaseIdentity.appVersion) {
    throw StateError(
      'Installed version name does not match the release candidate.',
    );
  }
  if (metadata['versionCode'] != releaseIdentity.buildNumber) {
    throw StateError(
      'Installed version code does not match the release candidate.',
    );
  }
  if (metadata['minSdk'] != releaseIdentity.minSdk) {
    throw StateError(
      'Installed minimum SDK does not match the release candidate.',
    );
  }
  if (metadata['targetSdk'] != releaseIdentity.targetSdk) {
    throw StateError(
      'Installed target SDK does not match the release candidate.',
    );
  }
  if (metadata['debuggable'] != false) {
    throw StateError(
      'Cold-start release evidence requires a non-debuggable build.',
    );
  }
}

String _requiredValue(Map<String, String> values, String key) {
  final value = values[key];
  if (value == null) {
    throw FormatException('Release metadata is missing $key.');
  }
  return value;
}

int _requiredPositiveInteger(Map<String, String> values, String key) {
  final rawValue = _requiredValue(values, key);
  final value = int.tryParse(rawValue);
  if (value == null || value <= 0) {
    throw FormatException('Release metadata $key must be a positive integer.');
  }
  return value;
}
