import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/core/drawing/app_drawing_style.dart';
import 'package:vinscent/core/drawing/widgets/app_drawing_width_slider.dart';

void main() {
  for (final extent in [320.0, 600.0]) {
    testWidgets('thumb matches actual stroke at canvas width $extent', (
      tester,
    ) async {
      var width = AppDrawingStyle.minStrokeWidth;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: StatefulBuilder(
                builder: (context, setState) => SizedBox(
                  key: const ValueKey('control'),
                  height: 220,
                  child: RotatedBox(
                    quarterTurns: 3,
                    child: AppDrawingWidthSlider(
                      canvasExtent: extent,
                      value: width,
                      onChanged: (value) => setState(() => width = value),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final slider = find.byType(Slider);
      final control = find.byKey(const ValueKey('control'));
      final initialBounds = tester.getRect(control);
      SliderThemeData theme() => SliderTheme.of(tester.element(slider));
      final overlay = theme().overlayShape!.getPreferredSize(true, false);
      final smallThumb = theme().thumbShape! as RoundSliderThumbShape;
      expect(
        smallThumb.enabledThumbRadius * 2,
        closeTo(width * extent, 0.0001),
      );
      expect(initialBounds.width, greaterThanOrEqualTo(48));
      await tester.dragFrom(initialBounds.center, const Offset(0, -110));
      await tester.pumpAndSettle();
      expect(width, AppDrawingStyle.maxStrokeWidth);
      expect(tester.getRect(control), initialBounds);
      expect(theme().overlayShape!.getPreferredSize(true, false), overlay);
      final largeThumb = theme().thumbShape! as RoundSliderThumbShape;
      expect(
        largeThumb.enabledThumbRadius * 2,
        closeTo(width * extent, 0.0001),
      );
      await tester.dragFrom(initialBounds.center, const Offset(0, 110));
      await tester.pumpAndSettle();
      expect(width, AppDrawingStyle.minStrokeWidth);
      expect(tester.takeException(), isNull);
    });
  }

  for (final background in [Colors.black, Colors.white]) {
    testWidgets('track remains tapered and visible on $background', (
      tester,
    ) async {
      const extent = 360.0;
      const width =
          (AppDrawingStyle.minStrokeWidth + AppDrawingStyle.maxStrokeWidth) / 2;
      final captureKey = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: RepaintBoundary(
                key: captureKey,
                child: ColoredBox(
                  color: background,
                  child: SizedBox(
                    height: 220,
                    child: RotatedBox(
                      quarterTurns: 3,
                      child: AppDrawingWidthSlider(
                        canvasExtent: extent,
                        value: width,
                        onChanged: (_) {},
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final boundary =
          captureKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      ui.Image? snapshot;
      ByteData? rgba;
      await tester.runAsync(() async {
        snapshot = await boundary.toImage(pixelRatio: 1);
        rgba = await snapshot!.toByteData(format: ui.ImageByteFormat.rawRgba);
      });
      addTearDown(snapshot!.dispose);
      int litPixels(int row, int threshold) {
        var count = 0;
        for (var x = 0; x < snapshot!.width; x++) {
          if (rgba!.getUint8((row * snapshot!.width + x) * 4) > threshold) {
            count++;
          }
        }
        return count;
      }

      if (background == Colors.black) {
        expect(litPixels(48, 40), greaterThan(litPixels(172, 40)));
        expect(litPixels(110, 240), closeTo(width * extent, 2));
      } else {
        int outlineWidth(int row) {
          final pixels = <int>[];
          for (var x = 0; x < snapshot!.width; x++) {
            if (rgba!.getUint8((row * snapshot!.width + x) * 4) < 240) {
              pixels.add(x);
            }
          }
          expect(pixels, isNotEmpty);
          return pixels.last - pixels.first;
        }

        expect(outlineWidth(48), greaterThan(outlineWidth(172)));
      }
    });
  }
}
