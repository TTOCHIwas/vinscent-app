import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/story_loops/data/story_card_type.dart';

void main() {
  test('defines the four supported story card formats in editor order', () {
    expect(StoryCardType.editorOrder, [
      StoryCardType.fullBleed,
      StoryCardType.polaroid,
      StoryCardType.fourCutGrid,
      StoryCardType.fourCutStrip,
    ]);
    expect(StoryCardType.fullBleed.storageValue, 'full_bleed');
    expect(StoryCardType.polaroid.storageValue, 'polaroid');
    expect(StoryCardType.fourCutGrid.storageValue, 'four_cut_grid');
    expect(StoryCardType.fourCutStrip.storageValue, 'four_cut_strip');

    expect(StoryCardType.fullBleed.canvasAspectRatio, 4 / 5);
    expect(StoryCardType.polaroid.canvasAspectRatio, 4 / 5);
    expect(StoryCardType.fourCutGrid.canvasAspectRatio, 20 / 27);
    expect(StoryCardType.fourCutStrip.canvasAspectRatio, 8 / 21);
    expect(StoryCardType.fullBleed.requiredPhotoCount, 1);
    expect(StoryCardType.polaroid.requiredPhotoCount, 1);
    expect(StoryCardType.fourCutGrid.requiredPhotoCount, 4);
    expect(StoryCardType.fourCutStrip.requiredPhotoCount, 4);
    expect(StoryCardType.fullBleed.supportsCaption, isFalse);
    expect(StoryCardType.polaroid.supportsCaption, isTrue);
    expect(StoryCardType.fourCutGrid.supportsCaption, isFalse);
    expect(StoryCardType.fourCutStrip.supportsCaption, isFalse);
  });

  test('full-bleed layout uses the entire card as its photo frame', () {
    final layout = StoryCardLayout.fromSize(
      type: StoryCardType.fullBleed,
      size: const Size(400, 500),
    );

    expect(layout.photoRects, [const Rect.fromLTWH(0, 0, 400, 500)]);
    expect(layout.captionRect, isNull);
    expect(layout.photoAspectRatio(0), 4 / 5);
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

  test('spacious grid frame adds vertical room without resizing photos', () {
    final legacySize = StoryCardType.fourCutGrid.previewSizeFor(
      storyCardLegacyLayoutVersion,
    );
    final currentSize = StoryCardType.fourCutGrid.previewSizeFor(
      storyCardCurrentLayoutVersion,
    );
    final legacy = StoryCardLayout.fromSize(
      type: StoryCardType.fourCutGrid,
      size: legacySize,
      layoutVersion: storyCardLegacyLayoutVersion,
    );
    final current = StoryCardLayout.fromSize(
      type: StoryCardType.fourCutGrid,
      size: currentSize,
      layoutVersion: storyCardCurrentLayoutVersion,
    );

    expect(legacySize, const Size(800, 1000));
    expect(currentSize, const Size(800, 1080));
    expect(
      current.photoRects.first.top,
      greaterThan(legacy.photoRects.first.top),
    );
    expect(
      currentSize.height - current.photoRects.last.bottom,
      greaterThan(legacySize.height - legacy.photoRects.last.bottom),
    );
    expect(current.photoRects.first.size, legacy.photoRects.first.size);
  });

  test('strip layout resolves four vertically ordered cells', () {
    final layout = StoryCardLayout.fromSize(
      type: StoryCardType.fourCutStrip,
      size: const Size(240, 600),
    );

    expect(layout.photoRects, hasLength(4));
    expect(layout.captionRect, isNull);
    expect(layout.photoRects.first.top, closeTo(24, 0.001));
    expect(600 - layout.photoRects.last.bottom, closeTo(24, 0.001));
    expect(layout.photoAspectRatio(0), greaterThan(1.5));
    for (var index = 1; index < layout.photoRects.length; index++) {
      expect(
        layout.photoRects[index].top,
        greaterThan(layout.photoRects[index - 1].bottom),
      );
    }
  });

  test('spacious strip frame adds balanced top and bottom room', () {
    final legacySize = StoryCardType.fourCutStrip.previewSizeFor(
      storyCardLegacyLayoutVersion,
    );
    final currentSize = StoryCardType.fourCutStrip.previewSizeFor(
      storyCardCurrentLayoutVersion,
    );
    final legacy = StoryCardLayout.fromSize(
      type: StoryCardType.fourCutStrip,
      size: legacySize,
      layoutVersion: storyCardLegacyLayoutVersion,
    );
    final current = StoryCardLayout.fromSize(
      type: StoryCardType.fourCutStrip,
      size: currentSize,
      layoutVersion: storyCardCurrentLayoutVersion,
    );

    expect(legacySize, const Size(640, 1600));
    expect(currentSize, const Size(640, 1680));
    expect(
      current.photoRects.first.top,
      greaterThan(legacy.photoRects.first.top),
    );
    expect(
      currentSize.height - current.photoRects.last.bottom,
      closeTo(current.photoRects.first.top, 0.001),
    );
    expect(
      current.photoRects.first.width,
      closeTo(legacy.photoRects.first.width, 0.001),
    );
    expect(
      current.photoRects.first.height,
      closeTo(legacy.photoRects.first.height, 1),
    );
  });
}
