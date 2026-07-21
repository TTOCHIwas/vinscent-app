import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as image;
import 'package:uuid/uuid.dart';

import '../../../core/assets/app_icons.dart';
import '../../../core/presentation/widgets/app_back_button.dart';
import '../../../core/presentation/widgets/app_svg_icon.dart';
import '../../../core/theme/app_colors.dart';
import '../application/story_card_editor_controller.dart';
import '../data/story_card_draft.dart';
import '../data/story_card_editor_session.dart';
import '../data/story_card_scene.dart';
import '../data/story_loop_write_failure.dart';
import 'widgets/story_card_caption_input_overlay.dart';
import 'widgets/story_card_camera_stage.dart';
import 'widgets/story_card_editor_canvas.dart';
import 'widgets/story_card_text_input_overlay.dart';

class StoryCardEditorScreen extends ConsumerWidget {
  const StoryCardEditorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draftAsync = ref.watch(storyCardEditorControllerProvider);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.black,
      body: draftAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
        ),
        error: (error, stackTrace) => _StoryCardEditorError(
          onRetry: () => ref.invalidate(storyCardEditorControllerProvider),
        ),
        data: (draft) => _StoryCardEditorContent(
          key: ValueKey(draft.existingRevision),
          initialDraft: draft,
        ),
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
  final _textTrashTargetKey = GlobalKey();

  late StoryCardEditorSession _session;
  ui.Image? _backgroundImage;
  StoryCardStroke? _activeStroke;
  StoryCardDrawingTool _selectedDrawingTool = StoryCardDrawingTool.pen;
  Color _selectedColor = storyCardColorPalette.first;
  double _selectedStrokeWidth = storyCardNormalStrokeWidth;
  int? _activePointer;
  double _backgroundScaleStart = 1;
  Offset _backgroundOffsetStart = Offset.zero;
  Offset _backgroundFocalPointStart = Offset.zero;
  StoryCardTextLayer? _textLayerTransformStart;
  Offset _textLayerFocalPointStart = Offset.zero;
  bool _isTextInputActive = false;
  bool _isCaptionInputActive = false;
  bool _isDraggingText = false;
  bool _isTextOverTrash = false;
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

  bool get _canSave =>
      !_isTextInputActive &&
      !_isCaptionInputActive &&
      !_isSaving &&
      !_isDeleting &&
      _draft.hasContent;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleBack();
        }
      },
      child: _session.stage == StoryCardEditorStage.camera
          ? StoryCardCameraStage(
              onBack: _handleBack,
              onImageSelected: _useBackgroundImage,
              onTextSelected: _enterBlankTextDecorator,
              onDrawingSelected: () =>
                  _enterBlankDecorator(StoryCardEditorTool.drawing),
            )
          : _buildDecorator(),
    );
  }

  Widget _buildDecorator() {
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          SafeArea(
            child: Center(
              child: AspectRatio(
                key: const ValueKey('story-card-editor-canvas'),
                aspectRatio: storyCardCanvasAspectRatio,
                child: RepaintBoundary(
                  key: _previewKey,
                  child: StoryCardEditorCanvas(
                    backgroundImage: _backgroundImage,
                    scene: _draft.scene,
                    visibleStrokes: _visibleStrokes,
                    interactionMode: _session.tool,
                    onStrokeStart: _startStroke,
                    onStrokeUpdate: _updateStroke,
                    onStrokeEnd: _endStroke,
                    onBackgroundScaleStart: _startBackgroundTransform,
                    onBackgroundScaleUpdate: _updateBackgroundTransform,
                    onTextLayerScaleStart: _startTextLayerTransform,
                    onTextLayerScaleUpdate: _updateTextLayerTransform,
                    onTextLayerScaleEnd: _endTextLayerTransform,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: _EditorHeader(
                key: const ValueKey('story-card-editor-header'),
                canSave: _canSave,
                isSaving: _isSaving,
                canDelete:
                    _draft.existingRevision != null &&
                    !_isSaving &&
                    !_isDeleting,
                onBackPressed: _handleBack,
                onDeletePressed: _deleteCard,
                onSavePressed: _saveCard,
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _StoryCardActionBar(
                  interactionMode: _session.tool,
                  hasBackground: _draft.hasPhoto,
                  onAddTextPressed: _selectTextTool,
                  onEditCaptionPressed: _selectCaptionTool,
                  onDrawingModePressed: () =>
                      _selectTool(StoryCardEditorTool.drawing),
                  onBackgroundColorPressed: _draft.hasPhoto
                      ? null
                      : _toggleCanvasBackground,
                ),
              ),
            ),
          ),
          if (_session.tool == StoryCardEditorTool.drawing)
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: _StoryCardDrawingControls(
                    selectedTool: _selectedDrawingTool,
                    selectedColor: _selectedColor,
                    selectedStrokeWidth: _selectedStrokeWidth,
                    canUndo:
                        _activeStroke == null &&
                        _draft.scene.strokes.isNotEmpty,
                    onToolChanged: (tool) {
                      setState(() {
                        _selectedDrawingTool = tool;
                      });
                    },
                    onColorChanged: (color) {
                      setState(() {
                        _selectedColor = color;
                        _selectedDrawingTool = StoryCardDrawingTool.pen;
                      });
                    },
                    onStrokeWidthChanged: (width) {
                      setState(() {
                        _selectedStrokeWidth = width;
                      });
                    },
                    onUndoPressed: _undoLastStroke,
                    onDonePressed: _completeDrawing,
                  ),
                ),
              ),
            ),
          if (_isDraggingText)
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _StoryCardTextTrashTarget(
                    key: _textTrashTargetKey,
                    isActive: _isTextOverTrash,
                  ),
                ),
              ),
            ),
          if (_isTextInputActive)
            StoryCardTextInputOverlay(
              maxLength: _remainingTextCharacterLimit,
              onCancelled: _cancelTextInput,
              onSubmitted: _submitTextInput,
            ),
          if (_isCaptionInputActive)
            StoryCardCaptionInputOverlay(
              initialValue: _draft.scene.caption ?? '',
              onCancelled: _cancelCaptionInput,
              onSubmitted: _submitCaptionInput,
            ),
        ],
      ),
    );
  }

  int get _remainingTextCharacterLimit {
    final remaining =
        storyCardMaxTextCharacters - _draft.scene.textCharacterCount;
    return remaining < storyCardMaxTextCharactersPerLayer
        ? remaining
        : storyCardMaxTextCharactersPerLayer;
  }

  Future<void> _handleBack() async {
    if (_isTextInputActive) {
      _cancelTextInput();
      return;
    }
    if (_isCaptionInputActive) {
      _cancelCaptionInput();
      return;
    }

    if (_isSaving || _isDeleting) {
      return;
    }

    if (_session.stage == StoryCardEditorStage.camera) {
      context.go('/home');
      return;
    }

    if (!_session.hasUnsavedChanges) {
      if (_session.hasPersistedCard) {
        context.go('/home');
      } else {
        _returnToCamera();
      }
      return;
    }

    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('수정 내용을 삭제하시겠어요?'),
        content: const Text('현재 편집 중인 사진, 그림, 텍스트가 모두 삭제돼요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('계속 수정'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (shouldDiscard != true || !mounted) {
      return;
    }

    await _discardUnsavedChanges();
  }

  void _returnToCamera() {
    _backgroundImage?.dispose();
    setState(() {
      _backgroundImage = null;
      _session = _session.returnToCamera();
    });
  }

  Future<void> _discardUnsavedChanges() async {
    final nextSession = _session.discardChanges();
    final bytes = nextSession.draft.backgroundImageBytes;
    ui.Image? nextBackgroundImage;
    if (bytes != null) {
      try {
        nextBackgroundImage = await _decodeUiImage(bytes);
      } catch (_) {
        if (mounted) {
          _showSnackBar('기존 사진을 불러오지 못했어요.');
        }
      }
    }
    if (!mounted) {
      nextBackgroundImage?.dispose();
      return;
    }

    _backgroundImage?.dispose();
    setState(() {
      _backgroundImage = nextBackgroundImage;
      _activeStroke = null;
      _activePointer = null;
      _session = nextSession;
    });
  }

  void _selectTool(StoryCardEditorTool tool) {
    setState(() {
      _session = _session.selectTool(tool);
    });
  }

  void _undoLastStroke() {
    if (_activeStroke != null || _draft.scene.strokes.isEmpty) {
      return;
    }

    setState(() {
      _session = _session.updateDraft(
        _draft.copyWith(
          scene: _draft.scene.copyWith(
            strokes: _draft.scene.strokes.sublist(
              0,
              _draft.scene.strokes.length - 1,
            ),
          ),
        ),
      );
    });
  }

  void _completeDrawing() {
    if (_activePointer != null) {
      return;
    }

    _selectTool(
      _draft.hasPhoto
          ? StoryCardEditorTool.background
          : StoryCardEditorTool.none,
    );
  }

  void _selectTextTool() {
    if (_draft.scene.textLayers.length >= storyCardMaxTextLayers) {
      _showSnackBar('텍스트는 최대 $storyCardMaxTextLayers개까지 추가할 수 있어요.');
      return;
    }
    if (_remainingTextCharacterLimit <= 0) {
      _showSnackBar('텍스트 전체 글자 수는 최대 $storyCardMaxTextCharacters자예요.');
      return;
    }

    setState(() {
      _session = _session.selectTool(StoryCardEditorTool.text);
      _isTextInputActive = true;
    });
  }

  void _selectCaptionTool() {
    setState(() {
      _session = _session.selectTool(StoryCardEditorTool.none);
      _isCaptionInputActive = true;
    });
  }

  void _toggleCanvasBackground() {
    final background =
        _draft.scene.canvasBackground == StoryCardCanvasBackground.white
        ? StoryCardCanvasBackground.black
        : StoryCardCanvasBackground.white;
    setState(() {
      _session = _session.updateDraft(
        _draft.copyWith(
          scene: _draft.scene.copyWith(canvasBackground: background),
        ),
      );
    });
  }

  void _enterBlankDecorator(StoryCardEditorTool tool) {
    setState(() {
      _backgroundImage?.dispose();
      _backgroundImage = null;
      _session = _session.enterBlankDecorator(tool: tool);
    });
  }

  void _enterBlankTextDecorator() {
    setState(() {
      _backgroundImage?.dispose();
      _backgroundImage = null;
      _session = _session.enterBlankDecorator(
        tool: StoryCardEditorTool.text,
        background: StoryCardCanvasBackground.black,
      );
      _isTextInputActive = true;
    });
  }

  void _cancelTextInput() {
    if (!_isTextInputActive) {
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _isTextInputActive = false;
      _session = _session.selectTool(
        _draft.hasPhoto
            ? StoryCardEditorTool.background
            : StoryCardEditorTool.none,
      );
    });
  }

  void _cancelCaptionInput() {
    if (!_isCaptionInputActive) {
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _isCaptionInputActive = false;
      _session = _session.selectTool(
        _draft.hasPhoto
            ? StoryCardEditorTool.background
            : StoryCardEditorTool.none,
      );
    });
  }

  void _submitCaptionInput(String value) {
    final caption = value.trim();
    if (caption.characters.length > storyCardMaxCaptionCharacters ||
        caption.split(RegExp(r'\r\n?|\n')).length > storyCardMaxCaptionLines) {
      _showSnackBar(
        '짧은 글은 최대 $storyCardMaxCaptionCharacters자, '
        '$storyCardMaxCaptionLines줄까지 입력할 수 있어요.',
      );
      return;
    }

    final nextCaption = caption.isEmpty ? null : caption;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _isCaptionInputActive = false;
      final nextTool = _draft.hasPhoto
          ? StoryCardEditorTool.background
          : StoryCardEditorTool.none;
      if (nextCaption == _draft.scene.caption) {
        _session = _session.selectTool(nextTool);
        return;
      }
      _session = _session.updateDraft(
        _draft.copyWith(scene: _draft.scene.copyWith(caption: nextCaption)),
        tool: nextTool,
      );
    });
  }

  void _submitTextInput(String value, Color color) {
    final text = value.trim();
    if (text.isEmpty) {
      _cancelTextInput();
      return;
    }
    if (text.characters.length > storyCardMaxTextCharactersPerLayer) {
      _showSnackBar('텍스트는 레이어당 최대 $storyCardMaxTextCharactersPerLayer자예요.');
      return;
    }
    if (_draft.scene.textLayers.length >= storyCardMaxTextLayers) {
      _showSnackBar('텍스트는 최대 $storyCardMaxTextLayers개까지 추가할 수 있어요.');
      return;
    }
    if (_draft.scene.textCharacterCount + text.characters.length >
        storyCardMaxTextCharacters) {
      _showSnackBar('텍스트 전체 글자 수는 최대 $storyCardMaxTextCharacters자예요.');
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _isTextInputActive = false;
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
                color: color,
              ),
            ],
          ),
        ),
        tool: StoryCardEditorTool.none,
      );
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
        tool: _selectedDrawingTool,
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

    final photoRect = StoryCardPolaroidLayout.fromSize(size).photoRect;
    final scale = (_backgroundScaleStart * details.scale)
        .clamp(storyCardMinBackgroundScale, storyCardMaxBackgroundScale)
        .toDouble();
    final focalDelta = details.localFocalPoint - _backgroundFocalPointStart;
    final offset =
        _backgroundOffsetStart +
        Offset(
          focalDelta.dx / photoRect.width,
          focalDelta.dy / photoRect.height,
        );

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

  void _startTextLayerTransform(String layerId, ScaleStartDetails details) {
    _textLayerTransformStart = _draft.scene.textLayers.firstWhere(
      (layer) => layer.id == layerId,
    );
    _textLayerFocalPointStart = details.localFocalPoint;
    if (!_isDraggingText) {
      setState(() {
        _isDraggingText = true;
        _isTextOverTrash = false;
      });
    }
  }

  void _updateTextLayerTransform(
    String layerId,
    ScaleUpdateDetails details,
    Size size,
  ) {
    final start = _textLayerTransformStart;
    if (start == null || start.id != layerId || size.isEmpty) {
      return;
    }

    final delta = details.localFocalPoint - _textLayerFocalPointStart;
    final x = (start.x + delta.dx / size.width).clamp(0.0, 1.0);
    final y = (start.y + delta.dy / size.height).clamp(0.0, 1.0);
    final scale = (start.scale * details.scale)
        .clamp(storyCardMinTextScale, storyCardMaxTextScale)
        .toDouble();
    final rotation = start.rotation + details.rotation;
    final isOverTrash = _isTextCenterOverTrash(x: x, y: y);

    setState(() {
      _isTextOverTrash = isOverTrash;
      _session = _session.updateDraft(
        _draft.copyWith(
          scene: _draft.scene.copyWith(
            textLayers: _draft.scene.textLayers
                .map(
                  (layer) => layer.id == layerId
                      ? layer.copyWith(
                          x: x,
                          y: y,
                          scale: scale,
                          rotation: rotation,
                        )
                      : layer,
                )
                .toList(growable: false),
          ),
        ),
      );
    });
  }

  void _endTextLayerTransform() {
    final layerId = _textLayerTransformStart?.id;
    final shouldDelete = _isTextOverTrash && layerId != null;
    setState(() {
      if (shouldDelete) {
        _session = _session.updateDraft(
          _draft.copyWith(
            scene: _draft.scene.copyWith(
              textLayers: _draft.scene.textLayers
                  .where((layer) => layer.id != layerId)
                  .toList(growable: false),
            ),
          ),
        );
      }
      _textLayerTransformStart = null;
      _isDraggingText = false;
      _isTextOverTrash = false;
    });
  }

  bool _isTextCenterOverTrash({required double x, required double y}) {
    final previewBox = _previewKey.currentContext?.findRenderObject();
    final trashBox = _textTrashTargetKey.currentContext?.findRenderObject();
    if (previewBox is! RenderBox ||
        trashBox is! RenderBox ||
        !previewBox.hasSize ||
        !trashBox.hasSize) {
      return false;
    }

    final textCenter = previewBox.localToGlobal(
      Offset(x * previewBox.size.width, y * previewBox.size.height),
    );
    final trashRect = trashBox.localToGlobal(Offset.zero) & trashBox.size;
    return trashRect.inflate(12).contains(textCenter);
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

    if (renderObject.size.width <= 0) {
      throw StateError('Story card preview boundary has an invalid size.');
    }
    final pixelRatio = storyCardPreviewWidth / renderObject.size.width;
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

class _StoryCardTextTrashTarget extends StatelessWidget {
  const _StoryCardTextTrashTarget({super.key, required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      key: const ValueKey('story-card-text-trash-target'),
      dimension: 72,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive ? const Color(0xE6000000) : const Color(0xB8000000),
          border: Border.all(
            color: isActive ? AppColors.actionPrimary : Colors.white54,
          ),
        ),
        child: Icon(
          Icons.delete_outline,
          key: const ValueKey('story-card-text-trash-icon'),
          color: isActive ? AppColors.actionPrimary : Colors.white,
          size: isActive ? 36 : 32,
        ),
      ),
    );
  }
}

class _EditorHeader extends StatelessWidget {
  const _EditorHeader({
    super.key,
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
    return ColoredBox(
      color: const Color(0x52000000),
      child: SizedBox(
        height: 56,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: AppBackButton(
                onPressed: onBackPressed,
                color: Colors.white,
                iconSize: 30,
              ),
            ),
            const Text(
              '오늘의 스토리',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (canDelete)
                    IconButton(
                      tooltip: '카드 삭제',
                      color: Colors.white,
                      onPressed: onDeletePressed,
                      icon: const Icon(Icons.delete_outline),
                    ),
                  TextButton(
                    key: const ValueKey('story-card-editor-save'),
                    style: TextButton.styleFrom(foregroundColor: Colors.white),
                    onPressed: canSave ? onSavePressed : null,
                    child: isSaving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('올리기'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoryCardActionBar extends StatelessWidget {
  const _StoryCardActionBar({
    required this.interactionMode,
    required this.hasBackground,
    required this.onAddTextPressed,
    required this.onEditCaptionPressed,
    required this.onDrawingModePressed,
    required this.onBackgroundColorPressed,
  });

  final StoryCardEditorTool interactionMode;
  final bool hasBackground;
  final VoidCallback onAddTextPressed;
  final VoidCallback onEditCaptionPressed;
  final VoidCallback onDrawingModePressed;
  final VoidCallback? onBackgroundColorPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _EditorIconButton(
          tooltip: '텍스트 추가',
          icon: Icons.text_fields,
          isSelected: interactionMode == StoryCardEditorTool.text,
          onPressed: onAddTextPressed,
        ),
        const SizedBox(height: 8),
        _EditorIconButton(
          key: const ValueKey('story-card-caption-tool'),
          tooltip: '짧은 글',
          icon: Icons.short_text,
          onPressed: onEditCaptionPressed,
        ),
        const SizedBox(height: 8),
        _EditorIconButton(
          tooltip: '그리기',
          icon: Icons.brush_outlined,
          isSelected: interactionMode == StoryCardEditorTool.drawing,
          onPressed: onDrawingModePressed,
        ),
        if (!hasBackground) ...[
          const SizedBox(height: 8),
          _EditorIconButton(
            tooltip: '배경색 전환',
            icon: Icons.contrast,
            onPressed: onBackgroundColorPressed,
          ),
        ],
      ],
    );
  }
}

class _EditorIconButton extends StatelessWidget {
  const _EditorIconButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
    this.icon,
    this.iconWidget,
    this.isSelected = false,
  }) : assert(icon != null || iconWidget != null),
       assert(icon == null || iconWidget == null);

  final String tooltip;
  final IconData? icon;
  final Widget? iconWidget;
  final VoidCallback? onPressed;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: iconWidget ?? Icon(icon),
      color: Colors.white,
      style: IconButton.styleFrom(
        backgroundColor: isSelected
            ? AppColors.actionPrimary
            : const Color(0x85000000),
      ),
    );
  }
}

class _StoryCardDrawingControls extends StatelessWidget {
  const _StoryCardDrawingControls({
    required this.selectedTool,
    required this.selectedColor,
    required this.selectedStrokeWidth,
    required this.canUndo,
    required this.onToolChanged,
    required this.onColorChanged,
    required this.onStrokeWidthChanged,
    required this.onUndoPressed,
    required this.onDonePressed,
  });

  final StoryCardDrawingTool selectedTool;
  final Color selectedColor;
  final double selectedStrokeWidth;
  final bool canUndo;
  final ValueChanged<StoryCardDrawingTool> onToolChanged;
  final ValueChanged<Color> onColorChanged;
  final ValueChanged<double> onStrokeWidthChanged;
  final VoidCallback onUndoPressed;
  final VoidCallback onDonePressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xB8000000),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _EditorIconButton(
                  key: const ValueKey('story-card-drawing-pen'),
                  tooltip: '펜',
                  icon: Icons.edit,
                  isSelected: selectedTool == StoryCardDrawingTool.pen,
                  onPressed: () => onToolChanged(StoryCardDrawingTool.pen),
                ),
                const SizedBox(width: 6),
                _EditorIconButton(
                  key: const ValueKey('story-card-drawing-eraser'),
                  tooltip: '지우개',
                  iconWidget: const AppSvgIcon(AppIcons.eraser),
                  isSelected: selectedTool == StoryCardDrawingTool.eraser,
                  onPressed: () => onToolChanged(StoryCardDrawingTool.eraser),
                ),
                const SizedBox(width: 6),
                _EditorIconButton(
                  key: const ValueKey('story-card-drawing-undo'),
                  tooltip: '되돌리기',
                  icon: Icons.undo,
                  onPressed: canUndo ? onUndoPressed : null,
                ),
                const Spacer(),
                TextButton(
                  key: const ValueKey('story-card-drawing-done'),
                  onPressed: onDonePressed,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: AppColors.actionPrimary,
                    minimumSize: const Size(64, 40),
                  ),
                  child: const Text('완료'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final color in storyCardColorPalette)
                  GestureDetector(
                    onTap: () => onColorChanged(color),
                    child: Container(
                      width: 28,
                      height: 28,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color:
                              color == selectedColor &&
                                  selectedTool == StoryCardDrawingTool.pen
                              ? Colors.white
                              : Colors.white54,
                          width:
                              color == selectedColor &&
                                  selectedTool == StoryCardDrawingTool.pen
                              ? 2
                              : 1,
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
            const SizedBox(height: 4),
            Row(
              children: [
                const Text(
                  '굵기',
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
                const SizedBox(width: 10),
                SizedBox.square(
                  dimension: 44,
                  child: Center(
                    child: Container(
                      width: 12 + selectedStrokeWidth * 300,
                      height: 12 + selectedStrokeWidth * 300,
                      decoration: BoxDecoration(
                        color: selectedTool == StoryCardDrawingTool.pen
                            ? selectedColor
                            : Colors.white70,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Slider(
                    min: storyCardMinStrokeWidth,
                    max: storyCardMaxStrokeWidth,
                    value: selectedStrokeWidth.clamp(
                      storyCardMinStrokeWidth,
                      storyCardMaxStrokeWidth,
                    ),
                    activeColor: Colors.white,
                    inactiveColor: Colors.white38,
                    onChanged: onStrokeWidthChanged,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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
          const Text(
            '스토리 카드를 불러오지 못했어요.',
            style: TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: const Text('다시 시도')),
        ],
      ),
    );
  }
}
