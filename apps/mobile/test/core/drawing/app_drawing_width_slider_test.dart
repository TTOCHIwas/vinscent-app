import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/core/drawing/app_drawing_style.dart';
import 'package:vinscent/core/drawing/widgets/app_drawing_width_slider.dart';
import 'package:vinscent/core/theme/app_colors.dart';

void main() {
  const preview = ValueKey('drawing-width-preview');

  for (final brightness in Brightness.values) {
    testWidgets('width track is visible on $brightness surface', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppDrawingWidthSlider(
              brightness: brightness,
              canvasExtent: 320,
              value: AppDrawingStyle.normalStrokeWidth,
              onChanged: (_) {},
            ),
          ),
        ),
      );
      final theme = SliderTheme.of(tester.element(find.byType(Slider)));
      expect(
        theme.activeTrackColor,
        brightness == Brightness.light ? AppColors.textMuted : Colors.white70,
      );
      expect(
        theme.inactiveTrackColor,
        brightness == Brightness.light
            ? AppColors.settingsDivider
            : Colors.white38,
      );
      expect(theme.thumbColor, Colors.white);
    });
  }

  for (final extent in [320.0, 600.0, 900.0]) {
    testWidgets('stable handle and transient actual-size preview at $extent', (
      tester,
    ) async {
      var width = AppDrawingStyle.minStrokeWidth;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: StatefulBuilder(
                builder: (context, setState) => SizedBox(
                  width: 320,
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
      );
      final control = find.byType(AppDrawingWidthSlider);
      final slider = find.byType(Slider);
      final initialBounds = tester.getRect(control);
      SliderThemeData theme() => SliderTheme.of(tester.element(slider));
      final thumbSize = theme().thumbShape!.getPreferredSize(true, false);
      expect(thumbSize.width, greaterThanOrEqualTo(20));
      expect(initialBounds.height, 48);
      expect(find.byKey(preview), findsNothing);

      final bounds = tester.getRect(slider);
      final gesture = await tester.startGesture(bounds.center);
      await tester.pump();
      expect(find.byKey(preview), findsOneWidget);
      expect(
        tester.getSize(find.byKey(preview)).width,
        closeTo(width * extent, .001),
      );
      expect(tester.getRect(find.byKey(preview)).bottom, lessThan(bounds.top));

      await gesture.moveTo(bounds.centerRight - const Offset(1, 0));
      await tester.pump();
      expect(width, AppDrawingStyle.maxStrokeWidth);
      expect(theme().thumbShape!.getPreferredSize(true, false), thumbSize);
      expect(tester.getRect(control), initialBounds);
      final previewBounds = tester.getRect(find.byKey(preview));
      expect(previewBounds.width, closeTo(width * extent, .001));
      expect(previewBounds.left, greaterThanOrEqualTo(initialBounds.left));
      expect(previewBounds.right, lessThanOrEqualTo(initialBounds.right));

      await gesture.moveTo(bounds.centerLeft + const Offset(1, 0));
      await tester.pump();
      expect(width, AppDrawingStyle.minStrokeWidth);
      expect(theme().thumbShape!.getPreferredSize(true, false), thumbSize);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.byKey(preview), findsNothing);
      expect(tester.getRect(control), initialBounds);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('cancelled drag removes preview', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: AppDrawingWidthSlider(
              canvasExtent: 360,
              value: AppDrawingStyle.normalStrokeWidth,
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(Slider)),
    );
    await tester.pump();
    expect(find.byKey(preview), findsOneWidget);
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(find.byKey(preview), findsNothing);
  });

  testWidgets('disabled control does not show preview', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppDrawingWidthSlider(
            canvasExtent: 360,
            value: AppDrawingStyle.normalStrokeWidth,
            onChanged: null,
          ),
        ),
      ),
    );
    await tester.tap(find.byType(Slider));
    await tester.pump();
    expect(find.byKey(preview), findsNothing);
  });
}
