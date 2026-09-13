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
    expect(
      tester
          .widgetList<StoryCardTypeIcon>(find.byType(StoryCardTypeIcon))
          .map((icon) => icon.color)
          .toSet(),
      {Colors.white},
    );
    for (final type in StoryCardType.editorOrder) {
      expect(find.text(type.displayName), findsOneWidget);
    }

    await tester.tap(
      find.byKey(const ValueKey('test-card-type-four-cut-strip')),
    );
    expect(selected, StoryCardType.fourCutStrip);
  });

  testWidgets('카드 유형 아이콘은 한 색과 최소 라운드만 사용한다', (tester) async {
    const iconColor = Color(0xFFE8E8E8);
    await tester.pumpWidget(
      MaterialApp(
        home: Row(
          children: StoryCardType.editorOrder
              .map(
                (type) =>
                    StoryCardTypeIcon(type: type, size: 40, color: iconColor),
              )
              .toList(growable: false),
        ),
      ),
    );

    final painters = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((paint) => paint.painter)
        .whereType<StoryCardTypeIconPainter>()
        .toList(growable: false);
    expect(painters, hasLength(StoryCardType.editorOrder.length));
    for (final painter in painters) {
      expect(painter.color, iconColor);
      expect(painter.fillColor, iconColor);
      expect(painter.cornerRadius, lessThanOrEqualTo(1));
    }
  });
}
