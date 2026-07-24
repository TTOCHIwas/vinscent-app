import 'package:flutter/material.dart';

import '../../../../core/assets/app_icons.dart';
import '../../../../core/presentation/widgets/app_svg_icon.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/story_card_scene.dart';
import 'story_card_editor_icon_button.dart';

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
  final VoidCallback onDonePressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xB8000000),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                StoryCardEditorIconButton(
                  key: const ValueKey('story-card-drawing-pen'),
                  tooltip: '펜',
                  icon: Icons.edit,
                  isSelected: selectedTool == StoryCardDrawingTool.pen,
                  onPressed: () => onToolChanged(StoryCardDrawingTool.pen),
                ),
                const SizedBox(width: 6),
                StoryCardEditorIconButton(
                  key: const ValueKey('story-card-drawing-eraser'),
                  tooltip: '지우개',
                  iconWidget: const AppSvgIcon(AppIcons.eraser),
                  isSelected: selectedTool == StoryCardDrawingTool.eraser,
                  onPressed: () => onToolChanged(StoryCardDrawingTool.eraser),
                ),
                const SizedBox(width: 6),
                StoryCardEditorIconButton(
                  key: const ValueKey('story-card-drawing-undo'),
                  tooltip: '되돌리기',
                  icon: Icons.undo,
                  onPressed: canUndo ? onUndoPressed : null,
                ),
                const Spacer(),
                TextButton(
                  key: const ValueKey('story-card-drawing-done'),
                  onPressed: onDonePressed,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: AppColors.actionPrimary,
                    minimumSize: const Size(64, 40),
                  ),
                  child: const Text('완료'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final color in storyCardColorPalette)
                  GestureDetector(
                    onTap: () => onColorChanged(color),
                    child: Container(
                      width: 28,
                      height: 28,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color:
                              color == selectedColor &&
                                  selectedTool == StoryCardDrawingTool.pen
                              ? Colors.white
                              : Colors.white54,
                          width:
                              color == selectedColor &&
                                  selectedTool == StoryCardDrawingTool.pen
                              ? 2
                              : 1,
                        ),
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Text('굵기', style: AppTextStyles.drawingToolLabel),
                const SizedBox(width: 10),
                SizedBox.square(
                  dimension: 44,
                  child: Center(
                    child: Container(
                      width: 12 + selectedStrokeWidth * 300,
                      height: 12 + selectedStrokeWidth * 300,
                      decoration: BoxDecoration(
                        color: selectedTool == StoryCardDrawingTool.pen
                            ? selectedColor
                            : Colors.white70,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Slider(
                    min: storyCardMinStrokeWidth,
                    max: storyCardMaxStrokeWidth,
                    value: selectedStrokeWidth.clamp(
                      storyCardMinStrokeWidth,
                      storyCardMaxStrokeWidth,
                    ),
                    activeColor: Colors.white,
                    inactiveColor: Colors.white38,
                    onChanged: onStrokeWidthChanged,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
