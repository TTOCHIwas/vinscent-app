import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/story_loops/data/story_card_draft.dart';
import 'package:vinscent/features/story_loops/application/story_card_editor_session.dart';
import 'package:vinscent/features/story_loops/data/story_card_film_look.dart';
import 'package:vinscent/features/story_loops/data/story_card_scene.dart';
import 'package:vinscent/features/story_loops/data/story_card_type.dart';

void main() {
  test('new card starts in the camera with the full-bleed format', () {
    final session = StoryCardEditorSession.fromDraft(
      StoryCardDraft(
        scene: StoryCardScene.empty(cardType: StoryCardType.fullBleed),
      ),
    );

    expect(session.stage, StoryCardEditorStage.camera);
    expect(session.draft.scene.cardType, StoryCardType.fullBleed);
    expect(session.hasUnsavedChanges, isFalse);
  });

  test(
    'changing type in the editor preserves captured photos and edit layers',
    () {
      final firstPhoto = Uint8List.fromList([1]);
      const layer = StoryCardTextLayer(
        id: 'layer',
        text: '함께',
        x: 0.5,
        y: 0.5,
        color: Color(0xFF111111),
      );
      final session = StoryCardEditorSession.fromDraft(
        StoryCardDraft(
          scene: StoryCardScene.empty(cardType: StoryCardType.fullBleed),
        ),
      ).enterPhotoDecorator(firstPhoto).addTextLayer(layer);

      final fourCut = session.changeCardType(StoryCardType.fourCutGrid);
      final polaroid = fourCut.changeCardType(StoryCardType.polaroid);

      expect(fourCut.stage, StoryCardEditorStage.decorating);
      expect(fourCut.draft.scene.layoutVersion, storyCardCurrentLayoutVersion);
      expect(fourCut.draft.photoImageBytes.first, same(firstPhoto));
      expect(fourCut.draft.scene.textLayers, [layer]);
      expect(polaroid.draft.photoImageBytes.single, same(firstPhoto));
      expect(polaroid.draft.scene.textLayers, [layer]);
    },
  );

  test('inactive photos keep a loaded local draft in the editor', () {
    final session = StoryCardEditorSession.fromDraft(
      StoryCardDraft(
        scene: StoryCardScene.empty(cardType: StoryCardType.fullBleed),
        additionalPhotoImageBytes: [
          Uint8List.fromList([2]),
        ],
      ),
    );

    expect(session.stage, StoryCardEditorStage.decorating);
    expect(session.draft.canSave, isFalse);
  });

  test('four-cut photos are filled independently before decorating', () {
    var session = StoryCardEditorSession.fromDraft(
      StoryCardDraft(scene: StoryCardScene.empty()),
    ).changeCardType(StoryCardType.fourCutGrid);

    for (var index = 0; index < 4; index++) {
      session = session.setPhoto(index, Uint8List.fromList([index]));
    }
    final decorating = session.enterFourCutDecorator();

    expect(session.draft.hasAllRequiredPhotos, isTrue);
    expect(decorating.stage, StoryCardEditorStage.decorating);
    expect(decorating.tool, StoryCardEditorTool.background);
  });

  test('captured photo enters decorating with unsaved content', () {
    const film = StoryCardFilmState(look: StoryCardFilmLook.warmth, seed: 31);
    final session =
        StoryCardEditorSession.fromDraft(
              StoryCardDraft(scene: StoryCardScene.empty()),
            )
            .changeCardType(StoryCardType.polaroid)
            .enterPhotoDecorator(Uint8List.fromList([1, 2, 3]), film: film);

    expect(session.stage, StoryCardEditorStage.decorating);
    expect(session.tool, StoryCardEditorTool.background);
    expect(session.draft.hasPhoto, isTrue);
    expect(session.draft.scene.film, film);
    expect(session.hasUnsavedChanges, isTrue);
  });

  test(
    'changing a film look preserves the photo and marks the draft dirty',
    () {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final session =
          StoryCardEditorSession.fromDraft(
                StoryCardDraft(scene: StoryCardScene.empty()),
              )
              .changeCardType(StoryCardType.polaroid)
              .enterPhotoDecorator(bytes)
              .setFilm(
                const StoryCardFilmState(
                  look: StoryCardFilmLook.moment,
                  seed: 77,
                ),
              );

      expect(session.draft.backgroundImageBytes, same(bytes));
      expect(session.draft.scene.film.look, StoryCardFilmLook.moment);
      expect(session.draft.scene.film.seed, 77);
      expect(session.hasUnsavedChanges, isTrue);
    },
  );

  test('blank editor stays clean until its draft changes', () {
    final session = StoryCardEditorSession.fromDraft(
      StoryCardDraft(scene: StoryCardScene.empty()),
    ).enterBlankDecorator(tool: StoryCardEditorTool.text);

    expect(session.stage, StoryCardEditorStage.decorating);
    expect(session.tool, StoryCardEditorTool.text);
    expect(session.hasUnsavedChanges, isFalse);
  });

  test('discarding a new card stays clean in the decorating stage', () {
    final session =
        StoryCardEditorSession.fromDraft(
              StoryCardDraft(scene: StoryCardScene.empty()),
            )
            .changeCardType(StoryCardType.polaroid)
            .enterPhotoDecorator(Uint8List.fromList([1]))
            .discardChanges();

    expect(session.stage, StoryCardEditorStage.camera);
    expect(session.draft.hasContent, isFalse);
    expect(session.hasUnsavedChanges, isFalse);
  });

  test('clean new decorator can return to a fresh camera stage', () {
    final session =
        StoryCardEditorSession.fromDraft(
              StoryCardDraft(scene: StoryCardScene.empty()),
            )
            .changeCardType(StoryCardType.polaroid)
            .enterBlankDecorator(tool: StoryCardEditorTool.drawing)
            .returnToCamera();

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

  test('updates the card appearance without changing its type', () {
    final session = StoryCardEditorSession.fromDraft(
      StoryCardDraft(
        scene: StoryCardScene.empty(cardType: StoryCardType.fourCutGrid),
      ),
    );
    const selectedColor = Color(0xFFB7D5C4);

    final updated = session.setCardBackgroundColor(selectedColor);

    expect(updated.draft.scene.cardType, StoryCardType.fourCutGrid);
    expect(updated.draft.scene.appearance.backgroundColor, selectedColor);
    expect(updated.hasUnsavedChanges, isTrue);
    expect(updated.setCardBackgroundColor(selectedColor), same(updated));
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

  test('updates one four-cut transform without moving the other slots', () {
    final session = StoryCardEditorSession.fromDraft(
      StoryCardDraft(
        scene: StoryCardScene.empty(cardType: StoryCardType.fourCutStrip),
        existingRevision: 1,
      ),
    );
    const transform = StoryCardBackgroundTransform(
      scale: 2,
      offsetX: -0.2,
      offsetY: 0.1,
    );

    final updated = session.setPhotoTransform(3, transform);

    expect(updated.draft.scene.photoTransforms[3], same(transform));
    expect(
      updated.draft.scene.photoTransforms.take(3),
      everyElement(const StoryCardBackgroundTransform.initial()),
    );
  });

  test('replacing a four-cut photo resets only that slot transform', () {
    final session = StoryCardEditorSession.fromDraft(
      StoryCardDraft(
        scene: StoryCardScene.empty(cardType: StoryCardType.fourCutGrid)
            .withPhotoTransform(
              1,
              const StoryCardBackgroundTransform(
                scale: 1.8,
                offsetX: 0.2,
                offsetY: -0.1,
              ),
            )
            .withPhotoTransform(
              2,
              const StoryCardBackgroundTransform(
                scale: 1.4,
                offsetX: -0.1,
                offsetY: 0.1,
              ),
            ),
      ),
    );

    final updated = session.setPhoto(1, Uint8List.fromList([9]));

    expect(
      updated.draft.scene.photoTransforms[1],
      const StoryCardBackgroundTransform.initial(),
    );
    expect(updated.draft.scene.photoTransforms[2].scale, 1.4);
    expect(updated.draft.photoImageBytes[1], Uint8List.fromList([9]));
  });

  test('reordering photos keeps bytes, transform, and film together', () {
    const transformed = StoryCardBackgroundTransform(
      scale: 1.7,
      offsetX: 0.2,
      offsetY: -0.1,
      rotation: 0.4,
    );
    const filtered = StoryCardFilmState(
      look: StoryCardFilmLook.quiet,
      seed: 77,
    );
    var session = StoryCardEditorSession.fromDraft(
      StoryCardDraft(
        scene: StoryCardScene.empty(cardType: StoryCardType.fourCutGrid),
      ),
    );
    for (var index = 0; index < 4; index++) {
      session = session.setPhoto(index, Uint8List.fromList([index]));
    }
    session = session
        .setPhotoTransform(0, transformed)
        .setPhotoFilm(0, filtered)
        .reorderPhotos(0, 2);

    expect(session.draft.photoImageBytes[2], Uint8List.fromList([0]));
    expect(session.draft.scene.photoTransforms[2], transformed);
    expect(session.draft.scene.photoFilms[2], filtered);
    expect(session.draft.photoImageBytes[0], Uint8List.fromList([2]));
  });

  test('removing one photo clears only that photo state', () {
    var session = StoryCardEditorSession.fromDraft(
      StoryCardDraft(
        scene: StoryCardScene.empty(cardType: StoryCardType.fourCutGrid),
      ),
    ).setPhoto(1, Uint8List.fromList([9]));
    session = session
        .setPhotoTransform(
          1,
          const StoryCardBackgroundTransform(
            scale: 2,
            offsetX: 0.1,
            offsetY: 0.2,
            rotation: 0.3,
          ),
        )
        .setPhotoFilm(
          1,
          const StoryCardFilmState(look: StoryCardFilmLook.color, seed: 12),
        )
        .removePhoto(1);

    expect(session.draft.photoImageBytes[1], isNull);
    expect(
      session.draft.scene.photoTransforms[1],
      const StoryCardBackgroundTransform.initial(),
    );
    expect(
      session.draft.scene.photoFilms[1],
      const StoryCardFilmState.original(),
    );
  });
}
