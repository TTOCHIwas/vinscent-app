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

  late StoryCardEditorSession _session;
  ui.Image? _backgroundImage;
  StoryCardStroke? _activeStroke;
  Color _selectedColor = storyCardColorPalette.first;
  double _selectedStrokeWidth = storyCardNormalStrokeWidth;
  int? _activePointer;
  double _backgroundScaleStart = 1;
  Offset _backgroundOffsetStart = Offset.zero;
  Offset _backgroundFocalPointStart = Offset.zero;
  StoryCardTextLayer? _textLayerTransformStart;
  Offset _textLayerFocalPointStart = Offset.zero;
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
              onTextSelected: () =>
                  _enterBlankDecorator(StoryCardEditorTool.text),
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
                  child: _StoryCardCanvas(
                    backgroundImage: _backgroundImage,
                    scene: _draft.scene,
                    visibleStrokes: _visibleStrokes,
                    interactionMode: _session.tool,
                    onCanvasTapped: _addTextLayerAt,
                    onStrokeStart: _startStroke,
                    onStrokeUpdate: _updateStroke,
                    onStrokeEnd: _endStroke,
                    onBackgroundScaleStart: _startBackgroundTransform,
                    onBackgroundScaleUpdate: _updateBackgroundTransform,
                    onTextLayerScaleStart: _startTextLayerTransform,
                    onTextLayerScaleUpdate: _updateTextLayerTransform,
                    onTextLayerScaleEnd: _endTextLayerTransform,
                    onTextLayerTapped: _editTextLayer,
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
                  onDrawingModePressed: () =>
                      _selectTool(StoryCardEditorTool.drawing),
                  onBackgroundModePressed: _draft.hasPhoto
                      ? () => _selectTool(StoryCardEditorTool.background)
                      : null,
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
                    selectedColor: _selectedColor,
                    selectedStrokeWidth: _selectedStrokeWidth,
                    onColorChanged: (color) {
                      setState(() {
                        _selectedColor = color;
                      });
                    },
                    onStrokeWidthChanged: (width) {
                      setState(() {
                        _selectedStrokeWidth = width;
                      });
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _handleBack() async {
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

  void _selectTextTool() {
    if (_draft.scene.textLayers.length >= storyCardMaxTextLayers) {
      _showSnackBar('텍스트는 최대 $storyCardMaxTextLayers개까지 추가할 수 있어요.');
      return;
    }
    _selectTool(StoryCardEditorTool.text);
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

    final scale = (_backgroundScaleStart * details.scale)
        .clamp(storyCardMinBackgroundScale, storyCardMaxBackgroundScale)
        .toDouble();
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

  Future<void> _addTextLayerAt(StoryCardPoint point) async {
    if (_session.tool != StoryCardEditorTool.text) {
      return;
    }

    final text = await _editText();
    if (text == null || text.isEmpty || !mounted) {
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

    setState(() {
      _session = _session.updateDraft(
        _draft.copyWith(
          scene: _draft.scene.copyWith(
            textLayers: [
              ..._draft.scene.textLayers,
              StoryCardTextLayer(
                id: const Uuid().v4(),
                text: text,
                x: point.x,
                y: point.y,
                color:
                    _draft.scene.canvasBackground ==
                        StoryCardCanvasBackground.black
                    ? Colors.white
                    : Colors.black,
              ),
            ],
          ),
        ),
        tool: StoryCardEditorTool.none,
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
    final nextCharacterCount =
        _draft.scene.textCharacterCount -
        layer.text.characters.length +
        text.characters.length;
    if (nextCharacterCount > storyCardMaxTextCharacters) {
      _showSnackBar('텍스트 전체 글자 수는 최대 $storyCardMaxTextCharacters자예요.');
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
    return showDialog<String>(
      context: context,
      builder: (_) => _StoryCardTextDialog(
        initialValue: initialValue,
        canDelete: canDelete,
      ),
    );
  }

  void _startTextLayerTransform(String layerId, ScaleStartDetails details) {
    _textLayerTransformStart = _draft.scene.textLayers.firstWhere(
      (layer) => layer.id == layerId,
    );
    _textLayerFocalPointStart = details.localFocalPoint;
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

    setState(() {
      _session = _session.updateDraft(
        _draft.copyWith(
          scene: _draft.scene.copyWith(
            textLayers: _draft.scene.textLayers
                .map(
                  (layer) => layer.id == layerId
                      ? layer.copyWith(x: x, y: y, scale: scale)
                      : layer,
                )
                .toList(growable: false),
          ),
        ),
      );
    });
  }

  void _endTextLayerTransform() {
    _textLayerTransformStart = null;
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

class _StoryCardTextDialog extends StatefulWidget {
  const _StoryCardTextDialog({
    required this.initialValue,
    required this.canDelete,
  });

  final String initialValue;
  final bool canDelete;

  @override
  State<_StoryCardTextDialog> createState() => _StoryCardTextDialogState();
}

class _StoryCardTextDialogState extends State<_StoryCardTextDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.canDelete ? '텍스트 수정' : '텍스트 추가'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: storyCardMaxTextCharactersPerLayer,
        maxLines: 5,
        decoration: const InputDecoration(hintText: '짧은 글을 적어주세요.'),
      ),
      actions: [
        if (widget.canDelete)
          TextButton(
            onPressed: () => Navigator.of(context).pop(''),
            child: const Text('삭제'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('완료'),
        ),
      ],
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

class _StoryCardCanvas extends StatefulWidget {
  const _StoryCardCanvas({
    required this.backgroundImage,
    required this.scene,
    required this.visibleStrokes,
    required this.interactionMode,
    required this.onCanvasTapped,
    required this.onStrokeStart,
    required this.onStrokeUpdate,
    required this.onStrokeEnd,
    required this.onBackgroundScaleStart,
    required this.onBackgroundScaleUpdate,
    required this.onTextLayerScaleStart,
    required this.onTextLayerScaleUpdate,
    required this.onTextLayerScaleEnd,
    required this.onTextLayerTapped,
  });

  final ui.Image? backgroundImage;
  final StoryCardScene scene;
  final List<StoryCardStroke> visibleStrokes;
  final StoryCardEditorTool interactionMode;
  final ValueChanged<StoryCardPoint> onCanvasTapped;
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
  final ValueChanged<String> onTextLayerTapped;

  @override
  State<_StoryCardCanvas> createState() => _StoryCardCanvasState();
}

class _StoryCardCanvasState extends State<_StoryCardCanvas> {
  final Set<int> _activePointers = {};
  final Map<int, String> _textPointerTargets = {};

  String? _lockedTextLayerId;
  bool _isBackgroundTransformLocked = false;

  @override
  void didUpdateWidget(covariant _StoryCardCanvas oldWidget) {
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
                        backgroundTransform: widget.scene.backgroundTransform,
                        canvasBackground: widget.scene.canvasBackground,
                        strokes: widget.visibleStrokes,
                      ),
                    ),
                  ),
                  if (widget.interactionMode == StoryCardEditorTool.text)
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapUp: (details) => widget.onCanvasTapped(
                          _normalize(details.localPosition, size),
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
                          child: GestureDetector(
                            onTap: () => widget.onTextLayerTapped(layer.id),
                            child: Transform.scale(
                              scale: layer.scale,
                              child: SizedBox(
                                width: size.width * .72,
                                child: Text(
                                  layer.text,
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.homeBodyMedium.copyWith(
                                    color: layer.color,
                                    shadows: const [],
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
        widget.interactionMode == StoryCardEditorTool.background &&
        widget.backgroundImage != null) {
      _isBackgroundTransformLocked = true;
      widget.onBackgroundScaleStart(details);
    }
  }

  void _handleScaleUpdate(ScaleUpdateDetails details, Size size) {
    final lockedTextLayerId = _lockedTextLayerId;
    if (lockedTextLayerId != null) {
      final hasActiveTextPointer = _textPointerTargets.containsValue(
        lockedTextLayerId,
      );
      if (details.pointerCount >= 2 || hasActiveTextPointer) {
        widget.onTextLayerScaleUpdate(lockedTextLayerId, details, size);
      }
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
    required this.backgroundTransform,
    required this.canvasBackground,
    required this.strokes,
  });

  final ui.Image? backgroundImage;
  final StoryCardBackgroundTransform backgroundTransform;
  final StoryCardCanvasBackground canvasBackground;
  final List<StoryCardStroke> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = canvasBackground.color,
    );
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
        oldDelegate.canvasBackground != canvasBackground ||
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
    required this.onBackgroundColorPressed,
  });

  final StoryCardEditorTool interactionMode;
  final bool hasBackground;
  final VoidCallback onAddTextPressed;
  final VoidCallback onDrawingModePressed;
  final VoidCallback? onBackgroundModePressed;
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
          tooltip: '그리기',
          icon: Icons.brush_outlined,
          isSelected: interactionMode == StoryCardEditorTool.drawing,
          onPressed: onDrawingModePressed,
        ),
        if (hasBackground) ...[
          const SizedBox(height: 8),
          _EditorIconButton(
            tooltip: '사진 위치 조정',
            icon: Icons.crop,
            isSelected: interactionMode == StoryCardEditorTool.background,
            onPressed: onBackgroundModePressed,
          ),
        ] else ...[
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
                          color: color == selectedColor
                              ? Colors.white
                              : Colors.white54,
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
            const SizedBox(height: 4),
            Row(
              children: [
                const Text(
                  '굵기',
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 12 + selectedStrokeWidth * 300,
                  height: 12 + selectedStrokeWidth * 300,
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
