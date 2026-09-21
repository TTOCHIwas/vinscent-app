import 'dart:typed_data';
import 'dart:ui';

import '../data/story_card_draft.dart';
import '../data/story_card_film_look.dart';
import '../data/story_card_scene.dart';
import '../data/story_card_type.dart';

enum StoryCardEditorStage { formatSelection, camera, assembling, decorating }

enum StoryCardEditorTool { none, background, text, drawing, film }

class StoryCardEditorSession {
  const StoryCardEditorSession({
    required this.stage,
    required this.tool,
    required this.draft,
    required this.baselineDraft,
    required this.hasUnsavedChanges,
  });

  factory StoryCardEditorSession.fromDraft(StoryCardDraft draft) {
    final hasPersistedCard = draft.existingRevision != null;
    return StoryCardEditorSession(
      stage: hasPersistedCard || draft.hasDraftContent
          ? StoryCardEditorStage.decorating
          : StoryCardEditorStage.camera,
      tool: hasPersistedCard
          ? StoryCardEditorTool.none
          : StoryCardEditorTool.none,
      draft: draft,
      baselineDraft: draft,
      hasUnsavedChanges: false,
    );
  }

  final StoryCardEditorStage stage;
  final StoryCardEditorTool tool;
  final StoryCardDraft draft;
  final StoryCardDraft baselineDraft;
  final bool hasUnsavedChanges;

  bool get hasPersistedCard => baselineDraft.existingRevision != null;

  StoryCardEditorSession selectCardType(StoryCardType cardType) {
    return changeCardType(cardType);
  }

  StoryCardEditorSession changeCardType(StoryCardType cardType) {
    if (cardType == draft.scene.cardType) {
      return this;
    }
    final nextDraft = draft.copyWith(
      scene: draft.scene.copyWith(
        cardType: cardType,
        layoutVersion: storyCardCurrentLayoutVersion,
      ),
    );
    return copyWith(
      stage: nextDraft.hasDraftContent
          ? StoryCardEditorStage.decorating
          : StoryCardEditorStage.camera,
      tool: StoryCardEditorTool.none,
      draft: nextDraft,
      hasUnsavedChanges: nextDraft.hasDraftContent || hasUnsavedChanges,
    );
  }

  StoryCardEditorSession enterBlankDecorator({
    required StoryCardEditorTool tool,
    StoryCardCanvasBackground background = StoryCardCanvasBackground.white,
  }) {
    return copyWith(
      stage: StoryCardEditorStage.decorating,
      tool: tool,
      draft: StoryCardDraft(
        scene: StoryCardScene.empty(
          cardType: draft.scene.cardType,
          canvasBackground: background,
        ),
      ),
      hasUnsavedChanges: false,
    );
  }

  StoryCardEditorSession enterPhotoDecorator(
    Uint8List imageBytes, {
    StoryCardFilmState film = const StoryCardFilmState.original(),
  }) {
    return copyWith(
      stage: StoryCardEditorStage.decorating,
      tool: StoryCardEditorTool.background,
      draft: StoryCardDraft(
        scene: StoryCardScene.empty(
          cardType: draft.scene.cardType,
        ).copyWith(film: film),
        backgroundImageBytes: imageBytes,
      ),
      hasUnsavedChanges: true,
    );
  }

  StoryCardEditorSession setPhoto(int index, Uint8List imageBytes) {
    final nextDraft = draft.withPhoto(index, imageBytes);
    return updateDraft(
      nextDraft.copyWith(
        scene: nextDraft.scene
            .withPhotoTransform(
              index,
              const StoryCardBackgroundTransform.initial(),
            )
            .withPhotoFilm(index, const StoryCardFilmState.original()),
      ),
    );
  }

  StoryCardEditorSession removePhoto(int index) {
    final nextDraft = draft.withPhoto(index, null);
    return updateDraft(
      nextDraft.copyWith(
        scene: nextDraft.scene
            .withPhotoTransform(
              index,
              const StoryCardBackgroundTransform.initial(),
            )
            .withPhotoFilm(index, const StoryCardFilmState.original()),
      ),
    );
  }

  StoryCardEditorSession reorderPhotos(int fromIndex, int toIndex) {
    if (fromIndex == toIndex) {
      return this;
    }
    final nextDraft = draft.reorderPhotos(fromIndex, toIndex);
    return updateDraft(
      nextDraft.copyWith(
        scene: nextDraft.scene.reorderPhotoState(fromIndex, toIndex),
      ),
    );
  }

  StoryCardEditorSession enterFourCutDecorator() {
    if (!draft.scene.cardType.isFourCut || !draft.hasAllRequiredPhotos) {
      throw StateError('A complete four-cut draft is required.');
    }
    return copyWith(
      stage: StoryCardEditorStage.decorating,
      tool: StoryCardEditorTool.background,
    );
  }

  StoryCardEditorSession enterFourCutCamera() {
    if (!draft.scene.cardType.isFourCut) {
      throw StateError('A four-cut draft is required.');
    }
    return copyWith(
      stage: StoryCardEditorStage.camera,
      tool: StoryCardEditorTool.none,
    );
  }

  StoryCardEditorSession enterPhotoCamera() {
    return copyWith(
      stage: StoryCardEditorStage.camera,
      tool: StoryCardEditorTool.none,
    );
  }

  StoryCardEditorSession returnToFourCutAssembly() {
    if (!draft.scene.cardType.isFourCut) {
      throw StateError('A four-cut draft is required.');
    }
    return copyWith(
      stage: StoryCardEditorStage.assembling,
      tool: StoryCardEditorTool.none,
    );
  }

  StoryCardEditorSession returnToDecorator() {
    return copyWith(
      stage: StoryCardEditorStage.decorating,
      tool: draft.hasPhoto
          ? StoryCardEditorTool.background
          : StoryCardEditorTool.none,
    );
  }

  StoryCardEditorSession updateDraft(
    StoryCardDraft nextDraft, {
    StoryCardEditorTool? tool,
  }) {
    return copyWith(
      draft: nextDraft,
      tool: tool ?? this.tool,
      hasUnsavedChanges: true,
    );
  }

  StoryCardEditorSession selectTool(StoryCardEditorTool nextTool) {
    return copyWith(tool: nextTool);
  }

  StoryCardEditorSession appendStroke(StoryCardStroke stroke) {
    return updateDraft(
      draft.copyWith(
        scene: draft.scene.copyWith(strokes: [...draft.scene.strokes, stroke]),
      ),
    );
  }

  StoryCardEditorSession undoLastStroke() {
    if (draft.scene.strokes.isEmpty) {
      return this;
    }

    return updateDraft(
      draft.copyWith(
        scene: draft.scene.copyWith(
          strokes: draft.scene.strokes.sublist(
            0,
            draft.scene.strokes.length - 1,
          ),
        ),
      ),
    );
  }

  StoryCardEditorSession toggleCanvasBackground() {
    final background =
        draft.scene.canvasBackground == StoryCardCanvasBackground.white
        ? StoryCardCanvasBackground.black
        : StoryCardCanvasBackground.white;
    return updateDraft(
      draft.copyWith(scene: draft.scene.copyWith(canvasBackground: background)),
    );
  }

  StoryCardEditorSession setCardBackgroundColor(Color color) {
    if (draft.scene.appearance.backgroundColor == color) {
      return this;
    }
    return updateDraft(
      draft.copyWith(
        scene: draft.scene.copyWith(
          appearance: draft.scene.appearance.copyWith(backgroundColor: color),
        ),
      ),
    );
  }

  StoryCardEditorSession setCaption(String? caption) {
    return updateDraft(
      draft.copyWith(scene: draft.scene.copyWith(caption: caption)),
    );
  }

  StoryCardEditorSession setFilm(StoryCardFilmState film) {
    if (!draft.hasPhoto || draft.scene.film == film) {
      return this;
    }
    return setPhotoFilm(0, film);
  }

  StoryCardEditorSession setPhotoFilm(int index, StoryCardFilmState film) {
    if (index < 0 ||
        index >= draft.photoImageBytes.length ||
        draft.photoImageBytes[index] == null ||
        draft.scene.photoFilms[index] == film) {
      return this;
    }
    return updateDraft(
      draft.copyWith(scene: draft.scene.withPhotoFilm(index, film)),
    );
  }

  StoryCardEditorSession addTextLayer(StoryCardTextLayer layer) {
    return updateDraft(
      draft.copyWith(
        scene: draft.scene.copyWith(
          textLayers: [...draft.scene.textLayers, layer],
        ),
      ),
    );
  }

  StoryCardEditorSession setBackgroundTransform(
    StoryCardBackgroundTransform transform,
  ) {
    return updateDraft(
      draft.copyWith(scene: draft.scene.withPhotoTransform(0, transform)),
    );
  }

  StoryCardEditorSession setPhotoTransform(
    int index,
    StoryCardBackgroundTransform transform,
  ) {
    return updateDraft(
      draft.copyWith(scene: draft.scene.withPhotoTransform(index, transform)),
    );
  }

  StoryCardEditorSession replaceTextLayer(StoryCardTextLayer replacement) {
    if (!draft.scene.textLayers.any((layer) => layer.id == replacement.id)) {
      return this;
    }

    return updateDraft(
      draft.copyWith(
        scene: draft.scene.copyWith(
          textLayers: draft.scene.textLayers
              .map((layer) => layer.id == replacement.id ? replacement : layer)
              .toList(growable: false),
        ),
      ),
    );
  }

  StoryCardEditorSession removeTextLayer(String layerId) {
    if (!draft.scene.textLayers.any((layer) => layer.id == layerId)) {
      return this;
    }

    return updateDraft(
      draft.copyWith(
        scene: draft.scene.copyWith(
          textLayers: draft.scene.textLayers
              .where((layer) => layer.id != layerId)
              .toList(growable: false),
        ),
      ),
    );
  }

  StoryCardEditorSession discardChanges() {
    if (hasPersistedCard) {
      return copyWith(
        draft: baselineDraft,
        tool: StoryCardEditorTool.none,
        hasUnsavedChanges: false,
      );
    }

    return copyWith(
      stage: StoryCardEditorStage.camera,
      draft: StoryCardDraft(
        scene: StoryCardScene.empty(cardType: StoryCardType.fullBleed),
      ),
      tool: StoryCardEditorTool.none,
      hasUnsavedChanges: false,
    );
  }

  StoryCardEditorSession returnToCamera() {
    return copyWith(
      stage: StoryCardEditorStage.camera,
      tool: StoryCardEditorTool.none,
      draft: StoryCardDraft(
        scene: StoryCardScene.empty(cardType: StoryCardType.fullBleed),
      ),
      hasUnsavedChanges: false,
    );
  }

  StoryCardEditorSession copyWith({
    StoryCardEditorStage? stage,
    StoryCardEditorTool? tool,
    StoryCardDraft? draft,
    StoryCardDraft? baselineDraft,
    bool? hasUnsavedChanges,
  }) {
    return StoryCardEditorSession(
      stage: stage ?? this.stage,
      tool: tool ?? this.tool,
      draft: draft ?? this.draft,
      baselineDraft: baselineDraft ?? this.baselineDraft,
      hasUnsavedChanges: hasUnsavedChanges ?? this.hasUnsavedChanges,
    );
  }
}
