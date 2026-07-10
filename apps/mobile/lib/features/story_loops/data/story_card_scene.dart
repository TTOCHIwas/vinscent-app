import 'dart:convert';

import 'package:flutter/material.dart';

const storyCardColorPalette = [
  Color(0xFF111111),
  Color(0xFFFFFFFF),
  Color(0xFFE94B5F),
  Color(0xFFF4932F),
  Color(0xFFF7D748),
  Color(0xFF39B871),
  Color(0xFF3E8EDE),
  Color(0xFF8C5BEA),
  Color(0xFFE56BAA),
];

const storyCardThinStrokeWidth = 0.012;
const storyCardNormalStrokeWidth = 0.022;
const storyCardThickStrokeWidth = 0.038;
const storyCardMinStrokeWidth = storyCardThinStrokeWidth;
const storyCardMaxStrokeWidth = storyCardThickStrokeWidth;
const storyCardMaxTextLayers = 10;
const storyCardMaxTextCharactersPerLayer = 500;
const storyCardMaxTextCharacters = 5000;

class StoryCardScene {
  const StoryCardScene({
    required this.backgroundTransform,
    required this.strokes,
    required this.textLayers,
  });

  factory StoryCardScene.empty() {
    return const StoryCardScene(
      backgroundTransform: StoryCardBackgroundTransform.initial(),
      strokes: [],
      textLayers: [],
    );
  }

  factory StoryCardScene.fromJsonString(String source) {
    return StoryCardScene.fromJson(
      Map<String, dynamic>.from(jsonDecode(source) as Map),
    );
  }

  factory StoryCardScene.fromJson(Map<String, dynamic> json) {
    final strokes = json['strokes'] as List<dynamic>? ?? const [];
    final textLayers = json['text_layers'] as List<dynamic>? ?? const [];
    final background = json['background'] as Map<String, dynamic>?;

    return StoryCardScene(
      backgroundTransform: background == null
          ? const StoryCardBackgroundTransform.initial()
          : StoryCardBackgroundTransform.fromJson(background),
      strokes: strokes
          .map(
            (stroke) => StoryCardStroke.fromJson(
              Map<String, dynamic>.from(stroke as Map),
            ),
          )
          .toList(growable: false),
      textLayers: textLayers
          .map(
            (layer) => StoryCardTextLayer.fromJson(
              Map<String, dynamic>.from(layer as Map),
            ),
          )
          .toList(growable: false),
    );
  }

  final StoryCardBackgroundTransform backgroundTransform;
  final List<StoryCardStroke> strokes;
  final List<StoryCardTextLayer> textLayers;

  bool get hasDrawing => strokes.isNotEmpty;

  bool get hasText => textLayers.isNotEmpty;

  int get textCharacterCount => textLayers.fold(
    0,
    (total, layer) => total + layer.text.characters.length,
  );

  StoryCardScene copyWith({
    StoryCardBackgroundTransform? backgroundTransform,
    List<StoryCardStroke>? strokes,
    List<StoryCardTextLayer>? textLayers,
  }) {
    return StoryCardScene(
      backgroundTransform: backgroundTransform ?? this.backgroundTransform,
      strokes: strokes ?? this.strokes,
      textLayers: textLayers ?? this.textLayers,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': 1,
      'background': backgroundTransform.toJson(),
      'strokes': strokes.map((stroke) => stroke.toJson()).toList(),
      'text_layers': textLayers.map((layer) => layer.toJson()).toList(),
    };
  }

  String toJsonString() => jsonEncode(toJson());
}

class StoryCardBackgroundTransform {
  const StoryCardBackgroundTransform({
    required this.scale,
    required this.offsetX,
    required this.offsetY,
  });

  const StoryCardBackgroundTransform.initial()
    : scale = 1,
      offsetX = 0,
      offsetY = 0;

  factory StoryCardBackgroundTransform.fromJson(Map<String, dynamic> json) {
    return StoryCardBackgroundTransform(
      scale: (json['scale'] as num?)?.toDouble() ?? 1,
      offsetX: (json['offset_x'] as num?)?.toDouble() ?? 0,
      offsetY: (json['offset_y'] as num?)?.toDouble() ?? 0,
    );
  }

  final double scale;
  final double offsetX;
  final double offsetY;

  StoryCardBackgroundTransform copyWith({
    double? scale,
    double? offsetX,
    double? offsetY,
  }) {
    return StoryCardBackgroundTransform(
      scale: scale ?? this.scale,
      offsetX: offsetX ?? this.offsetX,
      offsetY: offsetY ?? this.offsetY,
    );
  }

  Map<String, dynamic> toJson() {
    return {'scale': scale, 'offset_x': offsetX, 'offset_y': offsetY};
  }
}

class StoryCardStroke {
  const StoryCardStroke({
    required this.color,
    required this.width,
    required this.points,
  });

  factory StoryCardStroke.fromJson(Map<String, dynamic> json) {
    final points = json['points'] as List<dynamic>? ?? const [];

    return StoryCardStroke(
      color: _colorFromJson(json['color'] as String),
      width: (json['width'] as num).toDouble(),
      points: points
          .map(
            (point) => StoryCardPoint.fromJson(
              Map<String, dynamic>.from(point as Map),
            ),
          )
          .toList(growable: false),
    );
  }

  final Color color;
  final double width;
  final List<StoryCardPoint> points;

  StoryCardStroke copyWith({List<StoryCardPoint>? points}) {
    return StoryCardStroke(
      color: color,
      width: width,
      points: points ?? this.points,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'color': _colorToJson(color),
      'width': width,
      'points': points.map((point) => point.toJson()).toList(),
    };
  }
}

class StoryCardPoint {
  const StoryCardPoint({required this.x, required this.y});

  factory StoryCardPoint.fromJson(Map<String, dynamic> json) {
    return StoryCardPoint(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
    );
  }

  final double x;
  final double y;

  Map<String, dynamic> toJson() => {'x': x, 'y': y};
}

class StoryCardTextLayer {
  const StoryCardTextLayer({
    required this.id,
    required this.text,
    required this.x,
    required this.y,
    required this.color,
  });

  factory StoryCardTextLayer.fromJson(Map<String, dynamic> json) {
    return StoryCardTextLayer(
      id: json['id'] as String,
      text: json['text'] as String,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      color: _colorFromJson(json['color'] as String),
    );
  }

  final String id;
  final String text;
  final double x;
  final double y;
  final Color color;

  StoryCardTextLayer copyWith({
    String? text,
    double? x,
    double? y,
    Color? color,
  }) {
    return StoryCardTextLayer(
      id: id,
      text: text ?? this.text,
      x: x ?? this.x,
      y: y ?? this.y,
      color: color ?? this.color,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'x': x,
      'y': y,
      'color': _colorToJson(color),
    };
  }
}

String _colorToJson(Color color) {
  return '#${color.toARGB32().toRadixString(16).padLeft(8, '0')}';
}

Color _colorFromJson(String value) {
  final hex = value.replaceFirst('#', '');
  final normalized = hex.length == 6 ? 'ff$hex' : hex;

  return Color(int.parse(normalized, radix: 16));
}
