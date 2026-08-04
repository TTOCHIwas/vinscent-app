import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/shell/presentation/widgets/app_bottom_bar.dart';

void main() {
  testWidgets('keeps the dock above the system bottom inset', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            padding: EdgeInsets.only(bottom: 48),
            viewPadding: EdgeInsets.only(bottom: 48),
          ),
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

    expect(bottomBarRect.height, 138);
    expect(surfaceRect.height, 64);
    expect(bottomBarRect.bottom - surfaceRect.bottom, 66);
  });

  testWidgets('maintains the system inset while the keyboard is visible', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            viewPadding: EdgeInsets.only(bottom: 34),
            viewInsets: EdgeInsets.only(bottom: 300),
          ),
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

    expect(bottomBarRect.height, 124);
    expect(surfaceRect.height, 64);
    expect(bottomBarRect.bottom - surfaceRect.bottom, 52);
  });
}
