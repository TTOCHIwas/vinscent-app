import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/shell/presentation/widgets/app_bottom_bar.dart';

void main() {
  testWidgets('keeps the Android bottom gap when an iOS safe inset exists', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(padding: EdgeInsets.only(bottom: 34)),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: AppBottomBar(
              height: 90,
              currentLocation: '/home',
              onHomePressed: () {},
              onCalendarPressed: () {},
              onAiPressed: () {},
            ),
          ),
        ),
      ),
    );

    final bottomBar = find.byType(AppBottomBar);
    final surface = find.descendant(
      of: bottomBar,
      matching: find.byType(ClipRRect),
    );
    final bottomBarRect = tester.getRect(bottomBar);
    final surfaceRect = tester.getRect(surface);

    expect(bottomBarRect.height, 90);
    expect(surfaceRect.height, 64);
    expect(bottomBarRect.bottom - surfaceRect.bottom, 18);
  });
}
