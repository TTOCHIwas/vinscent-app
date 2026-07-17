import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

enum _ShellRootBackAction { confirmExit, returnHome }

class ShellRootBackScope extends StatefulWidget {
  const ShellRootBackScope.home({super.key, required this.child})
    : _action = _ShellRootBackAction.confirmExit;

  const ShellRootBackScope.secondaryTab({super.key, required this.child})
    : _action = _ShellRootBackAction.returnHome;

  static const exitConfirmationMessage = '종료하려면 다시 누르세요.';
  static const exitConfirmationWindow = Duration(seconds: 2);

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
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(ShellRootBackScope.exitConfirmationMessage),
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
