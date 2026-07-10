import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/story_loops/data/story_card_scene.dart';

void main() {
  test('scene JSON preserves visual layers and text count', () {
    const scene = StoryCardScene(
      backgroundTransform: StoryCardBackgroundTransform(
        scale: 1.5,
        offsetX: 0.1,
        offsetY: -0.2,
      ),
      strokes: [
        StoryCardStroke(
          color: Color(0xFFE94B5F),
          width: storyCardNormalStrokeWidth,
          points: [StoryCardPoint(x: 0.1, y: 0.2)],
        ),
      ],
      textLayers: [
        StoryCardTextLayer(
          id: 'text-1',
          text: '오늘도 좋아해',
          x: 0.5,
          y: 0.6,
          color: Color(0xFFFFFFFF),
        ),
      ],
    );

    final restored = StoryCardScene.fromJsonString(scene.toJsonString());

    expect(restored.backgroundTransform.scale, 1.5);
    expect(restored.backgroundTransform.offsetX, 0.1);
    expect(restored.backgroundTransform.offsetY, -0.2);
    expect(restored.hasDrawing, isTrue);
    expect(restored.hasText, isTrue);
    expect(restored.textLayers.single.text, '오늘도 좋아해');
    expect(restored.textCharacterCount, 7);
  });
}
