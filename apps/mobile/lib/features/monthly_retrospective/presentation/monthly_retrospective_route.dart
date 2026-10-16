import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shell/application/shell_navigation_guard.dart';
import 'monthly_retrospective_screen.dart';

class MonthlyRetrospectiveRoute extends ConsumerStatefulWidget {
  const MonthlyRetrospectiveRoute({super.key});

  @override
  ConsumerState<MonthlyRetrospectiveRoute> createState() =>
      _MonthlyRetrospectiveRouteState();
}

class _MonthlyRetrospectiveRouteState
    extends ConsumerState<MonthlyRetrospectiveRoute> {
  final _screenKey = GlobalKey<MonthlyRetrospectiveScreenState>();
  late final ShellNavigationGuard _guard;
  bool _dirty = false;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _guard = ref.read(shellNavigationGuardProvider);
    _guard.register(
      this,
      '/calendar/monthly',
      () => _screenKey.currentState?.confirmLeave() ?? Future.value(true),
    );
  }

  @override
  void dispose() {
    _guard.unregister(this);
    super.dispose();
  }

  Future<void> _close() async {
    if (_closing) return;
    _closing = true;
    try {
      if (await _guard.allows('/calendar/monthly') && mounted) {
        setState(() => _dirty = false);
        await WidgetsBinding.instance.endOfFrame;
        if (mounted) context.pop();
      }
    } finally {
      _closing = false;
    }
  }

  void _dirtyChanged(bool dirty) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _dirty != dirty) setState(() => _dirty = dirty);
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_dirty,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) _close();
    },
    child: MonthlyRetrospectiveScreen(
      key: _screenKey,
      onBack: _close,
      onDirtyChanged: _dirtyChanged,
      recordLocation: '/calendar/monthly/record',
    ),
  );
}
