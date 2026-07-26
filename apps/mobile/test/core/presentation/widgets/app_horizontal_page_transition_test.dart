import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/core/presentation/widgets/app_horizontal_page_transition.dart';

void main() {
  testWidgets('slides the current page left when the next page enters', (
    tester,
  ) async {
    await _pumpTransition(
      tester,
      transitionKey: 1,
      direction: AppHorizontalPageDirection.next,
      childKey: const Key('first-page'),
    );
    final initialLeft = tester
        .getTopLeft(find.byKey(const Key('first-page')))
        .dx;

    await _pumpTransition(
      tester,
      transitionKey: 2,
      direction: AppHorizontalPageDirection.next,
      childKey: const Key('second-page'),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      tester.getTopLeft(find.byKey(const Key('first-page'))).dx,
      lessThan(initialLeft),
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('second-page'))).dx,
      greaterThan(initialLeft),
    );

    await tester.pumpAndSettle();

    expect(find.byKey(const Key('first-page')), findsNothing);
    expect(find.byKey(const Key('second-page')), findsOneWidget);
  });

  testWidgets('slides the current page right when the previous page enters', (
    tester,
  ) async {
    await _pumpTransition(
      tester,
      transitionKey: 2,
      direction: AppHorizontalPageDirection.previous,
      childKey: const Key('second-page'),
    );
    final initialLeft = tester
        .getTopLeft(find.byKey(const Key('second-page')))
        .dx;

    await _pumpTransition(
      tester,
      transitionKey: 1,
      direction: AppHorizontalPageDirection.previous,
      childKey: const Key('first-page'),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      tester.getTopLeft(find.byKey(const Key('second-page'))).dx,
      greaterThan(initialLeft),
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('first-page'))).dx,
      lessThan(initialLeft),
    );
  });

  testWidgets('updates the current page without animating the same key', (
    tester,
  ) async {
    await _pumpTransition(
      tester,
      transitionKey: 1,
      direction: AppHorizontalPageDirection.next,
      childKey: const Key('first-version'),
    );

    await _pumpTransition(
      tester,
      transitionKey: 1,
      direction: AppHorizontalPageDirection.next,
      childKey: const Key('updated-version'),
    );

    expect(find.byKey(const Key('first-version')), findsNothing);
    expect(find.byKey(const Key('updated-version')), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('replaces the page immediately when animations are disabled', (
    tester,
  ) async {
    await _pumpTransition(
      tester,
      transitionKey: 1,
      direction: AppHorizontalPageDirection.next,
      childKey: const Key('first-page'),
      disableAnimations: true,
    );

    await _pumpTransition(
      tester,
      transitionKey: 2,
      direction: AppHorizontalPageDirection.next,
      childKey: const Key('second-page'),
      disableAnimations: true,
    );

    expect(find.byKey(const Key('first-page')), findsNothing);
    expect(find.byKey(const Key('second-page')), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}

Future<void> _pumpTransition(
  WidgetTester tester, {
  required Object transitionKey,
  required AppHorizontalPageDirection direction,
  required Key childKey,
  bool disableAnimations = false,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: Center(
          child: SizedBox(
            width: 320,
            height: 120,
            child: AppHorizontalPageTransition(
              transitionKey: transitionKey,
              direction: direction,
              duration: const Duration(milliseconds: 200),
              curve: Curves.linear,
              child: ColoredBox(key: childKey, color: Colors.white),
            ),
          ),
        ),
      ),
    ),
  );
}
