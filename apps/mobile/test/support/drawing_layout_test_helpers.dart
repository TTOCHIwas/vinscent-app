import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/core/drawing/widgets/app_drawing_width_slider.dart';

void expectSharedDrawingLayout(
  WidgetTester tester, {
  required String keyPrefix,
  required Finder canvas,
}) {
  final top = tester.getRect(find.byKey(ValueKey('$keyPrefix-top-controls')));
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
  expect(top.bottom, lessThanOrEqualTo(canvasRect.top));
  expect(canvasRect.bottom, lessThanOrEqualTo(width.top));
  expect(width.bottom, palette.top);
  expect(palette.width, top.width);
  expect(width.height, 48);
  expect(canvasRect.width, closeTo(canvasRect.height, .001));
  expect(slider.canvasExtent, closeTo(canvasRect.width, .001));
  expect(find.text('굵기'), findsNothing);
  expect(tester.takeException(), isNull);
}
