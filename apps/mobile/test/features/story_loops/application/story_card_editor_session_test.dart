import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/story_loops/data/story_card_draft.dart';
import 'package:vinscent/features/story_loops/application/story_card_editor_session.dart';
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

  test('appends and undoes drawing strokes as session transitions', () {
    final session = StoryCardEditorSession.fromDraft(
      StoryCardDraft(scene: StoryCardScene.empty()),
    );
    const stroke = StoryCardStroke(
      color: Color(0xFF111111),
      width: storyCardNormalStrokeWidth,
      points: [StoryCardPoint(x: 0.2, y: 0.3)],
    );

    final drawn = session.appendStroke(stroke);
    final undone = drawn.undoLastStroke();

    expect(drawn.draft.scene.strokes, [stroke]);
    expect(drawn.hasUnsavedChanges, isTrue);
    expect(undone.draft.scene.strokes, isEmpty);
    expect(session.undoLastStroke(), same(session));
  });

  test('updates caption, canvas background, and text layers', () {
    final session = StoryCardEditorSession.fromDraft(
      StoryCardDraft(scene: StoryCardScene.empty()),
    );
    const layer = StoryCardTextLayer(
      id: 'text-1',
      text: 'hello',
      x: 0.5,
      y: 0.5,
      color: Color(0xFFFFFFFF),
    );

    final updated = session
        .toggleCanvasBackground()
        .setCaption('caption')
        .addTextLayer(layer);

    expect(
      updated.draft.scene.canvasBackground,
      StoryCardCanvasBackground.black,
    );
    expect(updated.draft.scene.caption, 'caption');
    expect(updated.draft.scene.textLayers, [layer]);
  });

  test('updates transforms and removes a text layer', () {
    const layer = StoryCardTextLayer(
      id: 'text-1',
      text: 'hello',
      x: 0.5,
      y: 0.5,
      color: Color(0xFFFFFFFF),
    );
    final session = StoryCardEditorSession.fromDraft(
      StoryCardDraft(
        scene: StoryCardScene.empty().copyWith(textLayers: const [layer]),
      ),
    );
    const transform = StoryCardBackgroundTransform(
      scale: 2,
      offsetX: 0.1,
      offsetY: -0.2,
    );

    final transformed = session
        .setBackgroundTransform(transform)
        .replaceTextLayer(layer.copyWith(x: 0.8, scale: 1.5));
    final removed = transformed.removeTextLayer(layer.id);

    expect(transformed.draft.scene.backgroundTransform, same(transform));
    expect(transformed.draft.scene.textLayers.single.x, 0.8);
    expect(transformed.draft.scene.textLayers.single.scale, 1.5);
    expect(removed.draft.scene.textLayers, isEmpty);
  });
}
