import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/story_loops/application/story_card_editor_session.dart';
import 'package:vinscent/features/story_loops/data/story_card_type.dart';
import 'package:vinscent/features/story_loops/presentation/widgets/story_card_editor_action_bar.dart';
import 'package:vinscent/features/story_loops/presentation/widgets/story_card_type_icon.dart';

void main() {
  testWidgets('필름 아래에 현재 카드 유형 도구를 배치하고 짧은 글 도구는 제거한다', (tester) async {
    var typePresses = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: StoryCardEditorActionBar(
              interactionMode: StoryCardEditorTool.none,
              cardType: StoryCardType.fourCutStrip,
              onAddTextPressed: () {},
              onDrawingModePressed: () {},
              onFilmPressed: () {},
              onCardTypePressed: () => typePresses += 1,
            ),
          ),
        ),
      ),
    );

    final filmY = tester
        .getCenter(find.byKey(const ValueKey('story-card-film-tool')))
        .dy;
    final typeTool = find.byKey(const ValueKey('story-card-type-tool'));
    final typeY = tester.getCenter(typeTool).dy;
    final icon = tester.widget<StoryCardTypeIcon>(
      find.descendant(of: typeTool, matching: find.byType(StoryCardTypeIcon)),
    );

    expect(filmY, lessThan(typeY));
    expect(icon.type, StoryCardType.fourCutStrip);
    expect(find.byKey(const ValueKey('story-card-caption-tool')), findsNothing);

    await tester.tap(typeTool);
    expect(typePresses, 1);
  });

  testWidgets('사진이 있을 때만 필름 도구를 노출한다', (tester) async {
    var presses = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: StoryCardEditorActionBar(
              interactionMode: StoryCardEditorTool.none,
              cardType: StoryCardType.fullBleed,
              onAddTextPressed: () {},
              onDrawingModePressed: () {},
              onFilmPressed: () => presses += 1,
              onCardTypePressed: () {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('story-card-film-tool')));

    expect(presses, 1);
  });
}
