import 'dart:math' as math;

import 'package:flutter/material.dart';

const storyCardEditorViewportInsets = EdgeInsets.only(top: 68, bottom: 72);

class StoryCardViewportController extends ChangeNotifier {
  StoryCardViewportController({this.maxScale = 4});

  static const _minimumScale = 1.0;
  static const _scaleEpsilon = 0.001;

  final double maxScale;

  Size _viewportSize = Size.zero;
  Size _contentSize = Size.zero;
  double _scale = _minimumScale;
  Offset _translation = Offset.zero;
  double _gestureStartScale = _minimumScale;
  Offset _gestureStartTranslation = Offset.zero;
  Offset _gestureStartFocalPoint = Offset.zero;

  double get scale => _scale;
  Offset get translation => _translation;
  bool get isZoomed => _scale > _minimumScale + _scaleEpsilon;

  void configure({required Size viewportSize, required Size contentSize}) {
    _viewportSize = viewportSize;
    _contentSize = contentSize;
    _translation = _clampTranslation(_translation, _scale);
  }

  void beginGesture(Offset focalPoint) {
    _gestureStartScale = _scale;
    _gestureStartTranslation = _translation;
    _gestureStartFocalPoint = focalPoint;
  }

  void updateGesture({required Offset focalPoint, required double scale}) {
    if (_viewportSize.isEmpty || _contentSize.isEmpty) {
      return;
    }
    final nextScale = (_gestureStartScale * scale).clamp(
      _minimumScale,
      maxScale,
    );
    if (nextScale <= _minimumScale + _scaleEpsilon) {
      _setTransform(scale: _minimumScale, translation: Offset.zero);
      return;
    }

    final viewportCenter = _viewportSize.center(Offset.zero);
    final contentPoint =
        (_gestureStartFocalPoint - viewportCenter - _gestureStartTranslation) /
        _gestureStartScale;
    final nextTranslation =
        focalPoint - viewportCenter - contentPoint * nextScale;
    _setTransform(
      scale: nextScale,
      translation: _clampTranslation(nextTranslation, nextScale),
    );
  }

  void endGesture() {
    if (!isZoomed) {
      reset();
      return;
    }
    final clamped = _clampTranslation(_translation, _scale);
    if (clamped != _translation) {
      _translation = clamped;
      notifyListeners();
    }
  }

  void reset() {
    _setTransform(scale: _minimumScale, translation: Offset.zero);
  }

  Offset _clampTranslation(Offset value, double scale) {
    final horizontalExtent = math.max(
      0.0,
      (_contentSize.width * scale - _viewportSize.width) / 2,
    );
    final verticalExtent = math.max(
      0.0,
      (_contentSize.height * scale - _viewportSize.height) / 2,
    );
    return Offset(
      value.dx.clamp(-horizontalExtent, horizontalExtent),
      value.dy.clamp(-verticalExtent, verticalExtent),
    );
  }

  void _setTransform({required double scale, required Offset translation}) {
    if (_scale == scale && _translation == translation) {
      return;
    }
    _scale = scale;
    _translation = translation;
    notifyListeners();
  }
}

class StoryCardViewportGestures {
  const StoryCardViewportGestures({
    required this.isZoomed,
    required this.begin,
    required this.update,
    required this.end,
  });

  final bool Function() isZoomed;
  final ValueChanged<Offset> begin;
  final void Function(Offset focalPoint, double scale) update;
  final VoidCallback end;
}

typedef StoryCardViewportBuilder =
    Widget Function(
      BuildContext context,
      Size contentSize,
      StoryCardViewportGestures gestures,
    );

class StoryCardInteractiveViewport extends StatefulWidget {
  const StoryCardInteractiveViewport({
    super.key,
    required this.controller,
    required this.aspectRatio,
    required this.builder,
    this.clipContent = true,
  });

  final StoryCardViewportController controller;
  final double aspectRatio;
  final StoryCardViewportBuilder builder;
  final bool clipContent;

  @override
  State<StoryCardInteractiveViewport> createState() =>
      _StoryCardInteractiveViewportState();
}

class _StoryCardInteractiveViewportState
    extends State<StoryCardInteractiveViewport> {
  final _viewportKey = GlobalKey();
  late StoryCardViewportGestures _gestures;

  @override
  void initState() {
    super.initState();
    _gestures = StoryCardViewportGestures(
      isZoomed: () => widget.controller.isZoomed,
      begin: _beginGesture,
      update: _updateGesture,
      end: widget.controller.endGesture,
    );
  }

  @override
  void didUpdateWidget(covariant StoryCardInteractiveViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _gestures = StoryCardViewportGestures(
        isZoomed: () => widget.controller.isZoomed,
        begin: _beginGesture,
        update: _updateGesture,
        end: widget.controller.endGesture,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportSize = constraints.biggest;
        final contentSize = applyBoxFit(
          BoxFit.contain,
          Size(widget.aspectRatio, 1),
          viewportSize,
        ).destination;
        widget.controller.configure(
          viewportSize: viewportSize,
          contentSize: contentSize,
        );
        final card = SizedBox.fromSize(
          size: contentSize,
          child: widget.builder(context, contentSize, _gestures),
        );

        final transformedCard = AnimatedBuilder(
          animation: widget.controller,
          child: card,
          builder: (context, child) => Center(
            child: Transform.translate(
              key: const ValueKey('story-card-viewport-translation'),
              offset: widget.controller.translation,
              child: Transform.scale(
                key: const ValueKey('story-card-viewport-scale'),
                scale: widget.controller.scale,
                alignment: Alignment.center,
                child: child,
              ),
            ),
          ),
        );

        return SizedBox.expand(
          key: _viewportKey,
          child: widget.clipContent
              ? ClipRect(child: transformedCard)
              : transformedCard,
        );
      },
    );
  }

  void _beginGesture(Offset globalFocalPoint) {
    widget.controller.beginGesture(_toLocal(globalFocalPoint));
  }

  void _updateGesture(Offset globalFocalPoint, double scale) {
    widget.controller.updateGesture(
      focalPoint: _toLocal(globalFocalPoint),
      scale: scale,
    );
  }

  Offset _toLocal(Offset globalPoint) {
    final renderObject =
        _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    return renderObject?.globalToLocal(globalPoint) ?? globalPoint;
  }
}

class StoryCardViewportGestureRegion extends StatefulWidget {
  const StoryCardViewportGestureRegion({
    super.key,
    required this.gestures,
    required this.child,
    this.onInteractionChanged,
  });

  final StoryCardViewportGestures gestures;
  final Widget child;
  final ValueChanged<bool>? onInteractionChanged;

  @override
  State<StoryCardViewportGestureRegion> createState() =>
      _StoryCardViewportGestureRegionState();
}

class _StoryCardViewportGestureRegionState
    extends State<StoryCardViewportGestureRegion> {
  final Map<int, Offset> _pointers = {};
  var _isInteracting = false;
  var _startDistance = 1.0;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: (event) => _releasePointer(event.pointer),
      onPointerCancel: (event) => _releasePointer(event.pointer),
      child: widget.child,
    );
  }

  void _handlePointerDown(PointerDownEvent event) {
    _pointers[event.pointer] = event.position;
    if (_pointers.length >= 2) {
      _restartGesture();
      return;
    }
    if (widget.gestures.isZoomed()) {
      _beginInteraction(event.position);
    }
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (!_pointers.containsKey(event.pointer)) {
      return;
    }
    _pointers[event.pointer] = event.position;
    if (_pointers.length >= 2) {
      if (!_isInteracting) {
        _restartGesture();
      }
      final points = _pointers.values.take(2).toList(growable: false);
      final distance = (points[0] - points[1]).distance;
      widget.gestures.update(
        _midpoint(points[0], points[1]),
        distance / _startDistance,
      );
      return;
    }
    if (_isInteracting && widget.gestures.isZoomed()) {
      widget.gestures.update(_pointers.values.single, 1);
    }
  }

  void _releasePointer(int pointer) {
    _pointers.remove(pointer);
    if (_pointers.length >= 2) {
      _restartGesture();
      return;
    }
    _endInteraction();
    if (_pointers.length == 1 && widget.gestures.isZoomed()) {
      _beginInteraction(_pointers.values.single);
    }
  }

  void _restartGesture() {
    if (_isInteracting) {
      widget.gestures.end();
    }
    final points = _pointers.values.take(2).toList(growable: false);
    _startDistance = math.max((points[0] - points[1]).distance, 1);
    _beginInteraction(_midpoint(points[0], points[1]));
  }

  void _beginInteraction(Offset focalPoint) {
    if (!_isInteracting) {
      _isInteracting = true;
      widget.onInteractionChanged?.call(true);
    }
    widget.gestures.begin(focalPoint);
  }

  void _endInteraction() {
    if (!_isInteracting) {
      return;
    }
    widget.gestures.end();
    _isInteracting = false;
    widget.onInteractionChanged?.call(false);
  }

  Offset _midpoint(Offset first, Offset second) => (first + second) / 2;
}
