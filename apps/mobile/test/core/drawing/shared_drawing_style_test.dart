import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/characters/presentation/widgets/character_toolbar.dart';
import 'package:vinscent/features/story_loops/data/story_card_scene.dart';

void main() {
  test('drawing editors share the same color palette', () {
    expect(characterColorPalette, storyCardColorPalette);
  });

  test('drawing editors share the same stroke width range', () {
    expect(characterThinStrokeWidth, storyCardThinStrokeWidth);
    expect(characterNormalStrokeWidth, storyCardNormalStrokeWidth);
    expect(characterThickStrokeWidth, storyCardThickStrokeWidth);
    expect(characterMinStrokeWidth, storyCardMinStrokeWidth);
    expect(characterMaxStrokeWidth, storyCardMaxStrokeWidth);
  });
}
