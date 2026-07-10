import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:vinscent/core/presentation/widgets/app_back_button.dart';
import 'package:vinscent/features/story_loops/application/story_card_editor_controller.dart';
import 'package:vinscent/features/story_loops/data/story_card_draft.dart';
import 'package:vinscent/features/story_loops/data/story_card_scene.dart';
import 'package:vinscent/features/story_loops/presentation/story_card_editor_screen.dart';

void main() {
  testWidgets('keeps the editor header at the top of the screen', (
    tester,
  ) async {
    await _pumpEditor(tester, draft: _existingEmptyDraft());

    final header = find.byKey(const ValueKey('story-card-editor-header'));
    final save = find.byKey(const ValueKey('story-card-editor-save'));
    final textTool = find.byIcon(Icons.text_fields);

    expect(tester.getSize(header).height, 56);
    expect(tester.getTopLeft(header).dy, 0);
    expect(tester.getRect(save).overlaps(tester.getRect(textTool)), isFalse);
  });

  testWidgets('delivers text placement taps to the canvas', (tester) async {
    await _pumpEditor(tester, draft: _existingEmptyDraft());

    await tester.tap(find.byIcon(Icons.text_fields));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('story-card-editor-canvas')));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('delivers drawing pointer events to the canvas', (tester) async {
    await _pumpEditor(tester, draft: _existingEmptyDraft());

    TextButton saveButton() => tester.widget<TextButton>(
      find.byKey(const ValueKey('story-card-editor-save')),
    );

    expect(saveButton().onPressed, isNull);

    await tester.tap(find.byIcon(Icons.brush_outlined));
    await tester.pump();

    final canvas = find.byKey(const ValueKey('story-card-editor-canvas'));
    final center = tester.getCenter(canvas);
    await tester.dragFrom(center - const Offset(30, 30), const Offset(60, 60));
    await tester.pump();

    expect(saveButton().onPressed, isNotNull);
  });

  testWidgets('delivers background transform gestures to the canvas', (
    tester,
  ) async {
    await _pumpEditor(tester, draft: _existingPhotoDraft());

    await tester.tap(find.byIcon(Icons.crop));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();

    final canvas = find.byKey(const ValueKey('story-card-editor-canvas'));
    final scaleDetectors = tester
        .widgetList<GestureDetector>(
          find.descendant(of: canvas, matching: find.byType(GestureDetector)),
        )
        .where((detector) => detector.onScaleUpdate != null);
    expect(scaleDetectors, hasLength(1));

    final center = tester.getCenter(canvas);
    await tester.dragFrom(center, const Offset(40, 50));
    await tester.pump();

    await tester.tap(find.byType(AppBackButton));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
  });
}

Future<void> _pumpEditor(
  WidgetTester tester, {
  required StoryCardDraft draft,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        storyCardEditorControllerProvider.overrideWith(
          () => _TestStoryCardEditorController(draft),
        ),
      ],
      child: const MaterialApp(home: StoryCardEditorScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

StoryCardDraft _existingEmptyDraft() {
  return StoryCardDraft(scene: StoryCardScene.empty(), existingRevision: 1);
}

StoryCardDraft _existingPhotoDraft() {
  final photo = image.Image(width: 4, height: 4);
  return StoryCardDraft(
    scene: StoryCardScene.empty(),
    backgroundImageBytes: Uint8List.fromList(image.encodePng(photo)),
    existingRevision: 1,
  );
}

class _TestStoryCardEditorController extends StoryCardEditorController {
  _TestStoryCardEditorController(this.draft);

  final StoryCardDraft draft;

  @override
  Future<StoryCardDraft> build() async => draft;
}
