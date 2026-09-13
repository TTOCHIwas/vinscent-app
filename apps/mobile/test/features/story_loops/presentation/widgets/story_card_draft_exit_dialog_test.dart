import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/story_loops/presentation/widgets/story_card_draft_exit_dialog.dart';

void main() {
  testWidgets('임시저장 확인창은 세 동작을 요구된 세로 순서로 표시한다', (tester) async {
    StoryCardDraftExitAction? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showStoryCardDraftExitDialog(context: context);
            },
            child: const Text('열기'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    expect(find.text('임시 저장할까요?'), findsOneWidget);
    final save = find.byKey(const ValueKey('story-card-draft-exit-save'));
    final discard = find.byKey(const ValueKey('story-card-draft-exit-discard'));
    final continueEditing = find.byKey(
      const ValueKey('story-card-draft-exit-continue'),
    );
    expect(tester.getCenter(save).dy, lessThan(tester.getCenter(discard).dy));
    expect(
      tester.getCenter(discard).dy,
      lessThan(tester.getCenter(continueEditing).dy),
    );

    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(result, StoryCardDraftExitAction.saveDraft);
  });
}
