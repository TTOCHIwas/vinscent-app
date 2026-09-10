import 'dart:math' as math;
import 'dart:ui' as ui;

import '../data/story_card_film_look.dart';
import '../data/story_card_scene.dart';

class StoryCardFilmImageMapping {
  const StoryCardFilmImageMapping({
    required this.uvScale,
    required this.uvOffset,
  });

  const StoryCardFilmImageMapping.identity()
    : uvScale = const ui.Offset(1, 1),
      uvOffset = ui.Offset.zero;

  factory StoryCardFilmImageMapping.cover({
    required ui.Size imageSize,
    required ui.Rect destination,
    required StoryCardBackgroundTransform transform,
  }) {
    if (imageSize.isEmpty || destination.isEmpty) {
      throw ArgumentError('Film image mapping requires non-empty sizes.');
    }

    final coverScale = math.max(
      destination.width / imageSize.width,
      destination.height / imageSize.height,
    );
    final drawWidth = imageSize.width * coverScale * transform.scale;
    final drawHeight = imageSize.height * coverScale * transform.scale;
    final uvScale = ui.Offset(
      destination.width / drawWidth,
      destination.height / drawHeight,
    );

    return StoryCardFilmImageMapping(
      uvScale: uvScale,
      uvOffset: ui.Offset(
        (1 - uvScale.dx) / 2 - transform.offsetX * uvScale.dx,
        (1 - uvScale.dy) / 2 - transform.offsetY * uvScale.dy,
      ),
    );
  }

  final ui.Offset uvScale;
  final ui.Offset uvOffset;
}

abstract final class StoryCardFilmShaderProgram {
  static const assetPath = 'shaders/story_card_film.frag';
  static final Future<ui.FragmentProgram> _program =
      ui.FragmentProgram.fromAsset(assetPath);

  static Future<ui.FragmentProgram> load() => _program;
}

abstract final class StoryCardFilmShader {
  static ui.FragmentShader create({
    required ui.FragmentProgram program,
    required ui.Size outputSize,
    required ui.Offset outputOrigin,
    required StoryCardFilmImageMapping mapping,
    required ui.Color backgroundColor,
    required StoryCardFilmState film,
    ui.Image? image,
  }) {
    final preset = film.look.preset;
    final seed = (film.seed % 100000) / 100000;
    final values = <double>[
      outputSize.width,
      outputSize.height,
      outputOrigin.dx,
      outputOrigin.dy,
      mapping.uvScale.dx,
      mapping.uvScale.dy,
      mapping.uvOffset.dx,
      mapping.uvOffset.dy,
      backgroundColor.r,
      backgroundColor.g,
      backgroundColor.b,
      preset.exposure,
      preset.contrast,
      preset.saturation,
      preset.temperature,
      preset.tint,
      preset.fade,
      preset.grain,
      preset.softness,
      preset.bloom,
      preset.vignette,
      preset.shadowTeal,
      preset.highlightWarmth,
      seed,
    ];
    final shader = program.fragmentShader();
    for (var index = 0; index < values.length; index++) {
      shader.setFloat(index, values[index]);
    }
    if (image != null) {
      shader.setImageSampler(0, image, filterQuality: ui.FilterQuality.high);
    }
    return shader;
  }

  static ui.FragmentShader createForImageFilter({
    required ui.FragmentProgram program,
    required StoryCardFilmState film,
  }) {
    return create(
      program: program,
      outputSize: const ui.Size(1, 1),
      outputOrigin: ui.Offset.zero,
      mapping: const StoryCardFilmImageMapping.identity(),
      backgroundColor: const ui.Color(0xFF000000),
      film: film,
    );
  }
}
