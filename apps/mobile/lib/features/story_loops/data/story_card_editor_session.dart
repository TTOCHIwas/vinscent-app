import 'dart:typed_data';

import 'story_card_draft.dart';
import 'story_card_scene.dart';

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
