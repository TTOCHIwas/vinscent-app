import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/core/drawing/widgets/app_drawing_width_slider.dart';
import 'package:vinscent/core/drawing/widgets/app_drawing_style_controls.dart';
import 'package:vinscent/core/presentation/widgets/app_page_header.dart';
import 'package:vinscent/core/theme/app_colors.dart';

void expectSharedDrawingLayout(
  WidgetTester tester, {
  required String keyPrefix,
  required Finder canvas,
}) {
  final header = tester.getRect(find.byType(AppPageHeader));
  final tools = tester.getRect(find.byKey(ValueKey('$keyPrefix-toolbar')));
  final palette = tester.getRect(
    find.byKey(ValueKey('$keyPrefix-color-palette')),
  );
  final width = tester.getRect(
    find.byKey(ValueKey('$keyPrefix-width-control')),
  );
  final canvasRect = tester.getRect(canvas);
  final slider = tester.widget<AppDrawingWidthSlider>(
    find.byType(AppDrawingWidthSlider),
  );
  expect(header.bottom, lessThanOrEqualTo(canvasRect.top));
  expect(canvasRect.bottom, lessThanOrEqualTo(tools.top));
  expect(tools.bottom, width.top);
  expect(width.bottom, palette.top);
  expect(palette.width, tools.width);
  final pen = tester.getRect(find.byKey(ValueKey('$keyPrefix-pen')));
  final eraser = tester.getRect(find.byKey(ValueKey('$keyPrefix-eraser')));
  final undo = tester.getRect(find.byKey(ValueKey('$keyPrefix-undo')));
  final clear = tester.getRect(find.byKey(ValueKey('$keyPrefix-clear')));
  expect(pen.left - tools.left, closeTo(tools.right - clear.right, .001));
  expect(eraser.left, greaterThanOrEqualTo(pen.right));
  expect(undo.left, greaterThanOrEqualTo(eraser.right));
  expect(clear.left - undo.right, greaterThanOrEqualTo(24));
  expect(clear.center.dy, pen.center.dy);
  final surface = tester.widget<ColoredBox>(
    find
        .descendant(
          of: find.byType(AppDrawingStyleControls),
          matching: find.byType(ColoredBox),
        )
        .first,
  );
  expect(surface.color, AppColors.background);
  expect(width.height, 48);
  expect(canvasRect.width, closeTo(canvasRect.height, .001));
  expect(slider.canvasExtent, closeTo(canvasRect.width, .001));
  expect(find.text('굵기'), findsNothing);
  expect(tester.takeException(), isNull);
}
