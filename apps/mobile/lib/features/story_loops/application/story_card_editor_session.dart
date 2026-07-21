import 'dart:typed_data';

import '../data/story_card_draft.dart';
import '../data/story_card_scene.dart';

enum StoryCardEditorStage { camera, decorating }

enum StoryCardEditorTool { none, background, text, drawing }

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
      stage: hasPersistedCard
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

  StoryCardEditorSession enterBlankDecorator({
    required StoryCardEditorTool tool,
    StoryCardCanvasBackground background = StoryCardCanvasBackground.white,
  }) {
    return copyWith(
      stage: StoryCardEditorStage.decorating,
      tool: tool,
      draft: StoryCardDraft(
        scene: StoryCardScene.empty(canvasBackground: background),
      ),
      hasUnsavedChanges: false,
    );
  }

  StoryCardEditorSession enterPhotoDecorator(Uint8List imageBytes) {
    return copyWith(
      stage: StoryCardEditorStage.decorating,
      tool: StoryCardEditorTool.background,
      draft: StoryCardDraft(
        scene: StoryCardScene.empty(),
        backgroundImageBytes: imageBytes,
      ),
      hasUnsavedChanges: true,
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

  StoryCardEditorSession setCaption(String? caption) {
    return updateDraft(
      draft.copyWith(scene: draft.scene.copyWith(caption: caption)),
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
      draft.copyWith(
        scene: draft.scene.copyWith(backgroundTransform: transform),
      ),
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
      draft: StoryCardDraft(scene: StoryCardScene.empty()),
      tool: StoryCardEditorTool.none,
      hasUnsavedChanges: false,
    );
  }

  StoryCardEditorSession returnToCamera() {
    return copyWith(
      stage: StoryCardEditorStage.camera,
      tool: StoryCardEditorTool.none,
      draft: StoryCardDraft(scene: StoryCardScene.empty()),
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
