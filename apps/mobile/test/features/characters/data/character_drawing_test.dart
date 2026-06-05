import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/characters/data/character_drawing.dart';

void main() {
  test('serializes drawing strokes as editable JSON', () {
    const drawingData = CharacterDrawingData(
      strokes: [
        CharacterDrawingStroke(
          tool: CharacterDrawingTool.pen,
          color: Color(0xFF111111),
          width: 0.022,
          points: [
            CharacterDrawingPoint(x: 0.1, y: 0.2),
            CharacterDrawingPoint(x: 0.7, y: 0.8),
          ],
        ),
      ],
    );

    final restored = CharacterDrawingData.fromJsonString(
      drawingData.toJsonString(),
    );

    expect(restored.hasVisibleContent, isTrue);
    expect(restored.strokes, hasLength(1));
    expect(restored.strokes.first.tool, CharacterDrawingTool.pen);
    expect(restored.strokes.first.color, const Color(0xFF111111));
    expect(restored.strokes.first.width, 0.022);
    expect(restored.strokes.first.points.first.x, 0.1);
    expect(restored.strokes.first.points.last.y, 0.8);
  });

  test('does not treat eraser-only drawing as visible content', () {
    const drawingData = CharacterDrawingData(
      strokes: [
        CharacterDrawingStroke(
          tool: CharacterDrawingTool.eraser,
          color: Color(0xFF111111),
          width: 0.038,
          points: [CharacterDrawingPoint(x: 0.5, y: 0.5)],
        ),
      ],
    );

    expect(drawingData.hasVisibleContent, isFalse);
  });
}
