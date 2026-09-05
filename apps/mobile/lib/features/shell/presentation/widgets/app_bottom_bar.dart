import 'dart:math' as math;
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
    this.showHomeAttention = false,
    this.showCalendarAttention = false,
    this.showAiAttention = false,
  });

  static const _surfaceRadius = 100.0;
  static const _baseBottomGap = 18.0;

  final double height;
  final String currentLocation;
  final VoidCallback onHomePressed;
  final VoidCallback onCalendarPressed;
  final VoidCallback onAiPressed;
  final bool showHomeAttention;
  final bool showCalendarAttention;
  final bool showAiAttention;

  static double bottomGapFor({
    required TargetPlatform platform,
    required double bottomInset,
  }) {
    if (platform == TargetPlatform.iOS) {
      return math.max(_baseBottomGap, bottomInset);
    }
    return _baseBottomGap + bottomInset;
  }

  static double layoutHeightFor({
    required double height,
    required TargetPlatform platform,
    required double bottomInset,
  }) {
    return height -
        _baseBottomGap +
        bottomGapFor(platform: platform, bottomInset: bottomInset);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final platform = Theme.of(context).platform;
    final bottomGap = bottomGapFor(
      platform: platform,
      bottomInset: bottomInset,
    );

    return SizedBox(
      height: layoutHeightFor(
        height: height,
        platform: platform,
        bottomInset: bottomInset,
      ),
      width: double.infinity,
      child: Padding(
        padding: EdgeInsets.fromLTRB(18, 8, 18, bottomGap),
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
                          showAttentionIndicator: showHomeAttention,
                          attentionIndicatorKey: const Key(
                            'shell-tab-home-attention',
                          ),
                          onPressed: onHomePressed,
                        ),
                      ),
                      Expanded(
                        child: ShellTab(
                          label: '\ub2ec\ub825',
                          icon: Icons.calendar_today_rounded,
                          isSelected: currentLocation.startsWith('/calendar'),
                          showAttentionIndicator: showCalendarAttention,
                          attentionIndicatorKey: const Key(
                            'shell-tab-calendar-attention',
                          ),
                          onPressed: onCalendarPressed,
                        ),
                      ),
                      Expanded(
                        child: ShellTab(
                          label: 'AI',
                          icon: Icons.auto_awesome_rounded,
                          isSelected: currentLocation.startsWith('/ai'),
                          showAttentionIndicator: showAiAttention,
                          attentionIndicatorKey: const Key(
                            'shell-tab-ai-attention',
                          ),
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
