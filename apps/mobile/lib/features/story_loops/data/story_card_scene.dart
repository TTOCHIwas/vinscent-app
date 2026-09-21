import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/drawing/app_drawing_style.dart';
import 'story_card_appearance.dart';
import 'story_card_film_look.dart';
import 'story_card_type.dart';

const storyCardColorPalette = AppDrawingStyle.colorPalette;
const storyCardThinStrokeWidth = AppDrawingStyle.thinStrokeWidth;
const storyCardNormalStrokeWidth = AppDrawingStyle.normalStrokeWidth;
const storyCardThickStrokeWidth = AppDrawingStyle.thickStrokeWidth;
const storyCardMinStrokeWidth = AppDrawingStyle.minStrokeWidth;
const storyCardMaxStrokeWidth = AppDrawingStyle.maxStrokeWidth;
const storyCardMaxTextLayers = 10;
const storyCardMaxTextCharactersPerLayer = 500;
const storyCardMaxTextCharacters = 5000;
const storyCardMaxCaptionCharacters = 50;
const storyCardMaxCaptionLines = 2;
const storyCardCaptionFontSizeRatio = 0.09;
const storyCardTextFontSizeRatio = 16 / 360;
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
    final layout = StoryCardLayout.fromSize(
      type: StoryCardType.polaroid,
      size: size,
    );

    return StoryCardPolaroidLayout(
      photoRect: layout.photoRects.single,
      captionRect: layout.captionRect!,
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
    this.cardType = StoryCardType.polaroid,
    this.layoutVersion = storyCardCurrentLayoutVersion,
    this.additionalPhotoTransforms = const [],
    this.film = const StoryCardFilmState.original(),
    this.additionalPhotoFilms = const [],
    this.canvasBackground = StoryCardCanvasBackground.white,
    StoryCardAppearance? appearance,
    this.caption,
  }) : assert(
         layoutVersion == storyCardLegacyLayoutVersion ||
             layoutVersion == storyCardCurrentLayoutVersion,
       ),
       appearance =
           appearance ??
           (canvasBackground == StoryCardCanvasBackground.black
               ? const StoryCardAppearance.dark()
               : const StoryCardAppearance());

  factory StoryCardScene.empty({
    StoryCardCanvasBackground canvasBackground =
        StoryCardCanvasBackground.white,
    StoryCardType cardType = StoryCardType.polaroid,
    int layoutVersion = storyCardCurrentLayoutVersion,
  }) {
    return StoryCardScene(
      backgroundTransform: const StoryCardBackgroundTransform.initial(),
      strokes: const [],
      textLayers: const [],
      cardType: cardType,
      layoutVersion: layoutVersion,
      film: const StoryCardFilmState.original(),
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
    final backgrounds = json['backgrounds'] as List<dynamic>?;
    final canvas = json['canvas'] as Map<String, dynamic>?;
    final canvasBackground = _canvasBackgroundFromJson(
      canvas?['background_color'] as String?,
    );
    final cardType = StoryCardType.fromStorageValue(
      json['card_type'] as String?,
    );
    final transforms = backgrounds
        ?.map(
          (value) => StoryCardBackgroundTransform.fromJson(
            Map<String, dynamic>.from(value as Map),
          ),
        )
        .toList(growable: false);
    final legacyFilm = StoryCardFilmState.fromJson(json['film']);
    final serializedFilms = json['films'] as List<dynamic>?;
    final films = serializedFilms
        ?.map(StoryCardFilmState.fromJson)
        .toList(growable: false);

    return StoryCardScene(
      backgroundTransform:
          transforms?.firstOrNull ??
          (background == null
              ? const StoryCardBackgroundTransform.initial()
              : StoryCardBackgroundTransform.fromJson(background)),
      additionalPhotoTransforms: transforms == null
          ? const []
          : transforms.skip(1).toList(growable: false),
      cardType: cardType,
      layoutVersion: storyCardLayoutVersionFromValue(json['layout_version']),
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
      film: films?.firstOrNull ?? legacyFilm,
      additionalPhotoFilms: films == null
          ? List<StoryCardFilmState>.filled(3, legacyFilm, growable: false)
          : films.skip(1).toList(growable: false),
      canvasBackground: canvasBackground,
      appearance: StoryCardAppearance.fromJson(
        json['appearance'],
        fallbackBackgroundColor: canvasBackground.color,
      ),
      caption: json['caption'] as String?,
    );
  }

  final StoryCardBackgroundTransform backgroundTransform;
  final List<StoryCardBackgroundTransform> additionalPhotoTransforms;
  final StoryCardType cardType;
  final int layoutVersion;
  final List<StoryCardStroke> strokes;
  final List<StoryCardTextLayer> textLayers;
  final StoryCardFilmState film;
  final List<StoryCardFilmState> additionalPhotoFilms;
  final StoryCardCanvasBackground canvasBackground;
  final StoryCardAppearance appearance;
  final String? caption;

  Size get previewSize => cardType.previewSizeFor(layoutVersion);

  double get canvasAspectRatio => cardType.canvasAspectRatioFor(layoutVersion);

  List<StoryCardBackgroundTransform> get photoTransforms {
    final transforms = storedPhotoTransforms;
    return List.generate(
      cardType.requiredPhotoCount,
      (index) => index < transforms.length
          ? transforms[index]
          : const StoryCardBackgroundTransform.initial(),
      growable: false,
    );
  }

  List<StoryCardBackgroundTransform> get storedPhotoTransforms => [
    backgroundTransform,
    ...additionalPhotoTransforms,
  ];

  List<StoryCardFilmState> get photoFilms {
    final films = storedPhotoFilms;
    return List.generate(
      cardType.requiredPhotoCount,
      (index) => index < films.length
          ? films[index]
          : const StoryCardFilmState.original(),
      growable: false,
    );
  }

  List<StoryCardFilmState> get storedPhotoFilms => [
    film,
    ...additionalPhotoFilms,
  ];

  bool get hasDrawing =>
      strokes.any((stroke) => stroke.tool == StoryCardDrawingTool.pen);

  bool get hasText => textLayers.isNotEmpty;

  bool get hasCaption =>
      cardType.supportsCaption && (caption?.isNotEmpty ?? false);

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
    List<StoryCardBackgroundTransform>? additionalPhotoTransforms,
    StoryCardType? cardType,
    int? layoutVersion,
    List<StoryCardStroke>? strokes,
    List<StoryCardTextLayer>? textLayers,
    StoryCardFilmState? film,
    List<StoryCardFilmState>? additionalPhotoFilms,
    StoryCardCanvasBackground? canvasBackground,
    StoryCardAppearance? appearance,
    Object? caption = _storyCardCaptionUnchanged,
  }) {
    return StoryCardScene(
      backgroundTransform: backgroundTransform ?? this.backgroundTransform,
      additionalPhotoTransforms:
          additionalPhotoTransforms ?? this.additionalPhotoTransforms,
      cardType: cardType ?? this.cardType,
      layoutVersion: layoutVersion ?? this.layoutVersion,
      strokes: strokes ?? this.strokes,
      textLayers: textLayers ?? this.textLayers,
      film: film ?? this.film,
      additionalPhotoFilms: additionalPhotoFilms ?? this.additionalPhotoFilms,
      canvasBackground: canvasBackground ?? this.canvasBackground,
      appearance:
          appearance ??
          (canvasBackground == null
              ? this.appearance
              : StoryCardAppearance(backgroundColor: canvasBackground.color)),
      caption: identical(caption, _storyCardCaptionUnchanged)
          ? this.caption
          : caption as String?,
    );
  }

  StoryCardScene withPhotoTransform(
    int index,
    StoryCardBackgroundTransform transform,
  ) {
    if (index < 0 || index >= cardType.requiredPhotoCount) {
      throw RangeError.index(index, photoTransforms, 'index');
    }
    final transforms = [backgroundTransform, ...additionalPhotoTransforms];
    while (transforms.length <= index) {
      transforms.add(const StoryCardBackgroundTransform.initial());
    }
    transforms[index] = transform;
    return copyWith(
      backgroundTransform: transforms.first,
      additionalPhotoTransforms: transforms.skip(1).toList(growable: false),
    );
  }

  StoryCardScene withPhotoFilm(int index, StoryCardFilmState photoFilm) {
    if (index < 0 || index >= cardType.requiredPhotoCount) {
      throw RangeError.index(index, photoFilms, 'index');
    }
    final films = [film, ...additionalPhotoFilms];
    while (films.length <= index) {
      films.add(const StoryCardFilmState.original());
    }
    films[index] = photoFilm;
    return copyWith(
      film: films.first,
      additionalPhotoFilms: films.skip(1).toList(growable: false),
    );
  }

  StoryCardScene reorderPhotoState(int fromIndex, int toIndex) {
    if (fromIndex < 0 ||
        fromIndex >= cardType.requiredPhotoCount ||
        toIndex < 0 ||
        toIndex >= cardType.requiredPhotoCount) {
      throw RangeError('Photo reorder index is outside the active card.');
    }
    final transforms = [backgroundTransform, ...additionalPhotoTransforms];
    final films = [film, ...additionalPhotoFilms];
    while (transforms.length < cardType.requiredPhotoCount) {
      transforms.add(const StoryCardBackgroundTransform.initial());
    }
    while (films.length < cardType.requiredPhotoCount) {
      films.add(const StoryCardFilmState.original());
    }
    final fromTransform = transforms[fromIndex];
    transforms[fromIndex] = transforms[toIndex];
    transforms[toIndex] = fromTransform;
    final fromFilm = films[fromIndex];
    films[fromIndex] = films[toIndex];
    films[toIndex] = fromFilm;
    return copyWith(
      backgroundTransform: transforms.first,
      additionalPhotoTransforms: transforms.skip(1).toList(growable: false),
      film: films.first,
      additionalPhotoFilms: films.skip(1).toList(growable: false),
    );
  }

  Map<String, dynamic> toJson({bool includeInactivePhotoState = false}) {
    final serializedTransforms = includeInactivePhotoState
        ? storedPhotoTransforms
        : photoTransforms;
    final serializedFilms = includeInactivePhotoState
        ? storedPhotoFilms
        : photoFilms;
    return {
      'version': 9,
      'card_type': cardType.storageValue,
      'layout_version': layoutVersion,
      'appearance': appearance.toJson(),
      'canvas': {
        'width_ratio': switch (cardType) {
          StoryCardType.fourCutGrid
              when layoutVersion == storyCardCurrentLayoutVersion =>
            20,
          StoryCardType.fourCutStrip
              when layoutVersion == storyCardCurrentLayoutVersion =>
            8,
          StoryCardType.fourCutStrip => 2,
          StoryCardType.fullBleed ||
          StoryCardType.polaroid ||
          StoryCardType.fourCutGrid => 4,
        },
        'height_ratio': switch (cardType) {
          StoryCardType.fourCutGrid
              when layoutVersion == storyCardCurrentLayoutVersion =>
            27,
          StoryCardType.fourCutStrip
              when layoutVersion == storyCardCurrentLayoutVersion =>
            21,
          StoryCardType.fullBleed ||
          StoryCardType.polaroid ||
          StoryCardType.fourCutGrid ||
          StoryCardType.fourCutStrip => 5,
        },
        'background_color': canvasBackground.name,
      },
      'background': backgroundTransform.toJson(),
      'backgrounds': serializedTransforms
          .map((transform) => transform.toJson())
          .toList(growable: false),
      'film': film.toJson(),
      'films': serializedFilms
          .map((value) => value.toJson())
          .toList(growable: false),
      'strokes': strokes.map((stroke) => stroke.toJson()).toList(),
      'text_layers': textLayers.map((layer) => layer.toJson()).toList(),
      'caption': cardType.supportsCaption || includeInactivePhotoState
          ? caption
          : null,
    };
  }

  String toJsonString({bool includeInactivePhotoState = false}) =>
      jsonEncode(toJson(includeInactivePhotoState: includeInactivePhotoState));
}

class StoryCardBackgroundTransform {
  const StoryCardBackgroundTransform({
    required this.scale,
    required this.offsetX,
    required this.offsetY,
    this.rotation = 0,
  });

  const StoryCardBackgroundTransform.initial()
    : scale = 1,
      offsetX = 0,
      offsetY = 0,
      rotation = 0;

  factory StoryCardBackgroundTransform.fromJson(Map<String, dynamic> json) {
    return StoryCardBackgroundTransform(
      scale: ((json['scale'] as num?)?.toDouble() ?? 1)
          .clamp(storyCardMinBackgroundScale, storyCardMaxBackgroundScale)
          .toDouble(),
      offsetX: (json['offset_x'] as num?)?.toDouble() ?? 0,
      offsetY: (json['offset_y'] as num?)?.toDouble() ?? 0,
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0,
    );
  }

  final double scale;
  final double offsetX;
  final double offsetY;
  final double rotation;

  StoryCardBackgroundTransform copyWith({
    double? scale,
    double? offsetX,
    double? offsetY,
    double? rotation,
  }) {
    return StoryCardBackgroundTransform(
      scale: scale ?? this.scale,
      offsetX: offsetX ?? this.offsetX,
      offsetY: offsetY ?? this.offsetY,
      rotation: rotation ?? this.rotation,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'scale': scale,
      'offset_x': offsetX,
      'offset_y': offsetY,
      'rotation': rotation,
    };
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
