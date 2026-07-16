import 'dart:ui';

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

  static const _surfaceRadius = 32.0;

  final double height;
  final String currentLocation;
  final VoidCallback onHomePressed;
  final VoidCallback onCalendarPressed;
  final VoidCallback onAiPressed;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return SizedBox(
      height: height + bottomInset,
      width: double.infinity,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + bottomInset),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_surfaceRadius),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shellBottomBarShadow,
                blurRadius: 24,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_surfaceRadius),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.shellBottomBarGlass,
                  borderRadius: BorderRadius.circular(_surfaceRadius),
                  border: Border.all(color: AppColors.shellBottomBarBorder),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: ShellTab(
                          label: '\ud648',
                          icon: Icons.home_rounded,
                          isSelected: currentLocation.startsWith('/home'),
                          onPressed: onHomePressed,
                        ),
                      ),
                      Expanded(
                        child: ShellTab(
                          label: '\ub2ec\ub825',
                          icon: Icons.calendar_today_rounded,
                          isSelected: currentLocation.startsWith('/calendar'),
                          onPressed: onCalendarPressed,
                        ),
                      ),
                      Expanded(
                        child: ShellTab(
                          label: 'AI',
                          icon: Icons.auto_awesome_rounded,
                          isSelected: currentLocation.startsWith('/ai'),
                          onPressed: onAiPressed,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
