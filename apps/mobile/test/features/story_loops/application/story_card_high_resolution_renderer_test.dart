import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:vinscent/features/story_loops/application/story_card_high_resolution_renderer.dart';
import 'package:vinscent/features/story_loops/data/story_card_appearance.dart';
import 'package:vinscent/features/story_loops/data/story_card_download_source.dart';
import 'package:vinscent/features/story_loops/data/story_card_film_look.dart';
import 'package:vinscent/features/story_loops/data/story_card_scene.dart';
import 'package:vinscent/features/story_loops/data/story_card_type.dart';

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
      compositeImageBytes: null,
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

  testWidgets('renders a non-destructive film look from the original photo', (
    tester,
  ) async {
    final photo = image.Image(width: 8, height: 8);
    image.fill(photo, color: image.ColorRgb8(128, 128, 128));
    final originalBytes = image.encodePng(photo);
    final source = StoryCardDownloadSource(
      scene: StoryCardScene.empty().copyWith(
        film: const StoryCardFilmState(
          look: StoryCardFilmLook.moment,
          seed: 42,
        ),
      ),
      backgroundImageBytes: originalBytes,
      compositeImageBytes: null,
    );
    const renderer = StoryCardHighResolutionRenderer(
      outputWidth: 80,
      outputHeight: 100,
    );

    final rendered = await tester.runAsync(() => renderer.render(source));

    expect(rendered, isNotEmpty);
    expect(source.backgroundImageBytes, same(originalBytes));
    final output = image.decodePng(rendered!);
    expect(output, isNotNull);
    final photoPixel = output!.getPixel(40, 40);
    expect((
      photoPixel.r.toInt(),
      photoPixel.g.toInt(),
      photoPixel.b.toInt(),
    ), isNot((128, 128, 128)));
    final captionPixel = output.getPixel(40, 90);
    expect(
      (captionPixel.r.toInt(), captionPixel.g.toInt(), captionPixel.b.toInt()),
      (255, 255, 255),
    );
  });

  testWidgets('renders the selected card color around a polaroid photo', (
    tester,
  ) async {
    final photo = image.Image(width: 8, height: 8);
    image.fill(photo, color: image.ColorRgb8(255, 0, 0));
    const backgroundColor = ui.Color(0xFFB7D5C4);
    final source = StoryCardDownloadSource(
      scene: StoryCardScene.empty().copyWith(
        appearance: const StoryCardAppearance(backgroundColor: backgroundColor),
      ),
      backgroundImageBytes: image.encodePng(photo),
      compositeImageBytes: null,
    );
    const renderer = StoryCardHighResolutionRenderer(
      outputWidth: 80,
      outputHeight: 100,
    );

    final rendered = await tester.runAsync(() => renderer.render(source));
    final output = image.decodePng(rendered!);

    expect(output, isNotNull);
    final framePixel = output!.getPixel(2, 2);
    expect(
      (framePixel.r.toInt(), framePixel.g.toInt(), framePixel.b.toInt()),
      (183, 213, 196),
    );
    final photoPixel = output.getPixel(40, 40);
    expect(
      (photoPixel.r.toInt(), photoPixel.g.toInt(), photoPixel.b.toInt()),
      (255, 0, 0),
    );
  });

  test('returns the single saved composite for four-cut cards', () async {
    final composite = Uint8List.fromList([1, 2, 3, 4]);
    final source = StoryCardDownloadSource(
      scene: StoryCardScene.empty(cardType: StoryCardType.fourCutStrip),
      backgroundImageBytes: null,
      compositeImageBytes: composite,
    );

    final rendered = await const StoryCardHighResolutionRenderer().render(
      source,
    );

    expect(rendered, same(composite));
  });
}
