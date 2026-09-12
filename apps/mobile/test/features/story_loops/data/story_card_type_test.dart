import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/story_loops/data/story_card_type.dart';

void main() {
  test('defines the three supported story card formats', () {
    expect(StoryCardType.polaroid.storageValue, 'polaroid');
    expect(StoryCardType.fourCutGrid.storageValue, 'four_cut_grid');
    expect(StoryCardType.fourCutStrip.storageValue, 'four_cut_strip');

    expect(StoryCardType.polaroid.canvasAspectRatio, 4 / 5);
    expect(StoryCardType.fourCutGrid.canvasAspectRatio, 4 / 5);
    expect(StoryCardType.fourCutStrip.canvasAspectRatio, 2 / 5);
    expect(StoryCardType.polaroid.requiredPhotoCount, 1);
    expect(StoryCardType.fourCutGrid.requiredPhotoCount, 4);
    expect(StoryCardType.fourCutStrip.requiredPhotoCount, 4);
    expect(StoryCardType.polaroid.supportsCaption, isTrue);
    expect(StoryCardType.fourCutGrid.supportsCaption, isFalse);
    expect(StoryCardType.fourCutStrip.supportsCaption, isFalse);
  });

  test('unknown persisted formats remain backward compatible', () {
    expect(StoryCardType.fromStorageValue(null), StoryCardType.polaroid);
    expect(
      StoryCardType.fromStorageValue('future_format'),
      StoryCardType.polaroid,
    );
  });

  test('grid layout resolves four cells in two rows and columns', () {
    final layout = StoryCardLayout.fromSize(
      type: StoryCardType.fourCutGrid,
      size: const Size(400, 500),
    );

    expect(layout.photoRects, hasLength(4));
    expect(layout.captionRect, isNull);
    expect(layout.photoRects[0].left, layout.photoRects[2].left);
    expect(layout.photoRects[1].left, greaterThan(layout.photoRects[0].left));
    expect(layout.photoRects[2].top, greaterThan(layout.photoRects[0].top));
    expect(layout.photoRects[3].top, layout.photoRects[2].top);
  });

  test('strip layout resolves four vertically ordered cells', () {
    final layout = StoryCardLayout.fromSize(
      type: StoryCardType.fourCutStrip,
      size: const Size(240, 600),
    );

    expect(layout.photoRects, hasLength(4));
    expect(layout.captionRect, isNull);
    for (var index = 1; index < layout.photoRects.length; index++) {
      expect(
        layout.photoRects[index].top,
        greaterThan(layout.photoRects[index - 1].bottom),
      );
    }
  });
}
