import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import 'widgets/app_bottom_bar.dart';

class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.child,
    required this.location,
    this.navigationShell,
  });

  static const topMinHeight = 56.0;
  static const headerHeight = 56.0;
  static const bottomBarHeight = 90.0;

  final Widget child;
  final String location;
  final StatefulNavigationShell? navigationShell;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final showBottomBar = !_hidesBottomBar;
    final canPop =
        GoRouter.maybeOf(context)?.canPop() ?? Navigator.of(context).canPop();

    return PopScope(
      canPop: canPop || location == '/home',
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && location != '/home') {
          context.go('/home');
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        extendBody: showBottomBar,
        body: Column(
          children: [
            SizedBox(height: math.max(topMinHeight, topInset)),
            Expanded(child: child),
          ],
        ),
        bottomNavigationBar: showBottomBar
            ? AppBottomBar(
                height: bottomBarHeight,
                currentLocation: location,
                onHomePressed: () => _openBranch(context, 0, '/home'),
                onCalendarPressed: () => _openBranch(context, 1, '/calendar'),
                onAiPressed: () => _openBranch(context, 2, '/ai'),
              )
            : null,
      ),
    );
  }

  void _openBranch(BuildContext context, int index, String location) {
    final shell = navigationShell;
    if (shell == null) {
      context.go(location);
      return;
    }

    shell.goBranch(index, initialLocation: shell.currentIndex == index);
  }

  bool get _hidesBottomBar {
    return location.startsWith('/home/recordings') ||
        location == '/ai/ask' ||
        location == '/ai/memories' ||
        location == '/home/question/edit' ||
        location.startsWith('/settings');
  }
}
