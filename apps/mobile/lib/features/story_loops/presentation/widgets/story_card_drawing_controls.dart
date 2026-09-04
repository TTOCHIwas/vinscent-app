import 'package:flutter/material.dart';

import '../../../../core/drawing/app_drawing.dart';
import '../../../../core/drawing/widgets/app_drawing_style_controls.dart';
import '../../../../core/drawing/widgets/app_drawing_toolbar.dart';
import '../../data/story_card_scene.dart';

class StoryCardDrawingControls extends StatelessWidget {
  const StoryCardDrawingControls({
    super.key,
    required this.selectedTool,
    required this.selectedColor,
    required this.selectedStrokeWidth,
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
              color: const Color(0x33000000),
              child: SizedBox(
                height: AppDrawingToolbar.height,
                width: double.infinity,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: AppDrawingToolButton(
                      buttonKey: const ValueKey('story-card-drawing-done'),
                      tooltip: '그리기 완료',
                      icon: const Icon(Icons.check_rounded, size: 26),
                      isSelected: true,
                      onPressed: onDonePressed,
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
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: AppDrawingStyleControls(
              keyPrefix: 'story-card-drawing',
              previewClearance: AppDrawingToolbar.height,
              canvasExtent: applyBoxFit(
                BoxFit.contain,
                const Size(storyCardCanvasAspectRatio, 1),
                constraints.biggest,
              ).destination.shortestSide,
              selectedColor: selectedColor,
              selectedStrokeWidth: selectedStrokeWidth,
              showColorSelection: selectedTool == StoryCardDrawingTool.pen,
              onColorChanged: onColorChanged,
              onPickColor: onEyedropperPressed,
              onStrokeWidthChanged: onStrokeWidthChanged,
            ),
          ),
        ],
      ),
    );
  }
}
