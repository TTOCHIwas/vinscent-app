import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import 'widgets/app_bottom_bar.dart';
import 'widgets/app_header.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child, required this.location});

  static const topMinHeight = 56.0;
  static const headerHeight = 56.0;
  static const bottomBarHeight = 76.0;

  final Widget child;
  final String location;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final showHeader = !_hidesMainHeader;
    final showBottomBar = !_usesAnswerEditBottomBar;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          SizedBox(height: math.max(topMinHeight, topInset)),
          if (showHeader)
            AppHeader(
              height: headerHeight,
              onSettingsPressed: () => context.go('/settings'),
            ),
          Expanded(child: child),
          if (showBottomBar)
            AppBottomBar(
              height: bottomBarHeight,
              currentLocation: location,
              onHomePressed: () => context.go('/home'),
              onCalendarPressed: () => context.go('/calendar'),
              onAiPressed: () => context.go('/ai'),
            ),
        ],
      ),
    );
  }

  bool get _hidesMainHeader {
    return location == '/calendar' ||
        location == '/home/question' ||
        location == '/home/question/edit';
  }

  bool get _usesAnswerEditBottomBar {
    return location == '/home/question/edit';
  }
}
