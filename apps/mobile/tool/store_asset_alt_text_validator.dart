import 'dart:convert';
import 'dart:io';

final class StoreAssetAltTextValidator {
  const StoreAssetAltTextValidator();

  static const manifestPath = 'store-assets/google-play/alt-text.ko.json';
  static const maximumCharacterCount = 140;

  List<String> validate(
    File file, {
    Set<String> requiredTabletScenes = const {},
  }) {
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
    _validateGroup(
      decoded['phone'],
      'phone',
      requiredScenes: _phoneScenes,
      allowedScenes: _phoneScenes,
      errors: errors,
    );
    _validateGroup(
      decoded['tablet'],
      'tablet',
      requiredScenes: {..._minimumTabletScenes, ...requiredTabletScenes},
      allowedScenes: _phoneScenes,
      errors: errors,
    );
    return errors;
  }

  void _validateGroup(
    Object? value,
    String group, {
    required Set<String> requiredScenes,
    required Set<String> allowedScenes,
    required List<String> errors,
  }) {
    if (value is! Map<String, Object?>) {
      errors.add(_issue('format', '$group must be a JSON object.'));
      return;
    }

    _validateRequiredKeys(value, requiredScenes, group, errors);
    _validateAllowedKeys(value, allowedScenes, group, errors);
    for (final scene in requiredScenes) {
      _validateText(value[scene], '$group.$scene', errors);
    }
    for (final scene in value.keys.where(allowedScenes.contains)) {
      if (!requiredScenes.contains(scene)) {
        _validateText(value[scene], '$group.$scene', errors);
      }
    }
    _validateUniqueTexts(value, allowedScenes, group, errors);
  }

  void _validateKeys(
    Map<String, Object?> values,
    Set<String> expectedKeys,
    String group,
    List<String> errors,
  ) {
    _validateRequiredKeys(values, expectedKeys, group, errors);
    _validateAllowedKeys(values, expectedKeys, group, errors);
  }

  void _validateRequiredKeys(
    Map<String, Object?> values,
    Set<String> requiredKeys,
    String group,
    List<String> errors,
  ) {
    for (final key in requiredKeys.difference(values.keys.toSet())) {
      errors.add(_issue('missing', 'Missing alt text: $group.$key.'));
    }
  }

  void _validateAllowedKeys(
    Map<String, Object?> values,
    Set<String> allowedKeys,
    String group,
    List<String> errors,
  ) {
    for (final key in values.keys.toSet().difference(allowedKeys)) {
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

  void _validateUniqueTexts(
    Map<String, Object?> values,
    Set<String> allowedKeys,
    String group,
    List<String> errors,
  ) {
    final keysByText = <String, List<String>>{};
    for (final entry in values.entries) {
      if (!allowedKeys.contains(entry.key) || entry.value is! String) {
        continue;
      }
      final text = (entry.value! as String).trim();
      if (text.isEmpty) {
        continue;
      }
      keysByText.putIfAbsent(text, () => []).add(entry.key);
    }
    for (final keys in keysByText.values.where((keys) => keys.length > 1)) {
      keys.sort();
      errors.add(
        _issue(
          'duplicate',
          '$group alt text must be unique: ${keys.join(', ')}.',
        ),
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

const _minimumTabletScenes = <String>{'home', 'calendar', 'ai', 'settings'};
