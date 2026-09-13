import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/core/theme/app_colors.dart';
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
    expect(find.text('저장하지 않은 변경 내용이 사라져요.'), findsOneWidget);
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
    expect(_labelColor(tester, save), AppColors.brandAction);
    expect(
      _labelColor(tester, discard),
      Theme.of(tester.element(discard)).colorScheme.error,
    );
    expect(_labelColor(tester, continueEditing), AppColors.textPrimary);

    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(result, StoryCardDraftExitAction.saveDraft);
  });

  testWidgets('바깥 영역을 누르면 선택 없이 임시저장 확인창을 닫는다', (tester) async {
    StoryCardDraftExitAction? result = StoryCardDraftExitAction.discard;
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
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(result, isNull);
  });
}

Color? _labelColor(WidgetTester tester, Finder button) {
  return tester
      .widget<Text>(find.descendant(of: button, matching: find.byType(Text)))
      .style
      ?.color;
}
