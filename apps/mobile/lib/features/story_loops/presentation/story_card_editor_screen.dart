import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as image;
import 'package:uuid/uuid.dart';

import '../../../core/presentation/widgets/app_back_button.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../application/story_card_editor_controller.dart';
import '../data/story_card_draft.dart';
import '../data/story_card_editor_session.dart';
import '../data/story_card_scene.dart';
import '../data/story_loop_write_failure.dart';
import 'widgets/story_card_camera_stage.dart';

class StoryCardEditorScreen extends ConsumerWidget {
  const StoryCardEditorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draftAsync = ref.watch(storyCardEditorControllerProvider);

    return draftAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (error, stackTrace) => _StoryCardEditorError(
        onRetry: () => ref.invalidate(storyCardEditorControllerProvider),
      ),
      data: (draft) => _StoryCardEditorContent(
        key: ValueKey(draft.existingRevision),
        initialDraft: draft,
      ),
    );
  }
}

class _StoryCardEditorContent extends ConsumerStatefulWidget {
  const _StoryCardEditorContent({super.key, required this.initialDraft});

  final StoryCardDraft initialDraft;

  @override
  ConsumerState<_StoryCardEditorContent> createState() =>
      _StoryCardEditorContentState();
}

class _StoryCardEditorContentState
    extends ConsumerState<_StoryCardEditorContent> {
  final _previewKey = GlobalKey();

  late StoryCardEditorSession _session;
  ui.Image? _backgroundImage;
  StoryCardStroke? _activeStroke;
  Color _selectedColor = storyCardColorPalette.first;
  double _selectedStrokeWidth = storyCardNormalStrokeWidth;
  int? _activePointer;
  double _backgroundScaleStart = 1;
  Offset _backgroundOffsetStart = Offset.zero;
  Offset _backgroundFocalPointStart = Offset.zero;
  bool _isSaving = false;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _session = StoryCardEditorSession.fromDraft(widget.initialDraft);
    _loadBackgroundImage(_draft.backgroundImageBytes);
  }

  @override
  void dispose() {
    _backgroundImage?.dispose();
    super.dispose();
  }

  StoryCardDraft get _draft => _session.draft;

  List<StoryCardStroke> get _visibleStrokes {
    return [..._draft.scene.strokes, ?_activeStroke];
  }

  bool get _canSave => !_isSaving && !_isDeleting && _draft.hasContent;

  @override
  Widget build(BuildContext context) {
    if (_session.stage == StoryCardEditorStage.camera) {
      return StoryCardCameraStage(
        onBack: () => context.go('/home'),
        onImageSelected: _useBackgroundImage,
        onTextSelected: () => _enterBlankDecorator(StoryCardEditorTool.text),
        onDrawingSelected: () =>
            _enterBlankDecorator(StoryCardEditorTool.drawing),
      );
    }

    return Column(
      children: [
        _EditorHeader(
          canSave: _canSave,
          isSaving: _isSaving,
          canDelete:
              _draft.existingRevision != null && !_isSaving && !_isDeleting,
          onBackPressed: () => context.go('/home'),
          onDeletePressed: _deleteCard,
          onSavePressed: _saveCard,
        ),
        Expanded(
          child: SingleChildScrollView(
            physics: _activePointer == null
                ? null
                : const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
            child: Column(
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: RepaintBoundary(
                    key: _previewKey,
                    child: _StoryCardCanvas(
                      backgroundImage: _backgroundImage,
                      scene: _draft.scene,
                      visibleStrokes: _visibleStrokes,
                      interactionMode: _session.tool,
                      onStrokeStart: _startStroke,
                      onStrokeUpdate: _updateStroke,
                      onStrokeEnd: _endStroke,
                      onBackgroundScaleStart: _startBackgroundTransform,
                      onBackgroundScaleUpdate: _updateBackgroundTransform,
                      onTextLayerMoved: _moveTextLayer,
                      onTextLayerTapped: _editTextLayer,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _StoryCardActionBar(
                  interactionMode: _session.tool,
                  hasBackground: _draft.hasPhoto,
                  onAddTextPressed: _addTextLayer,
                  onDrawingModePressed: () {
                    setState(() {
                      _session = _session.selectTool(
                        StoryCardEditorTool.drawing,
                      );
                    });
                  },
                  onBackgroundModePressed: _draft.hasPhoto
                      ? () {
                          setState(() {
                            _session = _session.selectTool(
                              StoryCardEditorTool.background,
                            );
                          });
                        }
                      : null,
                ),
                const SizedBox(height: 20),
                _StoryCardDrawingControls(
                  selectedColor: _selectedColor,
                  selectedStrokeWidth: _selectedStrokeWidth,
                  onColorChanged: (color) {
                    setState(() {
                      _selectedColor = color;
                      _session = _session.selectTool(
                        StoryCardEditorTool.drawing,
                      );
                    });
                  },
                  onStrokeWidthChanged: (width) {
                    setState(() {
                      _selectedStrokeWidth = width;
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _enterBlankDecorator(StoryCardEditorTool tool) {
    setState(() {
      _backgroundImage?.dispose();
      _backgroundImage = null;
      _session = _session.enterBlankDecorator(tool: tool);
    });
  }

  Future<void> _useBackgroundImage(Uint8List sourceBytes) async {
    if (_isSaving || _isDeleting) {
      return;
    }

    try {
      final normalizedImageBytes = await _normalizeBackgroundImage(sourceBytes);
      if (!mounted) {
        return;
      }

      _backgroundImage?.dispose();
      final backgroundImage = await _decodeUiImage(normalizedImageBytes);
      if (!mounted) {
        backgroundImage.dispose();
        return;
      }

      setState(() {
        _backgroundImage = backgroundImage;
        _session = _session.enterPhotoDecorator(normalizedImageBytes);
      });
    } catch (_) {
      if (mounted) {
        _showSnackBar('사진을 불러오지 못했어요.');
      }
    }
  }

  Future<Uint8List> _normalizeBackgroundImage(Uint8List source) async {
    final decoded = image.decodeImage(source);
    if (decoded == null) {
      throw const FormatException('Unsupported image format.');
    }

    var normalized = image.bakeOrientation(decoded);
    const maximumDimension = 2048;
    if (normalized.width > maximumDimension ||
        normalized.height > maximumDimension) {
      normalized = normalized.width >= normalized.height
          ? image.copyResize(normalized, width: maximumDimension)
          : image.copyResize(normalized, height: maximumDimension);
    }

    var encoded = Uint8List.fromList(image.encodeJpg(normalized, quality: 88));
    while (encoded.length > 5 * 1024 * 1024 &&
        normalized.width > 960 &&
        normalized.height > 960) {
      normalized = image.copyResize(
        normalized,
        width: (normalized.width * 0.8).round(),
        height: (normalized.height * 0.8).round(),
      );
      encoded = Uint8List.fromList(image.encodeJpg(normalized, quality: 82));
    }

    if (encoded.length > 5 * 1024 * 1024) {
      throw const FormatException('Image is too large.');
    }

    return encoded;
  }

  Future<void> _loadBackgroundImage(Uint8List? bytes) async {
    if (bytes == null) {
      return;
    }

    try {
      final decoded = await _decodeUiImage(bytes);
      if (!mounted) {
        decoded.dispose();
        return;
      }

      setState(() {
        _backgroundImage = decoded;
      });
    } catch (_) {
      if (mounted) {
        _showSnackBar('기존 사진을 불러오지 못했어요.');
      }
    }
  }

  Future<ui.Image> _decodeUiImage(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    codec.dispose();
    return frame.image;
  }

  void _startStroke(StoryCardPoint point, int pointer) {
    if (_session.tool != StoryCardEditorTool.drawing ||
        _activePointer != null) {
      return;
    }

    setState(() {
      _activePointer = pointer;
      _activeStroke = StoryCardStroke(
        color: _selectedColor,
        width: _selectedStrokeWidth,
        points: [point],
      );
    });
  }

  void _updateStroke(StoryCardPoint point, int pointer) {
    if (_activePointer != pointer || _activeStroke == null) {
      return;
    }

    setState(() {
      _activeStroke = _activeStroke!.copyWith(
        points: [..._activeStroke!.points, point],
      );
    });
  }

  void _endStroke(int pointer) {
    if (_activePointer != pointer) {
      return;
    }

    final activeStroke = _activeStroke;
    setState(() {
      _activePointer = null;
      _activeStroke = null;
      if (activeStroke != null) {
        _session = _session.updateDraft(
          _draft.copyWith(
            scene: _draft.scene.copyWith(
              strokes: [..._draft.scene.strokes, activeStroke],
            ),
          ),
        );
      }
    });
  }

  void _startBackgroundTransform(ScaleStartDetails details) {
    final transform = _draft.scene.backgroundTransform;
    _backgroundScaleStart = transform.scale;
    _backgroundOffsetStart = Offset(transform.offsetX, transform.offsetY);
    _backgroundFocalPointStart = details.localFocalPoint;
  }

  void _updateBackgroundTransform(ScaleUpdateDetails details, Size size) {
    final image = _backgroundImage;
    if (image == null || size.isEmpty) {
      return;
    }

    final scale = (_backgroundScaleStart * details.scale).clamp(1.0, 4.0);
    final focalDelta = details.localFocalPoint - _backgroundFocalPointStart;
    final offset =
        _backgroundOffsetStart +
        Offset(focalDelta.dx / size.width, focalDelta.dy / size.height);

    setState(() {
      _session = _session.updateDraft(
        _draft.copyWith(
          scene: _draft.scene.copyWith(
            backgroundTransform: StoryCardBackgroundTransform(
              scale: scale,
              offsetX: offset.dx,
              offsetY: offset.dy,
            ),
          ),
        ),
      );
    });
  }

  Future<void> _addTextLayer() async {
    final text = await _editText();
    if (text == null || text.isEmpty || !mounted) {
      return;
    }

    if (_draft.scene.textLayers.length >= storyCardMaxTextLayers) {
      _showSnackBar('텍스트는 최대 $storyCardMaxTextLayers개까지 추가할 수 있어요.');
      return;
    }

    setState(() {
      _session = _session.updateDraft(
        _draft.copyWith(
          scene: _draft.scene.copyWith(
            textLayers: [
              ..._draft.scene.textLayers,
              StoryCardTextLayer(
                id: const Uuid().v4(),
                text: text,
                x: 0.5,
                y: 0.5,
                color: Colors.black,
              ),
            ],
          ),
        ),
      );
    });
  }

  Future<void> _editTextLayer(String layerId) async {
    final layer = _draft.scene.textLayers.firstWhere(
      (candidate) => candidate.id == layerId,
    );
    final text = await _editText(initialValue: layer.text, canDelete: true);
    if (!mounted || text == null) {
      return;
    }

    setState(() {
      _session = _session.updateDraft(
        _draft.copyWith(
          scene: _draft.scene.copyWith(
            textLayers: text.isEmpty
                ? _draft.scene.textLayers
                      .where((candidate) => candidate.id != layerId)
                      .toList(growable: false)
                : _draft.scene.textLayers
                      .map(
                        (candidate) => candidate.id == layerId
                            ? candidate.copyWith(text: text)
                            : candidate,
                      )
                      .toList(growable: false),
          ),
        ),
      );
    });
  }

  Future<String?> _editText({
    String initialValue = '',
    bool canDelete = false,
  }) {
    final controller = TextEditingController(text: initialValue);

    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(canDelete ? '텍스트 수정' : '텍스트 추가'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: storyCardMaxTextCharactersPerLayer,
          maxLines: 5,
          decoration: const InputDecoration(hintText: '짧은 글을 적어주세요.'),
        ),
        actions: [
          if (canDelete)
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(''),
              child: const Text('삭제'),
            ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('완료'),
          ),
        ],
      ),
    );
  }

  void _moveTextLayer(String layerId, Offset delta, Size size) {
    if (size.isEmpty) {
      return;
    }

    setState(() {
      _session = _session.updateDraft(
        _draft.copyWith(
          scene: _draft.scene.copyWith(
            textLayers: _draft.scene.textLayers
                .map(
                  (layer) => layer.id == layerId
                      ? layer.copyWith(
                          x: (layer.x + delta.dx / size.width).clamp(0.0, 1.0),
                          y: (layer.y + delta.dy / size.height).clamp(0.0, 1.0),
                        )
                      : layer,
                )
                .toList(growable: false),
          ),
        ),
      );
    });
  }

  Future<void> _saveCard() async {
    if (!_canSave) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final previewImageBytes = await _capturePreview();
      await ref
          .read(storyCardEditorControllerProvider.notifier)
          .save(draft: _draft, previewImageBytes: previewImageBytes);
      if (mounted) {
        context.go('/home');
      }
    } catch (error) {
      if (mounted) {
        _showSnackBar(_saveFailureMessage(error));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<Uint8List> _capturePreview() async {
    await WidgetsBinding.instance.endOfFrame;
    final renderObject = _previewKey.currentContext?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) {
      throw StateError('Story card preview boundary is unavailable.');
    }

    final pixelRatio = math.min(2.0, 960 / renderObject.size.width).toDouble();
    final image = await renderObject.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (byteData == null) {
      throw StateError('Story card preview export failed.');
    }

    return byteData.buffer.asUint8List();
  }

  Future<void> _deleteCard() async {
    if (_isDeleting || _draft.existingRevision == null) {
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('오늘 카드를 삭제할까요?'),
        content: const Text('삭제하면 질문은 두 카드가 다시 완성될 때만 생성돼요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (shouldDelete != true || !mounted) {
      return;
    }

    setState(() {
      _isDeleting = true;
    });
    try {
      await ref
          .read(storyCardEditorControllerProvider.notifier)
          .delete(expectedRevision: _draft.existingRevision!);
      if (mounted) {
        context.go('/home');
      }
    } catch (error) {
      if (mounted) {
        _showSnackBar(_saveFailureMessage(error));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  String _saveFailureMessage(Object error) {
    if (error is StoryLoopWriteRepositoryException) {
      return switch (error.reason) {
        StoryLoopWriteFailureReason.configMissing =>
          'Supabase 설정이 없어 저장할 수 없어요.',
        StoryLoopWriteFailureReason.authRequired => '로그인이 필요해요.',
        StoryLoopWriteFailureReason.activeCoupleRequired =>
          '커플 연결 상태를 다시 확인해 주세요.',
        StoryLoopWriteFailureReason.relationshipDateRequired ||
        StoryLoopWriteFailureReason.storyNotReady => '관계 시작일을 먼저 설정해 주세요.',
        StoryLoopWriteFailureReason.contentRequired =>
          '사진, 그림, 글 중 하나 이상을 추가해 주세요.',
        StoryLoopWriteFailureReason.invalidTextContent =>
          '텍스트 개수 또는 글자 수를 확인해 주세요.',
        StoryLoopWriteFailureReason.cardLocked => '질문이 생성되어 오늘 카드를 수정할 수 없어요.',
        StoryLoopWriteFailureReason.revisionRequired ||
        StoryLoopWriteFailureReason.revisionConflict =>
          '카드가 다른 곳에서 변경됐어요. 다시 열어 확인해 주세요.',
        StoryLoopWriteFailureReason.cardNotFound => '삭제할 카드를 찾을 수 없어요.',
        StoryLoopWriteFailureReason.questionPoolEmpty =>
          '질문을 준비하지 못했어요. 잠시 후 다시 시도해 주세요.',
        StoryLoopWriteFailureReason.requestTimeout =>
          '요청 시간이 초과됐어요. 다시 시도해 주세요.',
        StoryLoopWriteFailureReason.storage => '카드 파일을 저장하지 못했어요.',
        StoryLoopWriteFailureReason.unknown => '카드를 저장하지 못했어요.',
      };
    }

    return '카드를 저장하지 못했어요.';
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _EditorHeader extends StatelessWidget {
  const _EditorHeader({
    required this.canSave,
    required this.isSaving,
    required this.canDelete,
    required this.onBackPressed,
    required this.onDeletePressed,
    required this.onSavePressed,
  });

  final bool canSave;
  final bool isSaving;
  final bool canDelete;
  final VoidCallback onBackPressed;
  final VoidCallback onDeletePressed;
  final VoidCallback onSavePressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: AppBackButton(onPressed: onBackPressed, iconSize: 32),
          ),
          const Text('오늘의 스토리', style: AppTextStyles.shellTitle),
          Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (canDelete)
                  IconButton(
                    tooltip: '카드 삭제',
                    onPressed: onDeletePressed,
                    icon: const Icon(Icons.delete_outline),
                  ),
                TextButton(
                  onPressed: canSave ? onSavePressed : null,
                  child: isSaving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('올리기'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StoryCardCanvas extends StatelessWidget {
  const _StoryCardCanvas({
    required this.backgroundImage,
    required this.scene,
    required this.visibleStrokes,
    required this.interactionMode,
    required this.onStrokeStart,
    required this.onStrokeUpdate,
    required this.onStrokeEnd,
    required this.onBackgroundScaleStart,
    required this.onBackgroundScaleUpdate,
    required this.onTextLayerMoved,
    required this.onTextLayerTapped,
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
  final void Function(String layerId, Offset delta, Size size) onTextLayerMoved;
  final ValueChanged<String> onTextLayerTapped;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size.square(constraints.biggest.shortestSide);
        return DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.white,
            border: Border.all(color: AppColors.wireframeBorder),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: SizedBox.expand(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _StoryCardPainter(
                        backgroundImage: backgroundImage,
                        backgroundTransform: scene.backgroundTransform,
                        strokes: visibleStrokes,
                      ),
                    ),
                  ),
                  if (interactionMode == StoryCardEditorTool.drawing)
                    Positioned.fill(
                      child: Listener(
                        behavior: HitTestBehavior.opaque,
                        onPointerDown: (event) => onStrokeStart(
                          _normalize(event.localPosition, size),
                          event.pointer,
                        ),
                        onPointerMove: (event) => onStrokeUpdate(
                          _normalize(event.localPosition, size),
                          event.pointer,
                        ),
                        onPointerUp: (event) => onStrokeEnd(event.pointer),
                        onPointerCancel: (event) => onStrokeEnd(event.pointer),
                      ),
                    )
                  else
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onScaleStart: onBackgroundScaleStart,
                        onScaleUpdate: (details) =>
                            onBackgroundScaleUpdate(details, size),
                      ),
                    ),
                  for (final layer in scene.textLayers)
                    Positioned(
                      left: layer.x * size.width - 80,
                      top: layer.y * size.height - 24,
                      child: GestureDetector(
                        onTap: () => onTextLayerTapped(layer.id),
                        onPanUpdate: (details) =>
                            onTextLayerMoved(layer.id, details.delta, size),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: size.width * .72,
                          ),
                          child: Text(
                            layer.text,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.homeBodyMedium.copyWith(
                              color: layer.color,
                              shadows: const [
                                Shadow(
                                  color: Color(0x33000000),
                                  blurRadius: 2,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ),
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
    required this.backgroundTransform,
    required this.strokes,
  });

  final ui.Image? backgroundImage;
  final StoryCardBackgroundTransform backgroundTransform;
  final List<StoryCardStroke> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    final image = backgroundImage;
    if (image != null) {
      final coverScale =
          (size.width / image.width).compareTo(size.height / image.height) >= 0
          ? size.width / image.width
          : size.height / image.height;
      final drawWidth = image.width * coverScale * backgroundTransform.scale;
      final drawHeight = image.height * coverScale * backgroundTransform.scale;
      final offsetX =
          (size.width - drawWidth) / 2 +
          backgroundTransform.offsetX * size.width;
      final offsetY =
          (size.height - drawHeight) / 2 +
          backgroundTransform.offsetY * size.height;
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Rect.fromLTWH(offsetX, offsetY, drawWidth, drawHeight),
        Paint(),
      );
    }

    for (final stroke in strokes) {
      _drawStroke(canvas, size, stroke);
    }
  }

  void _drawStroke(Canvas canvas, Size size, StoryCardStroke stroke) {
    if (stroke.points.isEmpty) {
      return;
    }

    final paint = Paint()
      ..strokeWidth = stroke.width * size.shortestSide
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..color = stroke.color;

    if (stroke.points.length == 1) {
      final point = _denormalize(stroke.points.first, size);
      canvas.drawCircle(
        point,
        paint.strokeWidth / 2,
        paint..style = PaintingStyle.fill,
      );
      return;
    }

    final path = Path();
    final first = _denormalize(stroke.points.first, size);
    path.moveTo(first.dx, first.dy);
    for (final point in stroke.points.skip(1)) {
      final offset = _denormalize(point, size);
      path.lineTo(offset.dx, offset.dy);
    }
    canvas.drawPath(path, paint);
  }

  Offset _denormalize(StoryCardPoint point, Size size) {
    return Offset(point.x * size.width, point.y * size.height);
  }

  @override
  bool shouldRepaint(covariant _StoryCardPainter oldDelegate) {
    return oldDelegate.backgroundImage != backgroundImage ||
        oldDelegate.backgroundTransform != backgroundTransform ||
        oldDelegate.strokes != strokes;
  }
}

class _StoryCardActionBar extends StatelessWidget {
  const _StoryCardActionBar({
    required this.interactionMode,
    required this.hasBackground,
    required this.onAddTextPressed,
    required this.onDrawingModePressed,
    required this.onBackgroundModePressed,
  });

  final StoryCardEditorTool interactionMode;
  final bool hasBackground;
  final VoidCallback onAddTextPressed;
  final VoidCallback onDrawingModePressed;
  final VoidCallback? onBackgroundModePressed;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        _EditorIconButton(
          tooltip: '텍스트 추가',
          icon: Icons.text_fields,
          onPressed: onAddTextPressed,
        ),
        _EditorIconButton(
          tooltip: '그리기',
          icon: Icons.brush_outlined,
          isSelected: interactionMode == StoryCardEditorTool.drawing,
          onPressed: onDrawingModePressed,
        ),
        _EditorIconButton(
          tooltip: '사진 위치 조정',
          icon: Icons.crop,
          isSelected: interactionMode == StoryCardEditorTool.background,
          onPressed: onBackgroundModePressed,
        ),
      ],
    );
  }
}

class _EditorIconButton extends StatelessWidget {
  const _EditorIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.isSelected = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
      color: isSelected ? AppColors.actionPrimary : AppColors.textPrimary,
      style: IconButton.styleFrom(
        backgroundColor: isSelected
            ? AppColors.actionDisabled
            : AppColors.white,
        side: const BorderSide(color: AppColors.wireframeBorder),
      ),
    );
  }
}

class _StoryCardDrawingControls extends StatelessWidget {
  const _StoryCardDrawingControls({
    required this.selectedColor,
    required this.selectedStrokeWidth,
    required this.onColorChanged,
    required this.onStrokeWidthChanged,
  });

  final Color selectedColor;
  final double selectedStrokeWidth;
  final ValueChanged<Color> onColorChanged;
  final ValueChanged<double> onStrokeWidthChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final color in storyCardColorPalette)
              GestureDetector(
                onTap: () => onColorChanged(color),
                child: Container(
                  width: 32,
                  height: 32,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: color == selectedColor
                          ? AppColors.actionPrimary
                          : AppColors.wireframeBorder,
                      width: color == selectedColor ? 2 : 1,
                    ),
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Text('굵기', style: AppTextStyles.homeCharacterLabel),
            const SizedBox(width: 12),
            Container(
              width: 12 + selectedStrokeWidth * 360,
              height: 12 + selectedStrokeWidth * 360,
              decoration: BoxDecoration(
                color: selectedColor,
                shape: BoxShape.circle,
              ),
            ),
            Expanded(
              child: Slider(
                min: storyCardMinStrokeWidth,
                max: storyCardMaxStrokeWidth,
                value: selectedStrokeWidth,
                onChanged: onStrokeWidthChanged,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StoryCardEditorError extends StatelessWidget {
  const _StoryCardEditorError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('스토리 카드를 불러오지 못했어요.'),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: const Text('다시 시도')),
        ],
      ),
    );
  }
}
