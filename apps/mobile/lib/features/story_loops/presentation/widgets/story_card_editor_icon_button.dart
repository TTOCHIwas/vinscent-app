import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class StoryCardEditorIconButton extends StatelessWidget {
  const StoryCardEditorIconButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
    this.icon,
    this.iconWidget,
    this.isSelected = false,
  }) : assert(icon != null || iconWidget != null),
       assert(icon == null || iconWidget == null);

  final String tooltip;
  final IconData? icon;
  final Widget? iconWidget;
  final VoidCallback? onPressed;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: iconWidget ?? Icon(icon),
      color: Colors.white,
      style: IconButton.styleFrom(
        backgroundColor: isSelected
            ? AppColors.actionPrimary
            : const Color(0x85000000),
      ),
    );
  }
}
