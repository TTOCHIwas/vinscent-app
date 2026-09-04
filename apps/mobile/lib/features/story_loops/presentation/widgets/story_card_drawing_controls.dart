import 'package:flutter/material.dart';

import '../../../../core/assets/app_icons.dart';
import '../../../../core/presentation/widgets/app_svg_icon.dart';
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
  final VoidCallback? onEyedropperPressed;
  final VoidCallback onDonePressed;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            key: const ValueKey('story-card-drawing-top-controls'),
            width: double.infinity,
            height: 56,
            child: ColoredBox(
              color: const Color(0x33000000),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    _DrawingIconButton(
                      buttonKey: const ValueKey('story-card-drawing-pen'),
                      tooltip: '펜',
                      icon: const Icon(Icons.edit),
                      isSelected: selectedTool == StoryCardDrawingTool.pen,
                      onPressed: () => onToolChanged(StoryCardDrawingTool.pen),
                    ),
                    const SizedBox(width: 6),
                    _DrawingIconButton(
                      buttonKey: const ValueKey('story-card-drawing-eraser'),
                      tooltip: '지우개',
                      icon: const AppSvgIcon(AppIcons.eraser),
                      isSelected: selectedTool == StoryCardDrawingTool.eraser,
                      onPressed: () =>
                          onToolChanged(StoryCardDrawingTool.eraser),
                    ),
                    const SizedBox(width: 6),
                    _DrawingIconButton(
                      buttonKey: const ValueKey('story-card-drawing-undo'),
                      tooltip: '되돌리기',
                      icon: const Icon(Icons.undo),
                      onPressed: canUndo ? onUndoPressed : null,
                    ),
                    const Spacer(),
                    _DrawingIconButton(
                      buttonKey: const ValueKey('story-card-drawing-done'),
                      tooltip: '그리기 완료',
                      icon: const Icon(Icons.check_rounded, size: 26),
                      isSelected: true,
                      onPressed: onDonePressed,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 4),
            child: SizedBox(
              key: const ValueKey('story-card-drawing-width-control'),
              width: 48,
              height: 220,
              child: RotatedBox(
                quarterTurns: 3,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: Colors.white,
                    inactiveTrackColor: Colors.white38,
                    thumbColor: Colors.white,
                    overlayColor: Colors.white12,
                    trackHeight: 2,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 9,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 18,
                    ),
                  ),
                  child: Slider(
                    min: storyCardMinStrokeWidth,
                    max: storyCardMaxStrokeWidth,
                    value: selectedStrokeWidth.clamp(
                      storyCardMinStrokeWidth,
                      storyCardMaxStrokeWidth,
                    ),
                    onChanged: onStrokeWidthChanged,
                  ),
                ),
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            key: const ValueKey('story-card-drawing-color-palette'),
            width: double.infinity,
            height: 72,
            child: ColoredBox(
              color: const Color(0x33000000),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                itemCount: storyCardColorPalette.length + 1,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _EyedropperButton(onPressed: onEyedropperPressed);
                  }
                  final color = storyCardColorPalette[index - 1];
                  return _ColorSwatch(
                    swatchKey: ValueKey(
                      'story-card-drawing-color-${index - 1}',
                    ),
                    color: color,
                    isSelected:
                        selectedTool == StoryCardDrawingTool.pen &&
                        color == selectedColor,
                    onPressed: () => onColorChanged(color),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DrawingIconButton extends StatelessWidget {
  const _DrawingIconButton({
    required this.buttonKey,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.isSelected = false,
  });

  final Key buttonKey;
  final String tooltip;
  final Widget icon;
  final VoidCallback? onPressed;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: buttonKey,
      tooltip: tooltip,
      onPressed: onPressed,
      icon: icon,
      color: isSelected ? Colors.black : Colors.white,
      disabledColor: Colors.white38,
      style: IconButton.styleFrom(
        backgroundColor: isSelected ? Colors.white : const Color(0x52000000),
        disabledBackgroundColor: const Color(0x33000000),
        side: BorderSide(color: isSelected ? Colors.white : Colors.white38),
      ),
    );
  }
}

class _EyedropperButton extends StatelessWidget {
  const _EyedropperButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 52,
      child: IconButton(
        key: const ValueKey('story-card-drawing-eyedropper'),
        tooltip: '스포이드',
        onPressed: onPressed,
        icon: const Icon(Icons.colorize_outlined),
        color: Colors.black,
        disabledColor: Colors.black38,
        style: IconButton.styleFrom(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.swatchKey,
    required this.color,
    required this.isSelected,
    required this.onPressed,
  });

  final Key swatchKey;
  final Color color;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 52,
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: InkWell(
          key: swatchKey,
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: isSelected ? Colors.white : Colors.white70,
                  width: isSelected ? 3 : 1.5,
                ),
                boxShadow: isSelected
                    ? const [BoxShadow(color: Color(0x66000000), blurRadius: 4)]
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
