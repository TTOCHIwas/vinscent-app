import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/story_loops/application/story_card_editor_session.dart';
import 'package:vinscent/features/story_loops/presentation/widgets/story_card_editor_action_bar.dart';

void main() {
  testWidgets('텍스트와 그리기 다음에 짧은 글 도구를 배치한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: StoryCardEditorActionBar(
              interactionMode: StoryCardEditorTool.none,
              hasBackground: true,
              onAddTextPressed: () {},
              onEditCaptionPressed: () {},
              onDrawingModePressed: () {},
              onBackgroundColorPressed: null,
            ),
          ),
        ),
      ),
    );

    final textY = tester.getCenter(find.byIcon(Icons.text_fields)).dy;
    final drawingY = tester.getCenter(find.byIcon(Icons.brush_outlined)).dy;
    final captionY = tester.getCenter(find.byIcon(Icons.short_text)).dy;

    expect(textY, lessThan(drawingY));
    expect(drawingY, lessThan(captionY));
  });
}
