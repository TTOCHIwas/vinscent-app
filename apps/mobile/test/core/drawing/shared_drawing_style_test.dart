import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/core/drawing/app_drawing_style.dart';
import 'package:vinscent/features/story_loops/data/story_card_scene.dart';

void main() {
  test('drawing editors share the same color palette', () {
    expect(AppDrawingStyle.colorPalette, storyCardColorPalette);
  });

  test('drawing editors share the same stroke width range', () {
    expect(AppDrawingStyle.thinStrokeWidth, storyCardThinStrokeWidth);
    expect(AppDrawingStyle.normalStrokeWidth, storyCardNormalStrokeWidth);
    expect(AppDrawingStyle.thickStrokeWidth, storyCardThickStrokeWidth);
    expect(AppDrawingStyle.minStrokeWidth, storyCardMinStrokeWidth);
    expect(AppDrawingStyle.maxStrokeWidth, storyCardMaxStrokeWidth);
  });
}
