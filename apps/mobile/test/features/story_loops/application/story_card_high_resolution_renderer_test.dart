import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/story_loops/application/story_card_high_resolution_renderer.dart';
import 'package:vinscent/features/story_loops/data/story_card_download_source.dart';
import 'package:vinscent/features/story_loops/data/story_card_scene.dart';

void main() {
  testWidgets('renders a card as a 1440 by 1800 PNG', (tester) async {
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

    final bytes = await renderer.render(source);
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    addTearDown(() {
      frame.image.dispose();
      codec.dispose();
    });

    expect(frame.image.width, 1440);
    expect(frame.image.height, 1800);
  });
}
