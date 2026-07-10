import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/story_loops/data/story_card_draft.dart';
import 'package:vinscent/features/story_loops/data/story_card_editor_session.dart';
import 'package:vinscent/features/story_loops/data/story_card_scene.dart';

void main() {
  test('new card starts at the camera stage', () {
    final session = StoryCardEditorSession.fromDraft(
      StoryCardDraft(scene: StoryCardScene.empty()),
    );

    expect(session.stage, StoryCardEditorStage.camera);
    expect(session.hasUnsavedChanges, isFalse);
  });

  test('captured photo enters decorating with unsaved content', () {
    final session = StoryCardEditorSession.fromDraft(
      StoryCardDraft(scene: StoryCardScene.empty()),
    ).enterPhotoDecorator(Uint8List.fromList([1, 2, 3]));

    expect(session.stage, StoryCardEditorStage.decorating);
    expect(session.tool, StoryCardEditorTool.background);
    expect(session.draft.hasPhoto, isTrue);
    expect(session.hasUnsavedChanges, isTrue);
  });

  test('blank editor stays clean until its draft changes', () {
    final session = StoryCardEditorSession.fromDraft(
      StoryCardDraft(scene: StoryCardScene.empty()),
    ).enterBlankDecorator(tool: StoryCardEditorTool.text);

    expect(session.stage, StoryCardEditorStage.decorating);
    expect(session.tool, StoryCardEditorTool.text);
    expect(session.hasUnsavedChanges, isFalse);
  });

  test('discarding a new card stays clean in the decorating stage', () {
    final session = StoryCardEditorSession.fromDraft(
      StoryCardDraft(scene: StoryCardScene.empty()),
    ).enterPhotoDecorator(Uint8List.fromList([1])).discardChanges();

    expect(session.stage, StoryCardEditorStage.decorating);
    expect(session.draft.hasContent, isFalse);
    expect(session.hasUnsavedChanges, isFalse);
  });

  test('clean new decorator can return to a fresh camera stage', () {
    final session = StoryCardEditorSession.fromDraft(
      StoryCardDraft(scene: StoryCardScene.empty()),
    ).enterBlankDecorator(tool: StoryCardEditorTool.drawing).returnToCamera();

    expect(session.stage, StoryCardEditorStage.camera);
    expect(session.tool, StoryCardEditorTool.none);
    expect(session.draft.hasContent, isFalse);
  });

  test('persisted card starts in decorating and restores its baseline', () {
    final savedDraft = StoryCardDraft(
      scene: StoryCardScene.empty(),
      backgroundImageBytes: Uint8List.fromList([1]),
      existingRevision: 3,
    );
    final changedDraft = savedDraft.copyWith(
      scene: savedDraft.scene.copyWith(
        canvasBackground: StoryCardCanvasBackground.black,
      ),
    );
    final session = StoryCardEditorSession.fromDraft(
      savedDraft,
    ).updateDraft(changedDraft).discardChanges();

    expect(session.stage, StoryCardEditorStage.decorating);
    expect(session.draft, same(savedDraft));
    expect(session.hasUnsavedChanges, isFalse);
  });
}
