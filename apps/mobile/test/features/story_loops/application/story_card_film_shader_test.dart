import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/story_loops/application/story_card_film_shader.dart';
import 'package:vinscent/features/story_loops/data/story_card_scene.dart';

void main() {
  test('cover mapping matches the existing centered photo geometry', () {
    final mapping = StoryCardFilmImageMapping.cover(
      imageSize: const Size(400, 200),
      destination: const Rect.fromLTWH(20, 30, 200, 200),
      transform: const StoryCardBackgroundTransform.initial(),
    );

    expect(mapping.uvScale.dx, closeTo(0.5, 0.0001));
    expect(mapping.uvScale.dy, closeTo(1, 0.0001));
    expect(mapping.uvOffset.dx, closeTo(0.25, 0.0001));
    expect(mapping.uvOffset.dy, closeTo(0, 0.0001));
  });

  test('cover mapping applies normalized pan and user scale', () {
    final mapping = StoryCardFilmImageMapping.cover(
      imageSize: const Size(200, 200),
      destination: const Rect.fromLTWH(0, 0, 200, 200),
      transform: const StoryCardBackgroundTransform(
        scale: 2,
        offsetX: 0.25,
        offsetY: -0.1,
      ),
    );

    expect(mapping.uvScale, const Offset(0.5, 0.5));
    expect(mapping.uvOffset.dx, closeTo(0.125, 0.0001));
    expect(mapping.uvOffset.dy, closeTo(0.3, 0.0001));
  });

  testWidgets('film shader asset compiles', (tester) async {
    final program = await StoryCardFilmShaderProgram.load();

    expect(program, isA<FragmentProgram>());
  });
}
