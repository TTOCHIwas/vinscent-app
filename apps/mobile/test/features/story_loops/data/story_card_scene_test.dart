import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/story_loops/data/story_card_scene.dart';

void main() {
  test('canvas and preview keep the portrait 9:16 contract', () {
    expect(storyCardCanvasAspectRatio, 9 / 16);
    expect(storyCardPreviewWidth, 540);
    expect(storyCardPreviewHeight, 960);
    expect(storyCardMinBackgroundScale, lessThan(1));
    expect(storyCardMaxStrokeWidth, 0.08);
    expect(storyCardMaxTextScale, 8);
  });

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
          tool: StoryCardDrawingTool.pen,
          color: Color(0xFFE94B5F),
          width: storyCardNormalStrokeWidth,
          points: [StoryCardPoint(x: 0.1, y: 0.2)],
        ),
        StoryCardStroke(
          tool: StoryCardDrawingTool.eraser,
          color: Color(0xFF111111),
          width: storyCardMaxStrokeWidth,
          points: [StoryCardPoint(x: 0.2, y: 0.3)],
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
          rotation: 0.75,
        ),
      ],
    );

    final restored = StoryCardScene.fromJsonString(scene.toJsonString());

    expect(restored.backgroundTransform.scale, 1.5);
    expect(restored.backgroundTransform.offsetX, 0.1);
    expect(restored.backgroundTransform.offsetY, -0.2);
    expect(restored.canvasBackground, StoryCardCanvasBackground.black);
    expect(restored.hasDrawing, isTrue);
    expect(restored.strokes.first.tool, StoryCardDrawingTool.pen);
    expect(restored.strokes.last.tool, StoryCardDrawingTool.eraser);
    expect(restored.hasText, isTrue);
    expect(restored.textLayers.single.text, '오늘도 좋아해');
    expect(restored.textLayers.single.scale, 1.8);
    expect(restored.textLayers.single.rotation, 0.75);
    expect(restored.textCharacterCount, 7);
    expect(restored.toJson()['version'], 3);
  });

  test('legacy scene defaults to pen strokes and unrotated text', () {
    final restored = StoryCardScene.fromJson({
      'version': 1,
      'background': {'scale': 1, 'offset_x': 0, 'offset_y': 0},
      'strokes': <Object>[
        {
          'color': '#ff111111',
          'width': 0.022,
          'points': [
            {'x': 0.2, 'y': 0.3},
          ],
        },
      ],
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
    expect(restored.strokes.single.tool, StoryCardDrawingTool.pen);
    expect(restored.textLayers.single.scale, 1);
    expect(restored.textLayers.single.rotation, 0);
  });

  test('eraser-only scene is not valid drawing content', () {
    const scene = StoryCardScene(
      backgroundTransform: StoryCardBackgroundTransform.initial(),
      strokes: [
        StoryCardStroke(
          tool: StoryCardDrawingTool.eraser,
          color: Color(0xFF111111),
          width: storyCardNormalStrokeWidth,
          points: [StoryCardPoint(x: 0.5, y: 0.5)],
        ),
      ],
      textLayers: [],
    );

    expect(scene.hasDrawing, isFalse);
  });
}
