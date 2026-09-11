import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vinscent/features/story_loops/presentation/story_card_editor_route.dart';

void main() {
  testWidgets('홈 오른쪽 스와이프 진입은 화면을 왼쪽에서 시작한다', (tester) async {
    const contextKey = ValueKey('route-test-context');
    await tester.pumpWidget(const MaterialApp(home: SizedBox(key: contextKey)));
    final controller = AnimationController(
      vsync: tester,
      duration: const Duration(milliseconds: 280),
    );
    addTearDown(controller.dispose);

    final page = buildStoryCardEditorPage(
      key: const ValueKey('story-editor'),
      uri: Uri.parse(storyCardEditorSwipeRightLocation),
      child: const SizedBox(),
    );

    expect(page, isA<CustomTransitionPage<void>>());
    final transitionPage = page as CustomTransitionPage<void>;
    final transition = transitionPage.transitionsBuilder(
      tester.element(find.byKey(contextKey)),
      controller,
      kAlwaysDismissedAnimation,
      const SizedBox(),
    );
    await tester.pumpWidget(MaterialApp(home: transition));

    expect(
      tester
          .widget<SlideTransition>(
            find.byKey(const Key('story-card-editor-slide-transition')),
          )
          .position
          .value,
      const Offset(-1, 0),
    );

    controller.value = 1;
    await tester.pump();

    expect(
      tester
          .widget<SlideTransition>(
            find.byKey(const Key('story-card-editor-slide-transition')),
          )
          .position
          .value,
      Offset.zero,
    );
  });

  test('버튼 진입은 기존 Material 전환을 유지한다', () {
    final page = buildStoryCardEditorPage(
      key: const ValueKey('story-editor'),
      uri: Uri.parse(storyCardEditorLocation),
      child: const SizedBox(),
    );

    expect(page, isA<MaterialPage<void>>());
  });
}
