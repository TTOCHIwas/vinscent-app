import 'package:flutter/material.dart';

import '../../../../core/drawing/app_drawing.dart';
import '../../../../core/drawing/widgets/app_drawing_style_controls.dart';
import '../../../../core/drawing/widgets/app_drawing_toolbar.dart';
import '../../data/story_card_scene.dart';
import 'story_card_editor_style.dart';
import 'story_card_interactive_viewport.dart';

class StoryCardDrawingControls extends StatelessWidget {
  const StoryCardDrawingControls({
    super.key,
    required this.selectedTool,
    required this.selectedColor,
    required this.selectedStrokeWidth,
    required this.cardAspectRatio,
    required this.canUndo,
    required this.onToolChanged,
    required this.onColorChanged,
    required this.onStrokeWidthChanged,
    required this.onUndoPressed,
    required this.onEyedropperPressed,
    required this.onDonePressed,
  });

  final StoryCardDrawingTool selectedTool;
  final Color selectedColor;
  final double selectedStrokeWidth;
  final double cardAspectRatio;
  final bool canUndo;
  final ValueChanged<StoryCardDrawingTool> onToolChanged;
  final ValueChanged<Color> onColorChanged;
  final ValueChanged<double> onStrokeWidthChanged;
  final VoidCallback onUndoPressed;
  final Future<Color?> Function()? onEyedropperPressed;
  final VoidCallback onDonePressed;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Stack(
        fit: StackFit.expand,
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: Material(
              key: const ValueKey('story-card-drawing-header-surface'),
              color: Colors.transparent,
              child: SizedBox(
                height: AppDrawingToolbar.height,
                width: double.infinity,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox.square(
                      dimension: 48,
                      child: IconButton(
                        key: const ValueKey('story-card-drawing-done'),
                        tooltip: '그리기 완료',
                        color: Colors.white,
                        icon: const Icon(
                          Icons.check_rounded,
                          size: 26,
                          shadows: storyCardEditorControlShadows,
                        ),
                        onPressed: onDonePressed,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: AppDrawingStyleControls.height,
            child: AppDrawingToolbar(
              keyPrefix: 'story-card-drawing',
              selectedTool: selectedTool == StoryCardDrawingTool.pen
                  ? AppDrawingTool.pen
                  : AppDrawingTool.eraser,
              isReadOnly: false,
              canUndo: canUndo,
              onToolChanged: (tool) => onToolChanged(
                tool == AppDrawingTool.pen
                    ? StoryCardDrawingTool.pen
                    : StoryCardDrawingTool.eraser,
              ),
              onUndoPressed: onUndoPressed,
              backgroundColor: Colors.transparent,
              showContrastShadow: true,
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: AppDrawingStyleControls(
              keyPrefix: 'story-card-drawing',
              previewClearance: AppDrawingToolbar.height,
              canvasExtent: applyBoxFit(
                BoxFit.contain,
                Size(cardAspectRatio, 1),
                constraints.deflate(storyCardEditorViewportInsets).biggest,
              ).destination.shortestSide,
              selectedColor: selectedColor,
              selectedStrokeWidth: selectedStrokeWidth,
              showColorSelection: selectedTool == StoryCardDrawingTool.pen,
              onColorChanged: onColorChanged,
              onPickColor: onEyedropperPressed,
              onStrokeWidthChanged: onStrokeWidthChanged,
              backgroundColor: Colors.transparent,
              showContrastShadow: true,
            ),
          ),
        ],
      ),
    );
  }
}
