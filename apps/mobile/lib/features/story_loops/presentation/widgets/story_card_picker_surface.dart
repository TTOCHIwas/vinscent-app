import 'package:flutter/material.dart';

const storyCardPickerMaxWidth = 360.0;
const storyCardPickerSurfaceColor = Color(0xCC000000);
const storyCardPickerDividerColor = Color(0x33FFFFFF);
const storyCardPickerCornerRadius = 2.0;

class StoryCardPickerSurface extends StatelessWidget {
  const StoryCardPickerSurface({
    super.key,
    required this.child,
    this.surfaceKey,
    this.color = storyCardPickerSurfaceColor,
  });

  final Widget child;
  final Key? surfaceKey;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: storyCardPickerMaxWidth),
        child: DecoratedBox(
          key: surfaceKey,
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.all(
              Radius.circular(storyCardPickerCornerRadius),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
