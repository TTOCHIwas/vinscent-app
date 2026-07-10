import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/story_loops/data/story_card_scene.dart';

void main() {
  test('scene JSON preserves visual layers and text count', () {
    const scene = StoryCardScene(
      canvasBackground: StoryCardCanvasBackground.black,
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
          scale: 1.8,
        ),
      ],
    );

    final restored = StoryCardScene.fromJsonString(scene.toJsonString());

    expect(restored.backgroundTransform.scale, 1.5);
    expect(restored.backgroundTransform.offsetX, 0.1);
    expect(restored.backgroundTransform.offsetY, -0.2);
    expect(restored.canvasBackground, StoryCardCanvasBackground.black);
    expect(restored.hasDrawing, isTrue);
    expect(restored.hasText, isTrue);
    expect(restored.textLayers.single.text, '오늘도 좋아해');
    expect(restored.textLayers.single.scale, 1.8);
    expect(restored.textCharacterCount, 7);
  });

  test('version 1 scene defaults to white canvas and unit text scale', () {
    final restored = StoryCardScene.fromJson({
      'version': 1,
      'background': {'scale': 1, 'offset_x': 0, 'offset_y': 0},
      'strokes': <Object>[],
      'text_layers': [
        {
          'id': 'legacy-text',
          'text': '기존 글',
          'x': 0.5,
          'y': 0.5,
          'color': '#ff111111',
        },
      ],
    });

    expect(restored.canvasBackground, StoryCardCanvasBackground.white);
    expect(restored.textLayers.single.scale, 1);
  });
}
