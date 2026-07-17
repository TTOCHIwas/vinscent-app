import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';

enum _ShellRootBackAction { confirmExit, returnHome }

class ShellRootBackScope extends StatefulWidget {
  const ShellRootBackScope.home({super.key, required this.child})
    : _action = _ShellRootBackAction.confirmExit;

  const ShellRootBackScope.secondaryTab({super.key, required this.child})
    : _action = _ShellRootBackAction.returnHome;

  static const exitConfirmationMessage = '종료하려면 다시 누르세요.';
  static const exitConfirmationWindow = Duration(seconds: 2);
  static const _exitToastHorizontalPadding = 12.0;
  static const _exitToastTextStyle = TextStyle(
    color: AppColors.textInverse,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 20 / 14,
    letterSpacing: 0,
  );

  final Widget child;
  final _ShellRootBackAction _action;

  @override
  State<ShellRootBackScope> createState() => _ShellRootBackScopeState();
}

class _ShellRootBackScopeState extends State<ShellRootBackScope> {
  Timer? _exitConfirmationTimer;
  bool _exitConfirmationActive = false;

  @override
  void dispose() {
    _exitConfirmationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }

        switch (widget._action) {
          case _ShellRootBackAction.confirmExit:
            _handleExitRequest();
          case _ShellRootBackAction.returnHome:
            context.go('/home');
        }
      },
      child: widget.child,
    );
  }

  void _handleExitRequest() {
    final messenger = ScaffoldMessenger.of(context);
    if (_exitConfirmationActive) {
      _resetExitConfirmation();
      messenger.hideCurrentSnackBar();
      unawaited(SystemNavigator.pop());
      return;
    }

    _exitConfirmationActive = true;
    _exitConfirmationTimer?.cancel();
    _exitConfirmationTimer = Timer(
      ShellRootBackScope.exitConfirmationWindow,
      _resetExitConfirmation,
    );
    final textPainter = TextPainter(
      text: const TextSpan(
        text: ShellRootBackScope.exitConfirmationMessage,
        style: ShellRootBackScope._exitToastTextStyle,
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final textWidth = textPainter.width;
    textPainter.dispose();
    final toastWidth = math.min(
      MediaQuery.sizeOf(context).width - 48.0,
      textWidth + ShellRootBackScope._exitToastHorizontalPadding * 2,
    );
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          width: toastWidth,
          padding: const EdgeInsets.symmetric(
            horizontal: ShellRootBackScope._exitToastHorizontalPadding,
            vertical: 12,
          ),
          backgroundColor: Colors.black,
          elevation: 4,
          shape: const StadiumBorder(),
          content: const Text(
            ShellRootBackScope.exitConfirmationMessage,
            textAlign: TextAlign.center,
            style: ShellRootBackScope._exitToastTextStyle,
          ),
          duration: ShellRootBackScope.exitConfirmationWindow,
        ),
      );
  }

  void _resetExitConfirmation() {
    _exitConfirmationTimer?.cancel();
    _exitConfirmationTimer = null;
    _exitConfirmationActive = false;
  }
}
