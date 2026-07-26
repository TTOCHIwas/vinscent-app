import 'package:flutter/material.dart';

enum AppHorizontalPageDirection { previous, next }

class AppHorizontalPageTransition extends StatefulWidget {
  const AppHorizontalPageTransition({
    super.key,
    required this.transitionKey,
    required this.direction,
    required this.child,
    this.duration = const Duration(milliseconds: 180),
    this.curve = const Cubic(0.22, 0.25, 0, 1),
  });

  final Object transitionKey;
  final AppHorizontalPageDirection direction;
  final Widget child;
  final Duration duration;
  final Curve curve;

  @override
  State<AppHorizontalPageTransition> createState() =>
      _AppHorizontalPageTransitionState();
}

class _AppHorizontalPageTransitionState
    extends State<AppHorizontalPageTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Object _currentKey;
  late Widget _currentChild;
  Widget? _outgoingChild;
  Object? _outgoingKey;
  late AppHorizontalPageDirection _direction;

  @override
  void initState() {
    super.initState();
    _currentKey = widget.transitionKey;
    _currentChild = widget.child;
    _direction = widget.direction;
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: 1,
    )..addStatusListener(_handleAnimationStatus);
  }

  @override
  void didUpdateWidget(covariant AppHorizontalPageTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }

    if (widget.transitionKey == _currentKey) {
      _currentChild = widget.child;
      return;
    }

    _outgoingKey = _currentKey;
    _outgoingChild = _currentChild;
    _currentKey = widget.transitionKey;
    _currentChild = widget.child;
    _direction = widget.direction;

    final animationsDisabled =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (animationsDisabled || widget.duration == Duration.zero) {
      _outgoingKey = null;
      _outgoingChild = null;
      _controller.value = 1;
      return;
    }
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller
      ..removeStatusListener(_handleAnimationStatus)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final outgoingChild = _outgoingChild;
    final outgoingKey = _outgoingKey;
    if (outgoingChild == null || outgoingKey == null) {
      return RepaintBoundary(
        child: KeyedSubtree(key: ValueKey(_currentKey), child: _currentChild),
      );
    }

    final incomingDirection = _direction == AppHorizontalPageDirection.next
        ? 1.0
        : -1.0;
    final curvedAnimation = _controller.drive(CurveTween(curve: widget.curve));
    final outgoingAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset(-incomingDirection, 0),
    ).animate(curvedAnimation);
    final incomingAnimation = Tween<Offset>(
      begin: Offset(incomingDirection, 0),
      end: Offset.zero,
    ).animate(curvedAnimation);

    return ClipRect(
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          Positioned.fill(
            child: ExcludeSemantics(
              child: IgnorePointer(
                child: SlideTransition(
                  position: outgoingAnimation,
                  child: RepaintBoundary(
                    child: KeyedSubtree(
                      key: ValueKey(outgoingKey),
                      child: outgoingChild,
                    ),
                  ),
                ),
              ),
            ),
          ),
          IgnorePointer(
            child: SlideTransition(
              position: incomingAnimation,
              child: RepaintBoundary(
                child: KeyedSubtree(
                  key: ValueKey(_currentKey),
                  child: _currentChild,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleAnimationStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || _outgoingChild == null) {
      return;
    }
    setState(() {
      _outgoingKey = null;
      _outgoingChild = null;
    });
  }
}
