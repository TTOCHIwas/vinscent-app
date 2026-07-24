import 'package:flutter/material.dart';

class AppHorizontalSwipeRegion extends StatefulWidget {
  const AppHorizontalSwipeRegion({
    super.key,
    required this.child,
    this.onSwipeRight,
    this.onSwipeLeft,
    this.minimumDistance = 72,
    this.behavior = HitTestBehavior.opaque,
  }) : assert(minimumDistance > 0);

  final Widget child;
  final VoidCallback? onSwipeRight;
  final VoidCallback? onSwipeLeft;
  final double minimumDistance;
  final HitTestBehavior behavior;

  @override
  State<AppHorizontalSwipeRegion> createState() =>
      _AppHorizontalSwipeRegionState();
}

class _AppHorizontalSwipeRegionState extends State<AppHorizontalSwipeRegion> {
  double _dragDistance = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: widget.behavior,
      onHorizontalDragStart: (_) => _dragDistance = 0,
      onHorizontalDragUpdate: (details) {
        _dragDistance += details.primaryDelta ?? 0;
      },
      onHorizontalDragEnd: (_) => _finishDrag(),
      onHorizontalDragCancel: _resetDrag,
      child: widget.child,
    );
  }

  void _finishDrag() {
    final dragDistance = _dragDistance;
    _resetDrag();
    if (dragDistance.abs() < widget.minimumDistance) {
      return;
    }

    if (dragDistance > 0) {
      widget.onSwipeRight?.call();
      return;
    }

    widget.onSwipeLeft?.call();
  }

  void _resetDrag() {
    _dragDistance = 0;
  }
}
