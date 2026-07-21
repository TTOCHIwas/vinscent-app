import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class StoryCardTextTrashTarget extends StatelessWidget {
  const StoryCardTextTrashTarget({super.key, required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      key: const ValueKey('story-card-text-trash-target'),
      dimension: 72,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive ? const Color(0xE6000000) : const Color(0xB8000000),
          border: Border.all(
            color: isActive ? AppColors.actionPrimary : Colors.white54,
          ),
        ),
        child: Icon(
          Icons.delete_outline,
          key: const ValueKey('story-card-text-trash-icon'),
          color: isActive ? AppColors.actionPrimary : Colors.white,
          size: isActive ? 36 : 32,
        ),
      ),
    );
  }
}
