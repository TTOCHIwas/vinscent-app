import 'package:flutter/material.dart';

import 'app_loading_indicator.dart';

class AppMediaLoadingGroup extends StatefulWidget {
  const AppMediaLoadingGroup({
    super.key,
    required this.child,
    this.indicatorPadding = EdgeInsets.zero,
  });

  final Widget child;
  final EdgeInsets indicatorPadding;

  static AppMediaLoadingTracker? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_LoadingScope>()?.tracker;

  @override
  State<AppMediaLoadingGroup> createState() => _AppMediaLoadingGroupState();
}

class _AppMediaLoadingGroupState extends State<AppMediaLoadingGroup> {
  final _tracker = AppMediaLoadingTracker();

  @override
  void initState() {
    super.initState();
    _tracker.settleAfterFrame();
  }

  @override
  void dispose() {
    _tracker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      _LoadingScope(tracker: _tracker, child: widget.child),
      Positioned.fill(
        child: IgnorePointer(
          child: Padding(
            padding: widget.indicatorPadding,
            child: AnimatedBuilder(
              animation: _tracker,
              builder: (context, _) => _tracker.isLoading
                  ? const Center(
                      child: SizedBox.square(
                        dimension: 18,
                        child: AppLoadingIndicator(radius: 8),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    ],
  );
}

class AppMediaLoadingTracker extends ChangeNotifier {
  final _pending = <Object>{};
  var _notificationScheduled = false;
  var _disposed = false;

  var _loading = false;
  bool get isLoading => _loading;
  var _canReveal = false;
  bool get canReveal => _canReveal;

  void update(Object owner, {required bool loading}) {
    if (_disposed) return;
    final changed = loading ? _pending.add(owner) : _pending.remove(owner);
    if (!changed) return;
    settleAfterFrame();
  }

  void settleAfterFrame() {
    if (_disposed || _notificationScheduled) return;
    _notificationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notificationScheduled = false;
      if (!_disposed) {
        _loading = _pending.isNotEmpty;
        _canReveal = !_loading;
        notifyListeners();
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    _disposed = true;
    _pending.clear();
    super.dispose();
  }
}

class _LoadingScope extends InheritedWidget {
  const _LoadingScope({required this.tracker, required super.child});
  final AppMediaLoadingTracker tracker;

  @override
  bool updateShouldNotify(_LoadingScope oldWidget) =>
      tracker != oldWidget.tracker;
}
