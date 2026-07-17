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
const storyCardThickStrokeWidth = 0.08;
const storyCardMinStrokeWidth = storyCardThinStrokeWidth;
const storyCardMaxStrokeWidth = storyCardThickStrokeWidth;
const storyCardMaxTextLayers = 10;
const storyCardMaxTextCharactersPerLayer = 500;
const storyCardMaxTextCharacters = 5000;
const storyCardMaxCaptionCharacters = 50;
const storyCardMaxCaptionLines = 2;
const storyCardCaptionFontSizeRatio = 0.09;
const storyCardCanvasAspectRatio = 4 / 5;
const storyCardPhotoAspectRatio = 1.0;
const storyCardPreviewWidth = 800;
const storyCardPreviewHeight = 1000;
const storyCardMinBackgroundScale = 0.25;
const storyCardMaxBackgroundScale = 8.0;
const storyCardMinTextScale = 0.5;
const storyCardMaxTextScale = 8.0;

const _storyCardCaptionUnchanged = Object();

class StoryCardPolaroidLayout {
  const StoryCardPolaroidLayout({
    required this.photoRect,
    required this.captionRect,
  });

  factory StoryCardPolaroidLayout.fromSize(Size size) {
    final horizontalInset = size.width * 0.06;
    final topInset = horizontalInset;
    final photoSide = size.width - horizontalInset * 2;
    final photoRect = Rect.fromLTWH(
      horizontalInset,
      topInset,
      photoSide,
      photoSide / storyCardPhotoAspectRatio,
    );
    final captionTop = photoRect.bottom + size.width * 0.03;

    return StoryCardPolaroidLayout(
      photoRect: photoRect,
      captionRect: Rect.fromLTRB(
        horizontalInset,
        captionTop,
        size.width - horizontalInset,
        size.height - topInset,
      ),
    );
  }

  final Rect photoRect;
  final Rect captionRect;
}

enum StoryCardCanvasBackground {
  white,
  black;

  Color get color => switch (this) {
    StoryCardCanvasBackground.white => Colors.white,
    StoryCardCanvasBackground.black => Colors.black,
  };
}

enum StoryCardDrawingTool {
  pen,
  eraser;

  factory StoryCardDrawingTool.fromJson(String? value) {
    return switch (value) {
      null || 'pen' => StoryCardDrawingTool.pen,
      'eraser' => StoryCardDrawingTool.eraser,
      _ => throw FormatException('Unknown story card drawing tool: $value'),
    };
  }
}

class StoryCardScene {
  const StoryCardScene({
    required this.backgroundTransform,
    required this.strokes,
    required this.textLayers,
    this.canvasBackground = StoryCardCanvasBackground.white,
    this.caption,
  });

  factory StoryCardScene.empty({
    StoryCardCanvasBackground canvasBackground =
        StoryCardCanvasBackground.white,
  }) {
    return StoryCardScene(
      backgroundTransform: const StoryCardBackgroundTransform.initial(),
      strokes: const [],
      textLayers: const [],
      canvasBackground: canvasBackground,
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
    final canvas = json['canvas'] as Map<String, dynamic>?;

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
      canvasBackground: _canvasBackgroundFromJson(
        canvas?['background_color'] as String?,
      ),
      caption: json['caption'] as String?,
    );
  }

  final StoryCardBackgroundTransform backgroundTransform;
  final List<StoryCardStroke> strokes;
  final List<StoryCardTextLayer> textLayers;
  final StoryCardCanvasBackground canvasBackground;
  final String? caption;

  bool get hasDrawing =>
      strokes.any((stroke) => stroke.tool == StoryCardDrawingTool.pen);

  bool get hasText => textLayers.isNotEmpty;

  bool get hasCaption => caption?.isNotEmpty ?? false;

  int get textCharacterCount => textLayers.fold(
    0,
    (total, layer) => total + layer.text.characters.length,
  );

  int get captionCharacterCount => caption?.characters.length ?? 0;

  int get captionLineCount {
    final value = caption;
    return value == null || value.isEmpty
        ? 0
        : value.split(RegExp(r'\r\n?|\n')).length;
  }

  StoryCardScene copyWith({
    StoryCardBackgroundTransform? backgroundTransform,
    List<StoryCardStroke>? strokes,
    List<StoryCardTextLayer>? textLayers,
    StoryCardCanvasBackground? canvasBackground,
    Object? caption = _storyCardCaptionUnchanged,
  }) {
    return StoryCardScene(
      backgroundTransform: backgroundTransform ?? this.backgroundTransform,
      strokes: strokes ?? this.strokes,
      textLayers: textLayers ?? this.textLayers,
      canvasBackground: canvasBackground ?? this.canvasBackground,
      caption: identical(caption, _storyCardCaptionUnchanged)
          ? this.caption
          : caption as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': 4,
      'canvas': {
        'width_ratio': 4,
        'height_ratio': 5,
        'background_color': canvasBackground.name,
      },
      'background': backgroundTransform.toJson(),
      'strokes': strokes.map((stroke) => stroke.toJson()).toList(),
      'text_layers': textLayers.map((layer) => layer.toJson()).toList(),
      'caption': caption,
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
      scale: ((json['scale'] as num?)?.toDouble() ?? 1)
          .clamp(storyCardMinBackgroundScale, storyCardMaxBackgroundScale)
          .toDouble(),
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
    this.tool = StoryCardDrawingTool.pen,
  });

  factory StoryCardStroke.fromJson(Map<String, dynamic> json) {
    final points = json['points'] as List<dynamic>? ?? const [];

    return StoryCardStroke(
      tool: StoryCardDrawingTool.fromJson(json['tool'] as String?),
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

  final StoryCardDrawingTool tool;
  final Color color;
  final double width;
  final List<StoryCardPoint> points;

  StoryCardStroke copyWith({List<StoryCardPoint>? points}) {
    return StoryCardStroke(
      tool: tool,
      color: color,
      width: width,
      points: points ?? this.points,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tool': tool.name,
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
    this.scale = 1,
    this.rotation = 0,
  });

  factory StoryCardTextLayer.fromJson(Map<String, dynamic> json) {
    return StoryCardTextLayer(
      id: json['id'] as String,
      text: json['text'] as String,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      color: _colorFromJson(json['color'] as String),
      scale: ((json['scale'] as num?)?.toDouble() ?? 1)
          .clamp(storyCardMinTextScale, storyCardMaxTextScale)
          .toDouble(),
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0,
    );
  }

  final String id;
  final String text;
  final double x;
  final double y;
  final Color color;
  final double scale;
  final double rotation;

  StoryCardTextLayer copyWith({
    String? text,
    double? x,
    double? y,
    Color? color,
    double? scale,
    double? rotation,
  }) {
    return StoryCardTextLayer(
      id: id,
      text: text ?? this.text,
      x: x ?? this.x,
      y: y ?? this.y,
      color: color ?? this.color,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'x': x,
      'y': y,
      'color': _colorToJson(color),
      'scale': scale,
      'rotation': rotation,
    };
  }
}

StoryCardCanvasBackground _canvasBackgroundFromJson(String? value) {
  return StoryCardCanvasBackground.values.firstWhere(
    (background) => background.name == value,
    orElse: () => StoryCardCanvasBackground.white,
  );
}

String _colorToJson(Color color) {
  return '#${color.toARGB32().toRadixString(16).padLeft(8, '0')}';
}

Color _colorFromJson(String value) {
  final hex = value.replaceFirst('#', '');
  final normalized = hex.length == 6 ? 'ff$hex' : hex;

  return Color(int.parse(normalized, radix: 16));
}
