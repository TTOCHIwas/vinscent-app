import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/core/drawing/app_drawing.dart';

void main() {
  test('serializes drawing strokes as editable JSON', () {
    const drawingData = AppDrawingData(
      strokes: [
        AppDrawingStroke(
          tool: AppDrawingTool.pen,
          color: Color(0xFF111111),
          width: 0.022,
          points: [
            AppDrawingPoint(x: 0.1, y: 0.2),
            AppDrawingPoint(x: 0.7, y: 0.8),
          ],
        ),
      ],
    );

    final restored = AppDrawingData.fromJsonString(drawingData.toJsonString());

    expect(restored.hasVisibleContent, isTrue);
    expect(restored.strokes, hasLength(1));
    expect(restored.strokes.first.tool, AppDrawingTool.pen);
    expect(restored.strokes.first.color, const Color(0xFF111111));
    expect(restored.strokes.first.width, 0.022);
    expect(restored.strokes.first.points.first.x, 0.1);
    expect(restored.strokes.first.points.last.y, 0.8);
  });

  test('does not treat eraser-only drawing as visible content', () {
    const drawingData = AppDrawingData(
      strokes: [
        AppDrawingStroke(
          tool: AppDrawingTool.eraser,
          color: Color(0xFF111111),
          width: 0.038,
          points: [AppDrawingPoint(x: 0.5, y: 0.5)],
        ),
      ],
    );

    expect(drawingData.hasVisibleContent, isFalse);
  });
}
