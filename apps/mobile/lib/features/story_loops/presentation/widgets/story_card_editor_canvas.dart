import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_typography.dart';
import '../../application/story_card_canvas_renderer.dart';
import '../../application/story_card_editor_session.dart';
import '../../data/story_card_scene.dart';

class StoryCardEditorCanvas extends StatefulWidget {
  const StoryCardEditorCanvas({
    super.key,
    required this.backgroundImage,
    required this.scene,
    required this.visibleStrokes,
    required this.interactionMode,
    required this.onStrokeStart,
    required this.onStrokeUpdate,
    required this.onStrokeEnd,
    required this.onBackgroundScaleStart,
    required this.onBackgroundScaleUpdate,
    required this.onTextLayerScaleStart,
    required this.onTextLayerScaleUpdate,
    required this.onTextLayerScaleEnd,
  });

  final ui.Image? backgroundImage;
  final StoryCardScene scene;
  final List<StoryCardStroke> visibleStrokes;
  final StoryCardEditorTool interactionMode;
  final void Function(StoryCardPoint point, int pointer) onStrokeStart;
  final void Function(StoryCardPoint point, int pointer) onStrokeUpdate;
  final ValueChanged<int> onStrokeEnd;
  final ValueChanged<ScaleStartDetails> onBackgroundScaleStart;
  final void Function(ScaleUpdateDetails details, Size size)
  onBackgroundScaleUpdate;
  final void Function(String layerId, ScaleStartDetails details)
  onTextLayerScaleStart;
  final void Function(String layerId, ScaleUpdateDetails details, Size size)
  onTextLayerScaleUpdate;
  final VoidCallback onTextLayerScaleEnd;

  @override
  State<StoryCardEditorCanvas> createState() => _StoryCardEditorCanvasState();
}

class _StoryCardEditorCanvasState extends State<StoryCardEditorCanvas> {
  final Set<int> _activePointers = {};
  final Map<int, String> _textPointerTargets = {};

  String? _lockedTextLayerId;
  bool _isBackgroundTransformLocked = false;

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
          onPointerDown: (event) {
            _activePointers.add(event.pointer);
          },
          onPointerUp: _releaseCanvasPointer,
          onPointerCancel: _releaseCanvasPointer,
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
                        backgroundImage: widget.backgroundImage,
                        scene: widget.scene,
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
                          onPointerUp: (event) {
                            _textPointerTargets.remove(event.pointer);
                          },
                          onPointerCancel: (event) {
                            _textPointerTargets.remove(event.pointer);
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
                            widget.onStrokeEnd(event.pointer),
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

    if (_isBackgroundTransformLocked) {
      if (details.pointerCount >= 2) {
        widget.onBackgroundScaleStart(details);
      }
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

    if (details.pointerCount >= 2 &&
        widget.interactionMode != StoryCardEditorTool.drawing &&
        widget.backgroundImage != null) {
      _isBackgroundTransformLocked = true;
      widget.onBackgroundScaleStart(details);
    }
  }

  void _handleScaleUpdate(ScaleUpdateDetails details, Size size) {
    final lockedTextLayerId = _lockedTextLayerId;
    if (lockedTextLayerId != null) {
      widget.onTextLayerScaleUpdate(lockedTextLayerId, details, size);
      return;
    }

    if (_isBackgroundTransformLocked && details.pointerCount >= 2) {
      widget.onBackgroundScaleUpdate(details, size);
    }
  }

  void _releaseCanvasPointer(PointerEvent event) {
    _activePointers.remove(event.pointer);
    _textPointerTargets.remove(event.pointer);
    if (_activePointers.isNotEmpty) {
      return;
    }

    _lockedTextLayerId = null;
    _isBackgroundTransformLocked = false;
    _textPointerTargets.clear();
    widget.onTextLayerScaleEnd();
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
    required this.backgroundImage,
    required this.scene,
    required this.strokes,
  });

  final ui.Image? backgroundImage;
  final StoryCardScene scene;
  final List<StoryCardStroke> strokes;

  StoryCardBackgroundTransform get backgroundTransform =>
      scene.backgroundTransform;

  String? get caption => scene.caption;

  @override
  void paint(Canvas canvas, Size size) {
    StoryCardCanvasRenderer.paint(
      canvas: canvas,
      size: size,
      scene: scene,
      backgroundImage: backgroundImage,
      strokes: strokes,
      includeTextLayers: false,
    );
  }

  @override
  bool shouldRepaint(covariant _StoryCardPainter oldDelegate) {
    return oldDelegate.backgroundImage != backgroundImage ||
        oldDelegate.scene != scene ||
        oldDelegate.strokes != strokes;
  }
}
