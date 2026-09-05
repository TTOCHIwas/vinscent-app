import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/shell/presentation/widgets/app_bottom_bar.dart';

void main() {
  testWidgets('preserves the Android dock gap above the system inset', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
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

  testWidgets('uses the iOS system inset as the dock bottom gap', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        home: MediaQuery(
          data: const MediaQueryData(
            padding: EdgeInsets.only(bottom: 34),
            viewPadding: EdgeInsets.only(bottom: 34),
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

    expect(bottomBarRect.height, 106);
    expect(surfaceRect.height, 64);
    expect(bottomBarRect.bottom - surfaceRect.bottom, 34);
  });

  testWidgets('maintains the iOS system inset while the keyboard is visible', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
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

    expect(bottomBarRect.height, 106);
    expect(surfaceRect.height, 64);
    expect(bottomBarRect.bottom - surfaceRect.bottom, 34);
  });

  testWidgets('updates parent attention indicators without replacing them', (
    tester,
  ) async {
    var showHomeAttention = false;
    var showCalendarAttention = false;
    var showAiAttention = false;
    late StateSetter updateBottomBar;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            updateBottomBar = setState;
            return AppBottomBar(
              height: 90,
              currentLocation: '/home',
              showHomeAttention: showHomeAttention,
              showCalendarAttention: showCalendarAttention,
              showAiAttention: showAiAttention,
              onHomePressed: () {},
              onCalendarPressed: () {},
              onAiPressed: () {},
            );
          },
        ),
      ),
    );

    final homeIndicator = find.byKey(const Key('shell-tab-home-attention'));
    final calendarIndicator = find.byKey(
      const Key('shell-tab-calendar-attention'),
    );
    final aiIndicator = find.byKey(const Key('shell-tab-ai-attention'));
    final initialHomeElement = homeIndicator.evaluate().single;
    final initialCalendarElement = calendarIndicator.evaluate().single;
    final initialAiElement = aiIndicator.evaluate().single;

    expect(
      tester
          .widget<Badge>(
            find.descendant(of: homeIndicator, matching: find.byType(Badge)),
          )
          .isLabelVisible,
      isFalse,
    );

    updateBottomBar(() {
      showHomeAttention = true;
      showAiAttention = true;
    });
    await tester.pump();

    expect(homeIndicator.evaluate().single, same(initialHomeElement));
    expect(calendarIndicator.evaluate().single, same(initialCalendarElement));
    expect(aiIndicator.evaluate().single, same(initialAiElement));
    expect(
      tester
          .widget<Badge>(
            find.descendant(of: homeIndicator, matching: find.byType(Badge)),
          )
          .isLabelVisible,
      isTrue,
    );
    expect(
      tester
          .widget<Badge>(
            find.descendant(of: aiIndicator, matching: find.byType(Badge)),
          )
          .isLabelVisible,
      isTrue,
    );

    updateBottomBar(() {
      showHomeAttention = false;
      showAiAttention = false;
    });
    await tester.pump();

    expect(homeIndicator.evaluate().single, same(initialHomeElement));
    expect(aiIndicator.evaluate().single, same(initialAiElement));
    expect(tester.takeException(), isNull);
  });
}
