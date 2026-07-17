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
  static const bottomBarHeight = 90.0;

  final Widget child;
  final String location;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final showHeader = !_hidesMainHeader;
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
            if (showHeader)
              AppHeader(
                height: headerHeight,
                showRelationshipDayCount: location == '/home',
                onRecordingLibraryPressed: () =>
                    context.push('/home/recordings'),
                onSettingsPressed: () => context.push('/settings'),
              ),
            Expanded(child: child),
          ],
        ),
        bottomNavigationBar: showBottomBar
            ? AppBottomBar(
                height: bottomBarHeight,
                currentLocation: location,
                onHomePressed: () => context.go('/home'),
                onCalendarPressed: () => context.go('/calendar'),
                onAiPressed: () => context.go('/ai'),
              )
            : null,
      ),
    );
  }

  bool get _hidesMainHeader {
    return location == '/calendar' ||
        location == '/calendar/question' ||
        location.startsWith('/home/recordings') ||
        location == '/home/question' ||
        location == '/home/question/edit' ||
        location.startsWith('/settings');
  }

  bool get _hidesBottomBar {
    return location.startsWith('/home/recordings') ||
        location == '/home/question/edit' ||
        location.startsWith('/settings');
  }
}
