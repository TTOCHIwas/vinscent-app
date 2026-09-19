import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/story_loops/presentation/widgets/story_card_interactive_viewport.dart';

void main() {
  test('확대 후 최소 배율로 돌아오면 위치도 중앙으로 복원한다', () {
    final controller = StoryCardViewportController();
    addTearDown(controller.dispose);
    controller.configure(
      viewportSize: const Size(300, 500),
      contentSize: const Size(240, 300),
    );

    controller.beginGesture(const Offset(150, 250));
    controller.updateGesture(focalPoint: const Offset(180, 280), scale: 2);
    controller.endGesture();

    expect(controller.scale, 2);
    expect(controller.translation, const Offset(30, 30));
    expect(controller.isZoomed, isTrue);

    controller.beginGesture(const Offset(180, 280));
    controller.updateGesture(focalPoint: const Offset(150, 250), scale: 0.1);
    controller.endGesture();

    expect(controller.scale, 1);
    expect(controller.translation, Offset.zero);
    expect(controller.isZoomed, isFalse);
  });

  test('최소 배율을 지나친 핀치는 기본 상태를 다시 확대하지 않는다', () {
    final controller = StoryCardViewportController();
    addTearDown(controller.dispose);
    controller.configure(
      viewportSize: const Size(300, 500),
      contentSize: const Size(240, 300),
    );

    controller.beginGesture(const Offset(150, 250));
    controller.updateGesture(focalPoint: const Offset(150, 250), scale: 4);
    controller.endGesture();
    expect(controller.scale, 4);

    controller.beginGesture(const Offset(150, 250));
    controller.updateGesture(focalPoint: const Offset(150, 250), scale: 0.25);
    expect(controller.scale, 1);

    controller.updateGesture(focalPoint: const Offset(150, 250), scale: 0.5);
    controller.endGesture();
    expect(controller.scale, 1);
    expect(controller.translation, Offset.zero);

    controller.beginGesture(const Offset(150, 250));
    controller.updateGesture(focalPoint: const Offset(150, 250), scale: 1.5);
    controller.endGesture();
    expect(controller.scale, 1.5);
  });

  testWidgets('두 손가락으로 카드를 확대하고 한 손가락으로 이동한다', (tester) async {
    final controller = StoryCardViewportController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            height: 500,
            child: StoryCardInteractiveViewport(
              controller: controller,
              aspectRatio: 4 / 5,
              builder: (context, size, gestures) =>
                  StoryCardViewportGestureRegion(
                    gestures: gestures,
                    child: const ColoredBox(
                      key: ValueKey('viewport-card'),
                      color: Colors.red,
                    ),
                  ),
            ),
          ),
        ),
      ),
    );

    final card = find.byKey(const ValueKey('viewport-card'));
    final center = tester.getCenter(card);
    final first = await tester.startGesture(center - const Offset(30, 0));
    final second = await tester.startGesture(center + const Offset(30, 0));
    await first.moveTo(center - const Offset(70, 0));
    await second.moveTo(center + const Offset(70, 0));
    await tester.pump();
    await first.up();
    await second.up();
    await tester.pump();

    expect(controller.scale, greaterThan(1.5));

    final beforePan = controller.translation;
    await tester.drag(card, const Offset(0, 60));
    await tester.pump();
    expect(controller.translation.dy, greaterThan(beforePan.dy));
  });

  testWidgets('확대된 카드는 안전 여백을 넘어 투명 크롬 뒤까지 그려진다', (tester) async {
    final controller = StoryCardViewportController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 300,
            height: 500,
            child: ColoredBox(
              color: Colors.black,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 100),
                child: StoryCardInteractiveViewport(
                  controller: controller,
                  aspectRatio: 4 / 5,
                  clipContent: false,
                  builder: (context, size, gestures) => const ColoredBox(
                    key: ValueKey('overflow-card'),
                    color: Colors.red,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    controller.beginGesture(const Offset(150, 150));
    controller.updateGesture(focalPoint: const Offset(150, 150), scale: 2);
    await tester.pump();

    final viewport = find.byType(StoryCardInteractiveViewport);
    expect(
      find.descendant(of: viewport, matching: find.byType(ClipRect)),
      findsNothing,
    );
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('overflow-card'))).dy,
      lessThan(100),
    );
  });
}
