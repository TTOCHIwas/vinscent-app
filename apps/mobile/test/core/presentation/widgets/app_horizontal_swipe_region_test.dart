import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/core/presentation/widgets/app_horizontal_swipe_region.dart';

void main() {
  testWidgets('ignores a short fast horizontal flick', (tester) async {
    var rightSwipeCount = 0;

    await _pump(tester, onSwipeRight: () => rightSwipeCount++);

    await tester.fling(
      find.byType(AppHorizontalSwipeRegion),
      const Offset(64, 0),
      2000,
    );

    expect(rightSwipeCount, 0);
  });

  testWidgets('accepts a deliberate horizontal drag in either direction', (
    tester,
  ) async {
    var rightSwipeCount = 0;
    var leftSwipeCount = 0;

    await _pump(
      tester,
      onSwipeRight: () => rightSwipeCount++,
      onSwipeLeft: () => leftSwipeCount++,
    );

    await tester.drag(
      find.byType(AppHorizontalSwipeRegion),
      const Offset(120, 0),
    );
    await tester.drag(
      find.byType(AppHorizontalSwipeRegion),
      const Offset(-120, 0),
    );

    expect(rightSwipeCount, 1);
    expect(leftSwipeCount, 1);
  });
}

Future<void> _pump(
  WidgetTester tester, {
  VoidCallback? onSwipeRight,
  VoidCallback? onSwipeLeft,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: AppHorizontalSwipeRegion(
          onSwipeRight: onSwipeRight,
          onSwipeLeft: onSwipeLeft,
          child: const SizedBox.expand(),
        ),
      ),
    ),
  );
}
