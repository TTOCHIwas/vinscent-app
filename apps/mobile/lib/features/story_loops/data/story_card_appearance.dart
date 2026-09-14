import 'dart:ui';

abstract final class StoryCardThemeId {
  static const plain = 'plain';
}

const storyCardBackgroundColorPalette = <Color>[
  Color(0xFFFFFFFF),
  Color(0xFFF1F1F1),
  Color(0xFFFFD8D2),
  Color(0xFFF4E5B8),
  Color(0xFFD9E7D5),
  Color(0xFFD9E4F2),
  Color(0xFFE6DDF0),
  Color(0xFF222222),
];

class StoryCardAppearance {
  const StoryCardAppearance({
    this.themeId = StoryCardThemeId.plain,
    this.backgroundColor = const Color(0xFFFFFFFF),
  });

  const StoryCardAppearance.dark()
    : themeId = StoryCardThemeId.plain,
      backgroundColor = const Color(0xFF000000);

  factory StoryCardAppearance.fromJson(
    Object? value, {
    Color fallbackBackgroundColor = const Color(0xFFFFFFFF),
  }) {
    if (value is! Map) {
      return StoryCardAppearance(backgroundColor: fallbackBackgroundColor);
    }
    final json = Map<String, dynamic>.from(value);
    final serializedThemeId = json['theme_id'];
    final themeId = serializedThemeId is String && serializedThemeId.isNotEmpty
        ? serializedThemeId
        : StoryCardThemeId.plain;
    return StoryCardAppearance(
      themeId: themeId,
      backgroundColor: _colorFromJson(
        json['background_color'],
        fallback: fallbackBackgroundColor,
      ),
    );
  }

  final String themeId;
  final Color backgroundColor;

  Color get contentColor => backgroundColor.computeLuminance() > 0.45
      ? const Color(0xFF222222)
      : const Color(0xFFFFFFFF);

  StoryCardAppearance copyWith({String? themeId, Color? backgroundColor}) {
    return StoryCardAppearance(
      themeId: themeId ?? this.themeId,
      backgroundColor: backgroundColor ?? this.backgroundColor,
    );
  }

  Map<String, dynamic> toJson() => {
    'theme_id': themeId,
    'background_color': _colorToJson(backgroundColor),
  };

  @override
  bool operator ==(Object other) {
    return other is StoryCardAppearance &&
        other.themeId == themeId &&
        other.backgroundColor == backgroundColor;
  }

  @override
  int get hashCode => Object.hash(themeId, backgroundColor);
}

String _colorToJson(Color color) {
  return '#${color.toARGB32().toRadixString(16).padLeft(8, '0')}';
}

Color _colorFromJson(Object? value, {required Color fallback}) {
  if (value is! String) {
    return fallback;
  }
  final hex = value.replaceFirst('#', '');
  final normalized = hex.length == 6 ? 'ff$hex' : hex;
  if (normalized.length != 8) {
    return fallback;
  }
  final parsed = int.tryParse(normalized, radix: 16);
  return parsed == null ? fallback : Color(parsed);
}
