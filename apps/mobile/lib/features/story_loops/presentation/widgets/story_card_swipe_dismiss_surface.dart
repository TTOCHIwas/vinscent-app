import 'package:flutter/material.dart';

class StoryCardSwipeDismissSurface extends StatefulWidget {
  const StoryCardSwipeDismissSurface({
    super.key,
    required this.onDismissed,
    required this.child,
  });

  final VoidCallback onDismissed;
  final Widget child;

  @override
  State<StoryCardSwipeDismissSurface> createState() =>
      _StoryCardSwipeDismissSurfaceState();
}

class _StoryCardSwipeDismissSurfaceState
    extends State<StoryCardSwipeDismissSurface>
    with SingleTickerProviderStateMixin {
  static const _dismissDistanceRatio = 0.2;
  static const _minimumFlingDistance = 48.0;
  static const _dismissVelocity = 1000.0;
  static const _animationDuration = Duration(milliseconds: 220);

  late final AnimationController _progressController;
  var _viewportHeight = 1.0;
  var _dragExtent = 0.0;
  var _isDismissing = false;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: _animationDuration,
      reverseDuration: _animationDuration,
    );
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _viewportHeight = constraints.maxHeight;
        return AnimatedBuilder(
          animation: _progressController,
          child: widget.child,
          builder: (context, child) {
            final progress = _progressController.value;
            final easedProgress = Curves.easeOut.transform(progress);
            final scale = 1 - (0.04 * easedProgress);
            final cornerRadius = 18 * easedProgress;

            return Stack(
              fit: StackFit.expand,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  excludeFromSemantics: true,
                  onTap: _isDismissing ? null : widget.onDismissed,
                  child: IgnorePointer(
                    child: ColoredBox(
                      color: Colors.black.withValues(
                        alpha: 0.55 * (1 - progress),
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  excludeFromSemantics: true,
                  onVerticalDragStart: _handleDragStart,
                  onVerticalDragUpdate: _handleDragUpdate,
                  onVerticalDragEnd: _handleDragEnd,
                  onVerticalDragCancel: _restore,
                  child: Transform.translate(
                    key: const Key('story-card-stack-dismiss-translation'),
                    offset: Offset(0, progress * _viewportHeight),
                    child: Transform.scale(
                      scale: scale,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(cornerRadius),
                        child: child,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _handleDragStart(DragStartDetails details) {
    if (_isDismissing) {
      return;
    }
    _progressController.stop();
    _dragExtent = _progressController.value * _viewportHeight;
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (_isDismissing) {
      return;
    }
    _dragExtent = (_dragExtent + (details.primaryDelta ?? 0)).clamp(
      0.0,
      _viewportHeight,
    );
    _progressController.value = _dragExtent / _viewportHeight;
  }

  void _handleDragEnd(DragEndDetails details) {
    if (_isDismissing) {
      return;
    }
    final velocity = details.primaryVelocity ?? 0;
    final passedDistanceThreshold =
        _dragExtent >= _viewportHeight * _dismissDistanceRatio;
    final passedFlingThreshold =
        _dragExtent >= _minimumFlingDistance && velocity >= _dismissVelocity;
    if (passedDistanceThreshold || passedFlingThreshold) {
      _dismiss();
      return;
    }
    _restore();
  }

  void _restore() {
    if (_isDismissing) {
      return;
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      _progressController.value = 0;
      _dragExtent = 0;
      return;
    }
    _progressController.animateBack(0, curve: Curves.easeOutCubic);
    _dragExtent = 0;
  }

  Future<void> _dismiss() async {
    _isDismissing = true;
    if (!MediaQuery.disableAnimationsOf(context)) {
      try {
        await _progressController
            .animateTo(1, curve: Curves.easeOutCubic)
            .orCancel;
      } on TickerCanceled {
        return;
      }
    }
    if (mounted) {
      widget.onDismissed();
    }
  }
}
