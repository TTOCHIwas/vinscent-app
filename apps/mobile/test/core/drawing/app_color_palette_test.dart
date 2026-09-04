import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/core/drawing/app_drawing_style.dart';
import 'package:vinscent/core/drawing/widgets/app_color_palette.dart';

void main() {
  testWidgets('keeps the eyedropper fixed while only colors scroll', (
    tester,
  ) async {
    Color selected = Colors.white;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: StatefulBuilder(
                builder: (context, setState) => AppColorPalette(
                  keyPrefix: 'test',
                  selectedColor: selected,
                  onPickColor: () async => const Color(0xFF526173),
                  onColorChanged: (color) => setState(() => selected = color),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final eyedropper = find.byKey(const ValueKey('test-eyedropper'));
    final original = tester.getRect(eyedropper);
    await tester.drag(
      find.byKey(const ValueKey('test-color-scroll')),
      const Offset(-400, 0),
    );
    await tester.pumpAndSettle();
    expect(tester.getRect(eyedropper), original);
    await tester.tap(find.byKey(const ValueKey('test-color-9')));
    await tester.pump();
    expect(selected, AppDrawingStyle.colorPalette[9]);
    expect(
      tester.widget<IconButton>(eyedropper).style!.backgroundColor!.resolve({}),
      selected,
    );
    expect(
      tester.widget<IconButton>(eyedropper).style!.shape!.resolve({}),
      isA<CircleBorder>(),
    );
    await tester.tap(eyedropper);
    await tester.pumpAndSettle();
    expect(selected, const Color(0xFF526173));
    expect(
      tester.widget<IconButton>(eyedropper).style!.backgroundColor!.resolve({}),
      selected,
    );
    expect(tester.getRect(eyedropper), original);
  });

  testWidgets('blocks repeat sampling and preserves color on cancel', (
    tester,
  ) async {
    final pending = Completer<Color?>();
    var calls = 0;
    Color? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppColorPalette(
            keyPrefix: 'test',
            selectedColor: Colors.black,
            onColorChanged: (color) => selected = color,
            onPickColor: () {
              calls++;
              return pending.future;
            },
          ),
        ),
      ),
    );
    final eyedropper = find.byKey(const ValueKey('test-eyedropper'));
    await tester.tap(eyedropper);
    await tester.pump();
    expect(tester.widget<IconButton>(eyedropper).onPressed, isNull);
    await tester.tap(eyedropper);
    expect(calls, 1);
    pending.complete(null);
    await tester.pumpAndSettle();
    expect(selected, isNull);
    expect(tester.widget<IconButton>(eyedropper).onPressed, isNotNull);
  });

  testWidgets('disables palette and sampler in read-only mode', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppColorPalette(
            keyPrefix: 'test',
            selectedColor: Colors.black,
            onColorChanged: null,
            onPickColor: () async {
              calls++;
              return Colors.red;
            },
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('test-eyedropper')));
    await tester.tap(find.byKey(const ValueKey('test-color-0')));
    expect(calls, 0);
  });
}
