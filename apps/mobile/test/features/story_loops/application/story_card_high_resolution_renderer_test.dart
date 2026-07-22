import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/story_loops/application/story_card_high_resolution_renderer.dart';
import 'package:vinscent/features/story_loops/data/story_card_download_source.dart';
import 'package:vinscent/features/story_loops/data/story_card_scene.dart';

void main() {
  testWidgets('defaults to 1440 by 1800 and renders a PNG', (tester) async {
    const renderer = StoryCardHighResolutionRenderer();
    final source = StoryCardDownloadSource(
      scene: StoryCardScene.empty().copyWith(
        caption: 'our day',
        textLayers: const [
          StoryCardTextLayer(
            id: 'text-1',
            text: 'hello',
            x: 0.5,
            y: 0.4,
            color: ui.Color(0xFF111111),
          ),
        ],
      ),
      backgroundImageBytes: null,
    );

    expect(renderer.outputWidth, 1440);
    expect(renderer.outputHeight, 1800);

    final dimensions = await tester.runAsync<(int, int)>(() async {
      final bytes = await renderer.render(source);
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final result = (frame.image.width, frame.image.height);
      frame.image.dispose();
      codec.dispose();
      return result;
    });

    expect(dimensions, (1440, 1800));
  });
}
