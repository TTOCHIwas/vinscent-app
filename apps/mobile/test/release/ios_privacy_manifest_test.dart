import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

void main() {
  final runnerManifest = File('ios/Runner/PrivacyInfo.xcprivacy');
  final widgetManifest = File('ios/VinscentWidgets/PrivacyInfo.xcprivacy');
  final xcodeProject = File('ios/Runner.xcodeproj/project.pbxproj');

  test('iOS app and widget bundle their own privacy manifests', () {
    expect(runnerManifest.existsSync(), isTrue);
    expect(widgetManifest.existsSync(), isTrue);

    final project = xcodeProject.readAsStringSync();
    expect(_occurrences(project, 'PrivacyInfo.xcprivacy in Resources'), 4);
    expect(_occurrences(project, 'path = PrivacyInfo.xcprivacy;'), 2);
  });

  test('Runner declares collected data without tracking', () {
    final manifest = _readPlist(runnerManifest);

    expect(manifest['NSPrivacyTracking'], isFalse);
    expect(manifest['NSPrivacyTrackingDomains'], isEmpty);

    final collectedData = _collectedDataContracts(manifest);
    expect(
      collectedData.keys,
      unorderedEquals(_runnerCollectedDataContracts.keys),
    );
    for (final entry in _runnerCollectedDataContracts.entries) {
      expect(collectedData[entry.key], entry.value, reason: entry.key);
    }
  });

  test('required reason APIs match native app and widget usage', () {
    final runner = _readPlist(runnerManifest);
    final widget = _readPlist(widgetManifest);

    expect(_accessedApiReasons(runner), _runnerAccessedApiReasons);
    expect(_accessedApiReasons(widget), _widgetAccessedApiReasons);
    expect(widget['NSPrivacyTracking'], isFalse);
    expect(widget['NSPrivacyTrackingDomains'], isEmpty);
    expect(widget['NSPrivacyCollectedDataTypes'], isEmpty);
  });
}

const _appFunctionality = 'NSPrivacyCollectedDataTypePurposeAppFunctionality';
const _productPersonalization =
    'NSPrivacyCollectedDataTypePurposeProductPersonalization';

const _runnerCollectedDataContracts = <String, _CollectedDataContract>{
  'NSPrivacyCollectedDataTypeName': _CollectedDataContract({_appFunctionality}),
  'NSPrivacyCollectedDataTypeEmailAddress': _CollectedDataContract({
    _appFunctionality,
  }),
  'NSPrivacyCollectedDataTypeCoarseLocation': _CollectedDataContract({
    _productPersonalization,
  }),
  'NSPrivacyCollectedDataTypePhotosorVideos': _CollectedDataContract({
    _appFunctionality,
  }),
  'NSPrivacyCollectedDataTypeAudioData': _CollectedDataContract({
    _appFunctionality,
  }),
  'NSPrivacyCollectedDataTypeOtherUserContent': _CollectedDataContract({
    _appFunctionality,
    _productPersonalization,
  }),
  'NSPrivacyCollectedDataTypeSearchHistory': _CollectedDataContract({
    _appFunctionality,
    _productPersonalization,
  }),
  'NSPrivacyCollectedDataTypeUserID': _CollectedDataContract({
    _appFunctionality,
  }),
  'NSPrivacyCollectedDataTypeDeviceID': _CollectedDataContract({
    _appFunctionality,
  }),
  'NSPrivacyCollectedDataTypeProductInteraction': _CollectedDataContract({
    _appFunctionality,
    _productPersonalization,
  }),
  'NSPrivacyCollectedDataTypeOtherDiagnosticData': _CollectedDataContract({
    _appFunctionality,
  }),
  'NSPrivacyCollectedDataTypeOtherDataTypes': _CollectedDataContract({
    _appFunctionality,
    _productPersonalization,
  }),
};

const _runnerAccessedApiReasons = <String, Set<String>>{
  'NSPrivacyAccessedAPICategoryFileTimestamp': {'C617.1'},
  'NSPrivacyAccessedAPICategoryUserDefaults': {'CA92.1', '1C8F.1'},
};

const _widgetAccessedApiReasons = <String, Set<String>>{
  'NSPrivacyAccessedAPICategoryFileTimestamp': {'C617.1'},
  'NSPrivacyAccessedAPICategoryUserDefaults': {'1C8F.1'},
};

Map<String, Object?> _readPlist(File file) {
  final document = XmlDocument.parse(file.readAsStringSync());
  final plistValues = document.rootElement.childElements.toList();
  if (document.rootElement.name.local != 'plist' || plistValues.length != 1) {
    throw FormatException('Expected one plist root value in ${file.path}.');
  }

  final value = _parsePlistValue(plistValues.single);
  if (value is! Map<String, Object?>) {
    throw FormatException('Expected a plist dictionary in ${file.path}.');
  }
  return value;
}

Object? _parsePlistValue(XmlElement element) {
  return switch (element.name.local) {
    'dict' => _parsePlistDictionary(element),
    'array' => element.childElements.map(_parsePlistValue).toList(),
    'string' => element.innerText,
    'true' => true,
    'false' => false,
    _ => throw FormatException(
      'Unsupported plist element: ${element.name.local}.',
    ),
  };
}

Map<String, Object?> _parsePlistDictionary(XmlElement element) {
  final children = element.childElements.toList();
  if (children.length.isOdd) {
    throw const FormatException('A plist dictionary must contain key pairs.');
  }

  final result = <String, Object?>{};
  for (var index = 0; index < children.length; index += 2) {
    final keyElement = children[index];
    if (keyElement.name.local != 'key') {
      throw const FormatException('A plist dictionary key is missing.');
    }

    final key = keyElement.innerText;
    if (result.containsKey(key)) {
      throw FormatException('Duplicate plist key: $key.');
    }
    result[key] = _parsePlistValue(children[index + 1]);
  }
  return result;
}

Map<String, _CollectedDataContract> _collectedDataContracts(
  Map<String, Object?> manifest,
) {
  final entries = _dictionaryList(
    manifest['NSPrivacyCollectedDataTypes'],
    'NSPrivacyCollectedDataTypes',
  );
  final result = <String, _CollectedDataContract>{};
  for (final entry in entries) {
    final dataType = _requiredString(entry, 'NSPrivacyCollectedDataType');
    if (result.containsKey(dataType)) {
      throw FormatException('Duplicate collected data type: $dataType.');
    }

    result[dataType] = _CollectedDataContract(
      _stringSet(
        entry['NSPrivacyCollectedDataTypePurposes'],
        'NSPrivacyCollectedDataTypePurposes',
      ),
      linked: _requiredBool(entry, 'NSPrivacyCollectedDataTypeLinked'),
      tracking: _requiredBool(entry, 'NSPrivacyCollectedDataTypeTracking'),
    );
  }
  return result;
}

Map<String, Set<String>> _accessedApiReasons(Map<String, Object?> manifest) {
  final entries = _dictionaryList(
    manifest['NSPrivacyAccessedAPITypes'],
    'NSPrivacyAccessedAPITypes',
  );
  final result = <String, Set<String>>{};
  for (final entry in entries) {
    final apiType = _requiredString(entry, 'NSPrivacyAccessedAPIType');
    if (result.containsKey(apiType)) {
      throw FormatException('Duplicate accessed API type: $apiType.');
    }
    result[apiType] = _stringSet(
      entry['NSPrivacyAccessedAPITypeReasons'],
      'NSPrivacyAccessedAPITypeReasons',
    );
  }
  return result;
}

List<Map<String, Object?>> _dictionaryList(Object? value, String key) {
  if (value is! List<Object?>) {
    throw FormatException('$key must be an array.');
  }
  return value.map((entry) {
    if (entry is! Map<String, Object?>) {
      throw FormatException('$key must contain dictionaries.');
    }
    return entry;
  }).toList();
}

Set<String> _stringSet(Object? value, String key) {
  if (value is! List<Object?> || value.any((entry) => entry is! String)) {
    throw FormatException('$key must be a string array.');
  }
  final values = value.cast<String>().toSet();
  if (values.length != value.length) {
    throw FormatException('$key must not contain duplicates.');
  }
  return values;
}

String _requiredString(Map<String, Object?> dictionary, String key) {
  final value = dictionary[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('$key must be a non-empty string.');
  }
  return value;
}

bool _requiredBool(Map<String, Object?> dictionary, String key) {
  final value = dictionary[key];
  if (value is! bool) {
    throw FormatException('$key must be a boolean.');
  }
  return value;
}

class _CollectedDataContract {
  const _CollectedDataContract(
    this.purposes, {
    this.linked = true,
    this.tracking = false,
  });

  final Set<String> purposes;
  final bool linked;
  final bool tracking;

  @override
  bool operator ==(Object other) {
    return other is _CollectedDataContract &&
        linked == other.linked &&
        tracking == other.tracking &&
        purposes.length == other.purposes.length &&
        purposes.containsAll(other.purposes);
  }

  @override
  int get hashCode =>
      Object.hash(linked, tracking, Object.hashAllUnordered(purposes));
}

int _occurrences(String source, String pattern) {
  return pattern.allMatches(source).length;
}
