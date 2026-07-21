import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class HomeRecordingArtworkTrashTarget extends StatelessWidget {
  const HomeRecordingArtworkTrashTarget({required this.isActive, super.key});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      key: const ValueKey('home-recording-artwork-trash-target'),
      dimension: 64,
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
          key: const ValueKey('home-recording-artwork-trash-icon'),
          color: isActive ? AppColors.actionPrimary : Colors.white,
          size: isActive ? 34 : 30,
        ),
      ),
    );
  }
}
