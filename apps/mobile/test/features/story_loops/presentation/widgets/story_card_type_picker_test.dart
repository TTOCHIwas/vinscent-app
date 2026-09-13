import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/story_loops/data/story_card_type.dart';
import 'package:vinscent/features/story_loops/presentation/widgets/story_card_type_icon.dart';
import 'package:vinscent/features/story_loops/presentation/widgets/story_card_type_picker.dart';

void main() {
  testWidgets('카드 유형 아이콘은 실제 카드 외곽 비율을 유지한다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Row(
          children: [
            StoryCardTypeIcon(
              key: ValueKey('full-bleed-icon'),
              type: StoryCardType.fullBleed,
              size: 50,
            ),
            StoryCardTypeIcon(
              key: ValueKey('strip-icon'),
              type: StoryCardType.fourCutStrip,
              size: 50,
            ),
          ],
        ),
      ),
    );

    expect(
      tester.getSize(find.byKey(const ValueKey('full-bleed-icon'))).aspectRatio,
      closeTo(4 / 5, 0.001),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('strip-icon'))).aspectRatio,
      closeTo(2 / 5, 0.001),
    );
  });

  testWidgets('카드 유형을 아이콘과 이름으로 표시하고 선택을 반환한다', (tester) async {
    StoryCardType? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: StoryCardTypePicker(
            selectedType: StoryCardType.fullBleed,
            keyPrefix: 'test-card-type',
            onSelected: (value) => selected = value,
          ),
        ),
      ),
    );

    expect(find.byType(StoryCardTypeIcon), findsNWidgets(4));
    for (final type in StoryCardType.editorOrder) {
      expect(find.text(type.displayName), findsOneWidget);
    }

    await tester.tap(
      find.byKey(const ValueKey('test-card-type-four-cut-strip')),
    );
    expect(selected, StoryCardType.fourCutStrip);
  });
}
