import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_typography.dart';
import '../../application/story_card_canvas_renderer.dart';
import '../../application/story_card_editor_session.dart';
import '../../data/story_card_film_look.dart';
import '../../data/story_card_scene.dart';
import '../../data/story_card_type.dart';
import 'story_card_interactive_viewport.dart';

class StoryCardEditorCanvas extends StatefulWidget {
  const StoryCardEditorCanvas({
    super.key,
    required this.backgroundImages,
    required this.scene,
    this.filmProgram,
    required this.visibleStrokes,
    required this.interactionMode,
    required this.onStrokeStart,
    required this.onStrokeUpdate,
    required this.onStrokeEnd,
    required this.onStrokeCancel,
    required this.onPhotoTapped,
    required this.onPhotosReordered,
    required this.onCardTypeStep,
    this.onCanvasTapped,
    required this.onTextLayerScaleStart,
    required this.onTextLayerScaleUpdate,
    required this.onTextLayerScaleEnd,
    required this.viewportGestures,
  });

  final List<ui.Image?> backgroundImages;
  final StoryCardScene scene;
  final ui.FragmentProgram? filmProgram;
  final List<StoryCardStroke> visibleStrokes;
  final StoryCardEditorTool interactionMode;
  final void Function(StoryCardPoint point, int pointer) onStrokeStart;
  final void Function(StoryCardPoint point, int pointer) onStrokeUpdate;
  final ValueChanged<int> onStrokeEnd;
  final ValueChanged<int> onStrokeCancel;
  final ValueChanged<int> onPhotoTapped;
  final void Function(int fromIndex, int toIndex) onPhotosReordered;
  final ValueChanged<int> onCardTypeStep;
  final bool Function()? onCanvasTapped;
  final void Function(String layerId, ScaleStartDetails details)
  onTextLayerScaleStart;
  final void Function(String layerId, ScaleUpdateDetails details, Size size)
  onTextLayerScaleUpdate;
  final VoidCallback onTextLayerScaleEnd;
  final StoryCardViewportGestures viewportGestures;

  @override
  State<StoryCardEditorCanvas> createState() => _StoryCardEditorCanvasState();
}

class _StoryCardEditorCanvasState extends State<StoryCardEditorCanvas> {
  final Set<int> _activePointers = {};
  final Map<int, String> _textPointerTargets = {};
  final Map<int, Offset> _pointerOrigins = {};
  final Map<int, Offset> _pointerPositions = {};
  final Map<int, int> _photoPointerTargets = {};

  String? _lockedTextLayerId;
  Timer? _photoLongPressTimer;
  int? _longPressPointer;
  int? _longPressPhotoIndex;
  bool _longPressActivated = false;
  bool _gestureHadMultiplePointers = false;
  bool _gestureUsedViewport = false;

  @override
  void dispose() {
    _photoLongPressTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant StoryCardEditorCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    final layerIds = widget.scene.textLayers.map((layer) => layer.id).toSet();
    _textPointerTargets.removeWhere(
      (pointer, layerId) => !layerIds.contains(layerId),
    );
    if (!layerIds.contains(_lockedTextLayerId)) {
      _lockedTextLayerId = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (event) => _handleCanvasPointerDown(event, size),
          onPointerMove: _handleCanvasPointerMove,
          onPointerUp: (event) => _releaseCanvasPointer(event, size),
          onPointerCancel: (event) => _cancelCanvasPointer(event.pointer),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onScaleStart: _handleScaleStart,
            onScaleUpdate: (details) => _handleScaleUpdate(details, size),
            child: ClipRect(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _StoryCardPainter(
                        backgroundImages: widget.backgroundImages,
                        scene: widget.scene,
                        filmProgram: widget.filmProgram,
                        strokes: widget.visibleStrokes,
                      ),
                    ),
                  ),
                  for (final layer in widget.scene.textLayers)
                    Positioned(
                      left: layer.x * size.width,
                      top: layer.y * size.height,
                      child: FractionalTranslation(
                        translation: const Offset(-0.5, -0.5),
                        child: Listener(
                          onPointerDown: (event) {
                            _textPointerTargets.putIfAbsent(
                              event.pointer,
                              () => layer.id,
                            );
                          },
                          child: Transform.rotate(
                            key: ValueKey(
                              'story-card-text-transform-${layer.id}',
                            ),
                            angle: layer.rotation,
                            child: Transform.scale(
                              key: ValueKey(
                                'story-card-text-scale-${layer.id}',
                              ),
                              scale: layer.scale,
                              child: SizedBox(
                                width: size.width * .72,
                                child: Text(
                                  layer.text,
                                  textAlign: TextAlign.center,
                                  style: AppTypography.applyToStyle(
                                    AppTextStyles.homeBodyMedium.copyWith(
                                      color: layer.color,
                                      fontSize:
                                          size.width *
                                          storyCardTextFontSizeRatio,
                                      shadows: const [],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (widget.interactionMode == StoryCardEditorTool.drawing)
                    Positioned.fill(
                      child: Listener(
                        behavior: HitTestBehavior.opaque,
                        onPointerDown: (event) => widget.onStrokeStart(
                          _normalize(event.localPosition, size),
                          event.pointer,
                        ),
                        onPointerMove: (event) => widget.onStrokeUpdate(
                          _normalize(event.localPosition, size),
                          event.pointer,
                        ),
                        onPointerUp: (event) =>
                            widget.onStrokeEnd(event.pointer),
                        onPointerCancel: (event) =>
                            widget.onStrokeCancel(event.pointer),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleScaleStart(ScaleStartDetails details) {
    final lockedTextLayerId = _lockedTextLayerId;
    if (lockedTextLayerId != null) {
      widget.onTextLayerScaleStart(lockedTextLayerId, details);
      return;
    }

    final textLayerId = _textPointerTargets.isEmpty
        ? null
        : _textPointerTargets.values.first;
    if (textLayerId != null) {
      _lockedTextLayerId = textLayerId;
      widget.onTextLayerScaleStart(textLayerId, details);
      return;
    }

    if (details.pointerCount >= 2 || widget.viewportGestures.isZoomed()) {
      _gestureUsedViewport = true;
      widget.viewportGestures.begin(details.focalPoint);
    }
  }

  void _handleScaleUpdate(ScaleUpdateDetails details, Size size) {
    final lockedTextLayerId = _lockedTextLayerId;
    if (lockedTextLayerId != null) {
      widget.onTextLayerScaleUpdate(lockedTextLayerId, details, size);
      return;
    }
    if (!_gestureUsedViewport &&
        (details.pointerCount >= 2 || widget.viewportGestures.isZoomed())) {
      _gestureUsedViewport = true;
      widget.viewportGestures.begin(details.focalPoint);
    }
    if (_gestureUsedViewport) {
      widget.viewportGestures.update(details.focalPoint, details.scale);
    }
  }

  void _handleCanvasPointerDown(PointerDownEvent event, Size size) {
    _activePointers.add(event.pointer);
    _pointerOrigins[event.pointer] = event.localPosition;
    _pointerPositions[event.pointer] = event.localPosition;
    if (_activePointers.length > 1) {
      _gestureHadMultiplePointers = true;
      _cancelPhotoLongPress();
      if (widget.interactionMode == StoryCardEditorTool.drawing) {
        for (final pointer in _activePointers) {
          widget.onStrokeCancel(pointer);
        }
      }
    }

    if (widget.interactionMode == StoryCardEditorTool.drawing) {
      return;
    }

    scheduleMicrotask(() {
      if (!mounted ||
          !_activePointers.contains(event.pointer) ||
          _textPointerTargets.containsKey(event.pointer)) {
        return;
      }
      final photoIndex = _photoIndexAt(event.localPosition, size);
      if (photoIndex < 0) {
        return;
      }
      _photoPointerTargets[event.pointer] = photoIndex;
      if (widget.scene.cardType.isFourCut &&
          _hasPhoto(photoIndex) &&
          _activePointers.length == 1) {
        _longPressPointer = event.pointer;
        _longPressPhotoIndex = photoIndex;
        _photoLongPressTimer = Timer(const Duration(milliseconds: 450), () {
          if (!mounted ||
              !_activePointers.contains(event.pointer) ||
              _gestureHadMultiplePointers) {
            return;
          }
          _longPressActivated = true;
          unawaited(HapticFeedback.selectionClick());
        });
      }
    });
  }

  void _handleCanvasPointerMove(PointerMoveEvent event) {
    _pointerPositions[event.pointer] = event.localPosition;
    final origin = _pointerOrigins[event.pointer];
    if (origin == null) {
      return;
    }
    if (!_longPressActivated && (event.localPosition - origin).distance > 12) {
      _cancelPhotoLongPress();
    }
  }

  void _releaseCanvasPointer(PointerUpEvent event, Size size) {
    final origin = _pointerOrigins[event.pointer];
    final current = _pointerPositions[event.pointer] ?? event.localPosition;
    final startedOnText = _textPointerTargets.containsKey(event.pointer);
    final photoIndex = _photoPointerTargets[event.pointer];
    final wasLongPress =
        _longPressActivated &&
        _longPressPointer == event.pointer &&
        _longPressPhotoIndex != null;

    if (!startedOnText &&
        !_gestureHadMultiplePointers &&
        !_gestureUsedViewport &&
        origin != null) {
      final displacement = current - origin;
      if (wasLongPress) {
        final targetIndex = _photoIndexAt(current, size);
        final sourceIndex = _longPressPhotoIndex!;
        if (targetIndex >= 0 && targetIndex != sourceIndex) {
          widget.onPhotosReordered(sourceIndex, targetIndex);
        }
      } else if (displacement.dx.abs() >= 60 &&
          displacement.dx.abs() > displacement.dy.abs() * 1.35) {
        widget.onCardTypeStep(displacement.dx < 0 ? 1 : -1);
      } else if (displacement.distance <= 16) {
        final wasConsumed = widget.onCanvasTapped?.call() ?? false;
        if (!wasConsumed && photoIndex != null) {
          widget.onPhotoTapped(photoIndex);
        }
      }
    }

    _clearPointer(event.pointer);
    _activePointers.remove(event.pointer);
    if (_activePointers.isNotEmpty) {
      return;
    }

    _lockedTextLayerId = null;
    _textPointerTargets.clear();
    _gestureHadMultiplePointers = false;
    if (_gestureUsedViewport) {
      widget.viewportGestures.end();
      _gestureUsedViewport = false;
    }
    _cancelPhotoLongPress();
    widget.onTextLayerScaleEnd();
  }

  void _cancelCanvasPointer(int pointer) {
    _clearPointer(pointer);
    _activePointers.remove(pointer);
    if (_activePointers.isNotEmpty) {
      return;
    }
    _lockedTextLayerId = null;
    _textPointerTargets.clear();
    _gestureHadMultiplePointers = false;
    if (_gestureUsedViewport) {
      widget.viewportGestures.end();
      _gestureUsedViewport = false;
    }
    _cancelPhotoLongPress();
    widget.onTextLayerScaleEnd();
  }

  void _clearPointer(int pointer) {
    _pointerOrigins.remove(pointer);
    _pointerPositions.remove(pointer);
    _photoPointerTargets.remove(pointer);
    _textPointerTargets.remove(pointer);
  }

  void _cancelPhotoLongPress() {
    _photoLongPressTimer?.cancel();
    _photoLongPressTimer = null;
    _longPressPointer = null;
    _longPressPhotoIndex = null;
    _longPressActivated = false;
  }

  int _photoIndexAt(Offset position, Size size) {
    if (size.isEmpty) {
      return -1;
    }
    final layout = StoryCardLayout.fromSize(
      type: widget.scene.cardType,
      size: size,
    );
    return layout.photoRects.indexWhere((rect) => rect.contains(position));
  }

  bool _hasPhoto(int index) {
    return index >= 0 &&
        index < widget.backgroundImages.length &&
        widget.backgroundImages[index] != null;
  }

  StoryCardPoint _normalize(Offset position, Size size) {
    return StoryCardPoint(
      x: (position.dx / size.width).clamp(0.0, 1.0),
      y: (position.dy / size.height).clamp(0.0, 1.0),
    );
  }
}

class _StoryCardPainter extends CustomPainter {
  const _StoryCardPainter({
    required this.backgroundImages,
    required this.scene,
    required this.filmProgram,
    required this.strokes,
  });

  final List<ui.Image?> backgroundImages;

  ui.Image? get backgroundImage => backgroundImages.firstOrNull;
  final StoryCardScene scene;
  final ui.FragmentProgram? filmProgram;
  final List<StoryCardStroke> strokes;

  StoryCardBackgroundTransform get backgroundTransform =>
      scene.backgroundTransform;

  String? get caption => scene.caption;

  StoryCardFilmState get film => scene.film;

  @override
  void paint(Canvas canvas, Size size) {
    StoryCardCanvasRenderer.paint(
      canvas: canvas,
      size: size,
      scene: scene,
      backgroundImages: backgroundImages,
      filmProgram: filmProgram,
      strokes: strokes,
      includeTextLayers: false,
    );
  }

  @override
  bool shouldRepaint(covariant _StoryCardPainter oldDelegate) {
    return oldDelegate.backgroundImages != backgroundImages ||
        oldDelegate.scene != scene ||
        oldDelegate.filmProgram != filmProgram ||
        oldDelegate.strokes != strokes;
  }
}
