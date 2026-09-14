import 'dart:convert';

import 'package:characters/characters.dart';

final class StoreListingCopy {
  const StoreListingCopy({
    required this.appName,
    required this.playShortDescription,
    required this.playFullDescription,
    required this.appStoreSubtitle,
    required this.appStorePromotionalText,
    required this.appStoreKeywords,
    required this.appStoreDescription,
  });

  factory StoreListingCopy.parse(String source) {
    final sections = _QuotedMarkdownSections(source);
    return StoreListingCopy(
      appName: sections.read('## 1. 공통 이름'),
      playShortDescription: sections.read('### 짧은 설명'),
      playFullDescription: sections.read('### 전체 설명'),
      appStoreSubtitle: sections.read('### 부제'),
      appStorePromotionalText: sections.read('### 프로모션 텍스트'),
      appStoreKeywords: sections.read('### 키워드'),
      appStoreDescription: sections.read('### 설명'),
    );
  }

  final String appName;
  final String playShortDescription;
  final String playFullDescription;
  final String appStoreSubtitle;
  final String appStorePromotionalText;
  final String appStoreKeywords;
  final String appStoreDescription;

  StoreListingCopyMetrics get metrics => StoreListingCopyMetrics(
    appNameCharacters: appName.characters.length,
    playShortDescriptionCharacters: playShortDescription.characters.length,
    playFullDescriptionCharacters: playFullDescription.characters.length,
    appStoreSubtitleCharacters: appStoreSubtitle.characters.length,
    appStorePromotionalTextCharacters:
        appStorePromotionalText.characters.length,
    appStoreKeywordsBytes: utf8.encode(appStoreKeywords).length,
    appStoreDescriptionCharacters: appStoreDescription.characters.length,
  );
}

final class StoreListingCopyMetrics {
  const StoreListingCopyMetrics({
    required this.appNameCharacters,
    required this.playShortDescriptionCharacters,
    required this.playFullDescriptionCharacters,
    required this.appStoreSubtitleCharacters,
    required this.appStorePromotionalTextCharacters,
    required this.appStoreKeywordsBytes,
    required this.appStoreDescriptionCharacters,
  });

  final int appNameCharacters;
  final int playShortDescriptionCharacters;
  final int playFullDescriptionCharacters;
  final int appStoreSubtitleCharacters;
  final int appStorePromotionalTextCharacters;
  final int appStoreKeywordsBytes;
  final int appStoreDescriptionCharacters;
}

final class StoreListingCopyValidator {
  const StoreListingCopyValidator();

  List<String> validate(StoreListingCopy copy) {
    final errors = <String>[];

    _validateRequired('appName', copy.appName, errors);
    _validateRequired(
      'googlePlay.shortDescription',
      copy.playShortDescription,
      errors,
    );
    _validateRequired(
      'googlePlay.fullDescription',
      copy.playFullDescription,
      errors,
    );
    _validateRequired('appStore.subtitle', copy.appStoreSubtitle, errors);
    _validateRequired(
      'appStore.promotionalText',
      copy.appStorePromotionalText,
      errors,
    );
    _validateRequired('appStore.keywords', copy.appStoreKeywords, errors);
    _validateRequired('appStore.description', copy.appStoreDescription, errors);

    _validateSingleLine('appName', copy.appName, errors);
    _validateSingleLine(
      'googlePlay.shortDescription',
      copy.playShortDescription,
      errors,
    );
    _validateSingleLine('appStore.subtitle', copy.appStoreSubtitle, errors);
    _validateSingleLine(
      'appStore.promotionalText',
      copy.appStorePromotionalText,
      errors,
    );
    _validateSingleLine('appStore.keywords', copy.appStoreKeywords, errors);

    final metrics = copy.metrics;
    if (metrics.appNameCharacters < 2) {
      errors.add('appName must contain at least 2 characters.');
    }
    _validateMaximum(
      'appName',
      metrics.appNameCharacters,
      30,
      'characters',
      errors,
    );
    _validateMaximum(
      'googlePlay.shortDescription',
      metrics.playShortDescriptionCharacters,
      80,
      'characters',
      errors,
    );
    _validateMaximum(
      'googlePlay.fullDescription',
      metrics.playFullDescriptionCharacters,
      4000,
      'characters',
      errors,
    );
    _validateMaximum(
      'appStore.subtitle',
      metrics.appStoreSubtitleCharacters,
      30,
      'characters',
      errors,
    );
    _validateMaximum(
      'appStore.promotionalText',
      metrics.appStorePromotionalTextCharacters,
      170,
      'characters',
      errors,
    );
    _validateMaximum(
      'appStore.keywords',
      metrics.appStoreKeywordsBytes,
      100,
      'UTF-8 bytes',
      errors,
    );
    _validateMaximum(
      'appStore.description',
      metrics.appStoreDescriptionCharacters,
      4000,
      'characters',
      errors,
    );

    _validateKeywords(copy, errors);
    _validatePlainText(
      'appStore.description',
      copy.appStoreDescription,
      errors,
    );
    if (copy.appStoreDescription != copy.playFullDescription) {
      errors.add(
        'appStore.description must exactly match '
        'googlePlay.fullDescription.',
      );
    }
    if (copy.appStorePromotionalText != copy.playShortDescription) {
      errors.add(
        'appStore.promotionalText must exactly match '
        'googlePlay.shortDescription.',
      );
    }

    errors.sort();
    return List.unmodifiable(errors);
  }

  void _validateRequired(String field, String value, List<String> errors) {
    if (value.trim().isEmpty) {
      errors.add('$field is required.');
    }
    if (value != value.trim()) {
      errors.add('$field must not have surrounding whitespace.');
    }
  }

  void _validateSingleLine(String field, String value, List<String> errors) {
    if (value.contains('\n') || value.contains('\r')) {
      errors.add('$field must be a single line.');
    }
  }

  void _validateMaximum(
    String field,
    int actual,
    int maximum,
    String unit,
    List<String> errors,
  ) {
    if (actual > maximum) {
      errors.add('$field exceeds $maximum $unit.');
    }
  }

  void _validateKeywords(StoreListingCopy copy, List<String> errors) {
    final keywords = copy.appStoreKeywords.split(',');
    if (keywords.any((keyword) => keyword.trim().isEmpty)) {
      errors.add('appStore.keywords must not contain empty keywords.');
      return;
    }

    final normalized = <String, String>{};
    for (final keyword in keywords) {
      if (keyword != keyword.trim()) {
        errors.add(
          'appStore.keywords must not contain whitespace around commas.',
        );
      }
      final key = keyword.trim().toLowerCase();
      final existing = normalized[key];
      if (existing != null) {
        errors.add(
          'appStore.keywords contains duplicate keyword: ${keyword.trim()}.',
        );
      } else {
        normalized[key] = keyword.trim();
      }
    }
    if (normalized.containsKey(copy.appName.toLowerCase())) {
      errors.add('appStore.keywords must not repeat the app name.');
    }
  }

  void _validatePlainText(String field, String value, List<String> errors) {
    if (RegExp(r'</?[A-Za-z][^>]*>').hasMatch(value)) {
      errors.add('$field must use plain text without HTML.');
    }
  }
}

final class _QuotedMarkdownSections {
  _QuotedMarkdownSections(String source)
    : _lines = source.split(RegExp(r'\r?\n'));

  final List<String> _lines;

  String read(String heading) {
    final headingIndexes = <int>[
      for (var index = 0; index < _lines.length; index += 1)
        if (_lines[index].trim() == heading) index,
    ];
    if (headingIndexes.length != 1) {
      throw FormatException('$heading must appear exactly once.');
    }

    final quotedLines = <String>[];
    for (
      var index = headingIndexes.single + 1;
      index < _lines.length;
      index += 1
    ) {
      final line = _lines[index];
      if (line.trimLeft().startsWith('#')) {
        break;
      }
      if (line == '>') {
        quotedLines.add('');
      } else if (line.startsWith('> ')) {
        quotedLines.add(line.substring(2).trim());
      }
    }
    if (quotedLines.isEmpty) {
      throw FormatException('$heading must contain a quoted value.');
    }

    final paragraphs = <String>[];
    var paragraphLines = <String>[];
    void flushParagraph() {
      if (paragraphLines.isEmpty) {
        return;
      }
      paragraphs.add(paragraphLines.join(' '));
      paragraphLines = <String>[];
    }

    for (final line in quotedLines) {
      if (line.isEmpty) {
        flushParagraph();
      } else {
        paragraphLines.add(line);
      }
    }
    flushParagraph();

    final value = paragraphs.join('\n\n').trim();
    if (value.isEmpty) {
      throw FormatException('$heading must contain a quoted value.');
    }
    return value;
  }
}
