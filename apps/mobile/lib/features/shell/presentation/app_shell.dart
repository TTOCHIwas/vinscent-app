import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../application/app_attention_summary.dart';
import 'widgets/app_bottom_bar.dart';
import 'widgets/shell_bottom_bar_visibility_notification.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.child,
    required this.location,
    this.navigationShell,
    this.showHomeAttention = false,
    this.showCalendarAttention = false,
    this.showAiAttention = false,
    this.observeAttention = false,
  });

  static const topMinHeight = 56.0;
  static const headerHeight = 56.0;
  static const bottomBarHeight = 90.0;
  static const bottomBarMotionDuration = Duration(milliseconds: 180);
  static const bottomBarMotionCurve = Cubic(0.22, 0.25, 0, 1);

  final Widget child;
  final String location;
  final StatefulNavigationShell? navigationShell;
  final bool showHomeAttention;
  final bool showCalendarAttention;
  final bool showAiAttention;
  final bool observeAttention;

  @override
  State<AppShell> createState() => _AppShellState();

  bool get _hidesBottomBar {
    return location.startsWith('/home/recordings') ||
        location.startsWith('/calendar/event') ||
        location == '/ai/ask' ||
        location == '/ai/memories' ||
        location == '/home/question/edit' ||
        location.startsWith('/settings');
  }
}

class _AppShellState extends State<AppShell> {
  bool _isBottomBarRequestedHidden = false;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final showBottomBar = !widget._hidesBottomBar;
    final isBottomBarHidden =
        showBottomBar &&
        widget.location == '/calendar' &&
        _isBottomBarRequestedHidden;
    final canPop =
        GoRouter.maybeOf(context)?.canPop() ?? Navigator.of(context).canPop();
    Widget buildBottomBarContent(AppAttentionSummary? attention) {
      return IgnorePointer(
        ignoring: isBottomBarHidden,
        child: ExcludeSemantics(
          excluding: isBottomBarHidden,
          child: AppBottomBar(
            height: AppShell.bottomBarHeight,
            currentLocation: widget.location,
            showHomeAttention:
                attention?.hasHomeAttention ?? widget.showHomeAttention,
            showCalendarAttention:
                attention?.hasCalendarAttention ?? widget.showCalendarAttention,
            showAiAttention:
                attention?.hasAiAttention ?? widget.showAiAttention,
            onHomePressed: () => _openBranch(context, 0, '/home'),
            onCalendarPressed: () => _openBranch(context, 1, '/calendar'),
            onAiPressed: () => _openBranch(context, 2, '/ai'),
          ),
        ),
      );
    }

    final bottomNavigationBar = !showBottomBar
        ? null
        : AnimatedSlide(
            key: const Key('shell-bottom-bar-motion'),
            offset: isBottomBarHidden ? const Offset(0, 1) : Offset.zero,
            duration: AppShell.bottomBarMotionDuration,
            curve: AppShell.bottomBarMotionCurve,
            child: widget.observeAttention
                ? Consumer(
                    builder: (context, ref, child) => buildBottomBarContent(
                      ref.watch(appAttentionSummaryProvider),
                    ),
                  )
                : buildBottomBarContent(null),
          );

    return PopScope(
      canPop: canPop || widget.location == '/home',
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && widget.location != '/home') {
          context.go('/home');
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        extendBody: showBottomBar,
        body: NotificationListener<ShellBottomBarVisibilityNotification>(
          onNotification: _handleBottomBarVisibilityNotification,
          child: Column(
            children: [
              SizedBox(height: math.max(AppShell.topMinHeight, topInset)),
              Expanded(child: widget.child),
            ],
          ),
        ),
        bottomNavigationBar: bottomNavigationBar,
      ),
    );
  }

  bool _handleBottomBarVisibilityNotification(
    ShellBottomBarVisibilityNotification notification,
  ) {
    if (_isBottomBarRequestedHidden == notification.isHidden) {
      return true;
    }
    setState(() {
      _isBottomBarRequestedHidden = notification.isHidden;
    });
    return true;
  }

  void _openBranch(BuildContext context, int index, String location) {
    final shell = widget.navigationShell;
    if (shell == null) {
      context.go(location);
      return;
    }

    shell.goBranch(index, initialLocation: shell.currentIndex == index);
  }
}
