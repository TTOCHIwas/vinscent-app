import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/story_loops/data/story_card_type.dart';
import 'package:vinscent/features/story_loops/presentation/widgets/story_card_type_selector.dart';

void main() {
  testWidgets('shows all card types and returns the selected format', (
    tester,
  ) async {
    StoryCardType? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: StoryCardTypeSelector(
          onBack: () {},
          onSelected: (value) => selected = value,
        ),
      ),
    );

    expect(find.text('폴라로이드'), findsOneWidget);
    expect(find.text('네컷'), findsOneWidget);
    expect(find.text('세로 네컷'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('story-card-type-four-cut-strip')),
    );

    expect(selected, StoryCardType.fourCutStrip);
  });
}
