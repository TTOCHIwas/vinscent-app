import 'dart:convert';
import 'dart:io';

final class StoreAssetAltTextValidator {
  const StoreAssetAltTextValidator();

  static const manifestPath = 'store-assets/google-play/alt-text.ko.json';
  static const maximumCharacterCount = 140;

  List<String> validate(File file) {
    if (!file.existsSync()) {
      return [_issue('missing', 'Required Play alt-text manifest is missing.')];
    }

    late final Object? decoded;
    try {
      decoded = jsonDecode(file.readAsStringSync());
    } on Object {
      return [_issue('format', 'Alt-text manifest must be valid JSON.')];
    }
    if (decoded is! Map<String, Object?>) {
      return [_issue('format', 'Alt-text manifest must be a JSON object.')];
    }

    final errors = <String>[];
    _validateKeys(
      decoded,
      const {'featureGraphic', 'phone', 'tablet'},
      'root',
      errors,
    );
    _validateText(decoded['featureGraphic'], 'featureGraphic', errors);
    _validateGroup(decoded['phone'], 'phone', _phoneScenes, errors);
    _validateGroup(decoded['tablet'], 'tablet', _tabletScenes, errors);
    return errors;
  }

  void _validateGroup(
    Object? value,
    String group,
    Set<String> requiredScenes,
    List<String> errors,
  ) {
    if (value is! Map<String, Object?>) {
      errors.add(_issue('format', '$group must be a JSON object.'));
      return;
    }

    _validateKeys(value, requiredScenes, group, errors);
    for (final scene in requiredScenes) {
      _validateText(value[scene], '$group.$scene', errors);
    }
  }

  void _validateKeys(
    Map<String, Object?> values,
    Set<String> expectedKeys,
    String group,
    List<String> errors,
  ) {
    final actualKeys = values.keys.toSet();
    for (final key in expectedKeys.difference(actualKeys)) {
      errors.add(_issue('missing', 'Missing alt text: $group.$key.'));
    }
    for (final key in actualKeys.difference(expectedKeys)) {
      errors.add(_issue('key', 'Unknown alt-text key: $group.$key.'));
    }
  }

  void _validateText(Object? value, String key, List<String> errors) {
    if (value is! String || value.trim().isEmpty) {
      errors.add(_issue('content', '$key must contain alt text.'));
      return;
    }
    if (value.runes.length > maximumCharacterCount) {
      errors.add(
        _issue('length', '$key exceeds $maximumCharacterCount characters.'),
      );
    }
  }

  String _issue(String code, String message) =>
      '$manifestPath [$code] $message';
}

const _phoneScenes = <String>{
  'home',
  'card-editor',
  'question-answer',
  'calendar',
  'recording-library',
  'ai',
  'widgets',
  'settings',
};

const _tabletScenes = <String>{'home', 'calendar', 'ai', 'settings'};
