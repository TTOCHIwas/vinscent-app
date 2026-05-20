import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import 'shell_tab.dart';

class AppBottomBar extends StatelessWidget {
  const AppBottomBar({
    super.key,
    required this.height,
    required this.currentLocation,
    required this.onHomePressed,
    required this.onCalendarPressed,
    required this.onAiPressed,
  });

  final double height;
  final String currentLocation;
  final VoidCallback onHomePressed;
  final VoidCallback onCalendarPressed;
  final VoidCallback onAiPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      color: AppColors.shellBottomBarBackground,
      padding: const EdgeInsets.fromLTRB(35, 10, 35, 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ShellTab(
            label: '홈',
            isSelected: currentLocation == '/home',
            onPressed: onHomePressed,
          ),
          ShellTab(
            label: '달력',
            isSelected: currentLocation == '/calendar',
            onPressed: onCalendarPressed,
          ),
          ShellTab(
            label: 'AI',
            isSelected: currentLocation == '/ai',
            onPressed: onAiPressed,
          ),
        ],
      ),
    );
  }
}
