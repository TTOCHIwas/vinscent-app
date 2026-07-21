import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/core/drawing/app_drawing.dart';
import 'package:vinscent/core/drawing/app_drawing_controller.dart';
import 'package:vinscent/core/drawing/app_drawing_style.dart';

void main() {
  group('AppDrawingController', () {
    test(
      'builds an active stroke and completes it with the selected style',
      () {
        final controller = AppDrawingController();
        const start = AppDrawingPoint(x: 0.1, y: 0.2);
        const end = AppDrawingPoint(x: 0.3, y: 0.4);

        controller
          ..selectStrokeWidth(AppDrawingStyle.thickStrokeWidth)
          ..startStroke(start)
          ..updateStroke(end);

        expect(controller.strokes, isEmpty);
        expect(controller.visibleStrokes, hasLength(1));
        expect(controller.canUndo, isFalse);
        expect(controller.visibleStrokes.single.points, [start, end]);
        expect(
          controller.visibleStrokes.single.width,
          AppDrawingStyle.thickStrokeWidth,
        );

        controller.endStroke();

        expect(controller.strokes, hasLength(1));
        expect(controller.visibleStrokes, controller.strokes);
        expect(controller.canUndo, isTrue);
      },
    );

    test('selecting a color switches from eraser to pen', () {
      final controller = AppDrawingController();
      const color = Color(0xFFE94B5F);

      controller
        ..selectTool(AppDrawingTool.eraser)
        ..selectColor(color);

      expect(controller.selectedTool, AppDrawingTool.pen);
      expect(controller.selectedColor, color);
    });

    test(
      'undo is blocked while drawing and removes the latest stroke after',
      () {
        final controller = AppDrawingController();
        const point = AppDrawingPoint(x: 0.5, y: 0.5);

        controller
          ..startStroke(point)
          ..endStroke()
          ..startStroke(point);

        controller.undo();
        expect(controller.strokes, hasLength(1));

        controller
          ..endStroke()
          ..undo();

        expect(controller.strokes, hasLength(1));
      },
    );

    test('replace and clear reset active drawing state', () {
      final controller = AppDrawingController();
      const point = AppDrawingPoint(x: 0.25, y: 0.75);
      const stroke = AppDrawingStroke(
        tool: AppDrawingTool.pen,
        color: Color(0xFF111111),
        width: AppDrawingStyle.normalStrokeWidth,
        points: [point],
      );

      controller
        ..startStroke(point)
        ..replaceStrokes(const [stroke]);

      expect(controller.visibleStrokes, const [stroke]);
      expect(controller.hasVisibleContent, isTrue);

      controller.clear();

      expect(controller.strokes, isEmpty);
      expect(controller.visibleStrokes, isEmpty);
      expect(controller.hasVisibleContent, isFalse);
      expect(controller.canClear, isFalse);
    });
  });
}
