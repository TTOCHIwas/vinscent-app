import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/drawing/widgets/app_canvas_color_picker.dart';
import '../../../core/presentation/widgets/app_confirmation_dialog.dart';
import '../../characters/application/couple_character_controller.dart';
import '../application/story_card_camera_selection.dart';
import '../application/story_card_editor_controller.dart';
import '../application/story_card_editor_session.dart';
import '../application/story_card_film_shader.dart';
import '../application/story_card_gallery_picker.dart';
import '../application/story_card_image_normalizer.dart';
import '../data/story_card_draft.dart';
import '../data/story_card_film_look.dart';
import '../data/story_card_scene.dart';
import '../data/story_card_type.dart';
import '../data/story_loop_write_failure.dart';
import 'widgets/story_card_caption_input_overlay.dart';
import 'widgets/story_card_camera_stage.dart';
import 'widgets/story_card_drawing_controls.dart';
import 'widgets/story_card_editor_action_bar.dart';
import 'widgets/story_card_editor_canvas.dart';
import 'widgets/story_card_editor_header.dart';
import 'widgets/story_card_film_look_selector.dart';
import 'widgets/story_card_photo_assembly.dart';
import 'widgets/story_card_text_input_overlay.dart';
import 'widgets/story_card_text_trash_target.dart';
import 'widgets/story_card_type_selector.dart';

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
  final _galleryPicker = StoryCardGalleryPicker();

  late StoryCardEditorSession _session;
  late List<ui.Image?> _backgroundImages;
  StoryCardStroke? _activeStroke;
  StoryCardDrawingTool _selectedDrawingTool = StoryCardDrawingTool.pen;
  Color _selectedColor = storyCardColorPalette.first;
  double _selectedStrokeWidth = storyCardNormalStrokeWidth;
  int? _activePointer;
  double _backgroundScaleStart = 1;
  Offset _backgroundOffsetStart = Offset.zero;
  Offset _backgroundFocalPointStart = Offset.zero;
  int? _backgroundTransformPhotoIndex;
  int _selectedPhotoIndex = 0;
  StoryCardTextLayer? _textLayerTransformStart;
  Offset _textLayerFocalPointStart = Offset.zero;
  bool _isTextInputActive = false;
  bool _isCaptionInputActive = false;
  bool _isDraggingText = false;
  bool _isTextOverTrash = false;
  bool _isPickingColor = false;
  bool _isPickingGallery = false;
  bool _isSaving = false;
  late StoryCardFilmState _cameraFilm;
  ui.FragmentProgram? _filmProgram;
  Future<ui.FragmentProgram>? _filmProgramFuture;

  @override
  void initState() {
    super.initState();
    _session = StoryCardEditorSession.fromDraft(widget.initialDraft);
    _cameraFilm = widget.initialDraft.scene.film.seed > 0
        ? widget.initialDraft.scene.film
        : widget.initialDraft.scene.film.copyWith(
            seed: StoryCardFilmSeed.now(),
          );
    _backgroundImages = List<ui.Image?>.filled(
      _draft.scene.cardType.requiredPhotoCount,
      null,
      growable: false,
    );
    unawaited(_loadBackgroundImages(_draft.photoImageBytes));
    if (_draft.scene.film.look != StoryCardFilmLook.original) {
      unawaited(_prepareFilmProgram());
    }
  }

  @override
  void dispose() {
    _disposeImages(_backgroundImages);
    super.dispose();
  }

  StoryCardDraft get _draft => _session.draft;

  List<StoryCardStroke> get _visibleStrokes {
    return [..._draft.scene.strokes, ?_activeStroke];
  }

  bool get _canSave =>
      !_isTextInputActive &&
      !_isCaptionInputActive &&
      !_isPickingColor &&
      !_isPickingGallery &&
      !_isSaving &&
      _draft.canSave;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleBack();
        }
      },
      child: switch (_session.stage) {
        StoryCardEditorStage.formatSelection => StoryCardTypeSelector(
          onBack: () => context.go('/home'),
          onSelected: _selectCardType,
        ),
        StoryCardEditorStage.camera => StoryCardCameraStage(
          onBack: _handleBack,
          onImageSelected: _useBackgroundImage,
          initialFilm: _cameraFilm,
          onFilmChanged: (film) => _cameraFilm = film,
          loadCharacterImage: _loadCoupleCharacterImage,
          onTextSelected: _enterBlankTextDecorator,
          onDrawingSelected: () =>
              _enterBlankDecorator(StoryCardEditorTool.drawing),
          showEditorTools: !_draft.scene.cardType.isFourCut,
          showGalleryButton: !_draft.scene.cardType.isFourCut,
        ),
        StoryCardEditorStage.assembling => StoryCardPhotoAssembly(
          cardType: _draft.scene.cardType,
          photos: _draft.photoImageBytes,
          selectedIndex: _selectedPhotoIndex,
          isPickingGallery: _isPickingGallery,
          onBack: _handleBack,
          onPhotoSelected: _selectPhotoSlot,
          onCameraPressed: _openFourCutCamera,
          onGalleryPressed: () => unawaited(_pickFourCutGallery()),
          onContinue: _draft.hasAllRequiredPhotos
              ? _continueToFourCutDecorator
              : null,
        ),
        StoryCardEditorStage.decorating => _buildDecorator(),
      },
    );
  }

  Widget _buildDecorator() {
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          SafeArea(
            child: Padding(
              padding: _session.tool == StoryCardEditorTool.drawing
                  ? StoryCardDrawingControls.canvasInsets
                  : EdgeInsets.zero,
              child: Center(
                child: AspectRatio(
                  key: const ValueKey('story-card-editor-canvas'),
                  aspectRatio: _draft.scene.cardType.canvasAspectRatio,
                  child: RepaintBoundary(
                    key: _previewKey,
                    child: StoryCardEditorCanvas(
                      backgroundImages: _backgroundImages,
                      filmProgram: _filmProgram,
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
          ),
          if (_session.tool != StoryCardEditorTool.drawing)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: StoryCardEditorHeader(
                  key: const ValueKey('story-card-editor-header'),
                  canSave: _canSave,
                  isSaving: _isSaving,
                  onBackPressed: _handleBack,
                  onSavePressed: _saveCard,
                ),
              ),
            ),
          if (_session.tool != StoryCardEditorTool.drawing)
            SafeArea(
              child: Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: StoryCardEditorActionBar(
                    interactionMode: _session.tool,
                    hasBackground: _draft.hasPhoto,
                    onAddTextPressed: _selectTextTool,
                    onEditCaptionPressed: _draft.scene.cardType.supportsCaption
                        ? _selectCaptionTool
                        : null,
                    onDrawingModePressed: () =>
                        _selectTool(StoryCardEditorTool.drawing),
                    onBackgroundColorPressed: _draft.hasPhoto
                        ? null
                        : _toggleCanvasBackground,
                    onFilmPressed: _draft.hasPhoto ? _toggleFilmSelector : null,
                    isFilmSelected: _session.tool == StoryCardEditorTool.film,
                  ),
                ),
              ),
            ),
          if (_session.tool == StoryCardEditorTool.film)
            Positioned(
              left: 12,
              right: 12,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: StoryCardFilmLookSelector(
                    key: const ValueKey('story-card-editor-film-selector'),
                    selectedLook: _draft.scene.film.look,
                    onLookChanged: _selectFilmLook,
                    keyPrefix: 'story-card-editor-film',
                  ),
                ),
              ),
            ),
          if (_session.tool == StoryCardEditorTool.drawing)
            Positioned.fill(
              child: SafeArea(
                child: StoryCardDrawingControls(
                  selectedTool: _selectedDrawingTool,
                  selectedColor: _selectedColor,
                  selectedStrokeWidth: _selectedStrokeWidth,
                  canUndo:
                      _activeStroke == null && _draft.scene.strokes.isNotEmpty,
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
                  onEyedropperPressed: _enterColorSampler,
                  onDonePressed: _completeDrawing,
                ),
              ),
            ),
          if (_isDraggingText)
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: StoryCardTextTrashTarget(
                    key: _textTrashTargetKey,
                    isActive: _isTextOverTrash,
                  ),
                ),
              ),
            ),
          if (_isTextInputActive)
            StoryCardTextInputOverlay(
              maxLength: _remainingTextCharacterLimit,
              onPickColor: () => showAppCanvasColorPicker(
                context: context,
                canvasKey: _previewKey,
                backgroundColor: Colors.black,
                keyPrefix: 'story-card-text-input',
              ),
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
    if (_isPickingColor) {
      setState(() => _isPickingColor = false);
      return;
    }
    if (_isTextInputActive) {
      _cancelTextInput();
      return;
    }
    if (_isCaptionInputActive) {
      _cancelCaptionInput();
      return;
    }

    if (_isSaving) {
      return;
    }
    if (_isPickingGallery) {
      return;
    }
    if (_session.tool == StoryCardEditorTool.drawing) {
      _completeDrawing();
      return;
    }

    if (_session.stage == StoryCardEditorStage.camera) {
      if (_draft.scene.cardType.isFourCut) {
        setState(() {
          _session = _session.returnToFourCutAssembly();
        });
      } else {
        _returnToFormatSelection();
      }
      return;
    }

    if (_session.stage == StoryCardEditorStage.assembling &&
        !_session.hasUnsavedChanges) {
      _returnToFormatSelection();
      return;
    }

    if (_session.stage == StoryCardEditorStage.decorating &&
        _draft.scene.cardType.isFourCut &&
        !_session.hasPersistedCard) {
      setState(() {
        _session = _session.returnToFourCutAssembly();
      });
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

    final shouldDiscard = await showAppConfirmationDialog(
      context: context,
      title: '수정 내용을 버릴까요?',
      message: '저장하지 않은 변경 내용이 사라져요.',
      confirmLabel: '버리기',
      cancelLabel: '계속 수정',
    );
    if (!shouldDiscard || !mounted) {
      return;
    }

    await _discardUnsavedChanges();
  }

  void _returnToCamera() {
    _cameraFilm = _draft.scene.film.seed > 0 ? _draft.scene.film : _cameraFilm;
    final previousImages = _backgroundImages;
    setState(() {
      _backgroundImages = const [null];
      _session = _session.returnToCamera();
    });
    _disposeImages(previousImages);
  }

  void _returnToFormatSelection() {
    final previousImages = _backgroundImages;
    setState(() {
      _backgroundImages = const [null];
      _selectedPhotoIndex = 0;
      _session = _session.discardChanges();
    });
    _disposeImages(previousImages);
  }

  Future<void> _discardUnsavedChanges() async {
    final nextSession = _session.discardChanges();
    late final List<ui.Image?> nextBackgroundImages;
    try {
      nextBackgroundImages = await _decodeUiImages(
        nextSession.draft.photoImageBytes,
      );
    } catch (_) {
      if (mounted) {
        _showSnackBar('기존 사진을 불러오지 못했어요.');
      }
      return;
    }
    if (!mounted) {
      _disposeImages(nextBackgroundImages);
      return;
    }

    final previousImages = _backgroundImages;
    setState(() {
      _backgroundImages = nextBackgroundImages;
      _selectedPhotoIndex = 0;
      _activeStroke = null;
      _activePointer = null;
      _session = nextSession;
      _cameraFilm = nextSession.draft.scene.film.seed > 0
          ? nextSession.draft.scene.film
          : _cameraFilm;
    });
    _disposeImages(previousImages);
  }

  void _selectCardType(StoryCardType cardType) {
    final previousImages = _backgroundImages;
    setState(() {
      _session = _session.selectCardType(cardType);
      _backgroundImages = List<ui.Image?>.filled(
        cardType.requiredPhotoCount,
        null,
        growable: false,
      );
      _selectedPhotoIndex = 0;
    });
    _disposeImages(previousImages);
  }

  void _selectPhotoSlot(int index) {
    if (index < 0 || index >= _draft.scene.cardType.requiredPhotoCount) {
      return;
    }
    setState(() => _selectedPhotoIndex = index);
  }

  void _openFourCutCamera() {
    if (!_draft.scene.cardType.isFourCut || _isPickingGallery) {
      return;
    }
    setState(() {
      _session = _session.enterFourCutCamera();
    });
  }

  void _continueToFourCutDecorator() {
    if (!_draft.hasAllRequiredPhotos) {
      return;
    }
    setState(() {
      _session = _session.enterFourCutDecorator();
    });
  }

  Future<void> _pickFourCutGallery() async {
    if (!_draft.scene.cardType.isFourCut || _isPickingGallery || _isSaving) {
      return;
    }

    final currentPhotos = _draft.photoImageBytes;
    final targetIndices = <int>[
      _selectedPhotoIndex,
      for (var index = 0; index < currentPhotos.length; index++)
        if (index != _selectedPhotoIndex && currentPhotos[index] == null) index,
    ];

    setState(() => _isPickingGallery = true);
    try {
      final pickedImages = await _galleryPicker.pickNormalizedImages(
        limit: targetIndices.length,
      );
      if (!mounted || pickedImages.isEmpty) {
        return;
      }

      final decodedImages = await _decodeUiImages(pickedImages);
      if (!mounted) {
        _disposeImages(decodedImages);
        return;
      }

      var nextSession = _session;
      final nextBackgroundImages = [..._backgroundImages];
      final replacedImages = <ui.Image?>[];
      for (var offset = 0; offset < pickedImages.length; offset++) {
        final targetIndex = targetIndices[offset];
        replacedImages.add(nextBackgroundImages[targetIndex]);
        nextBackgroundImages[targetIndex] = decodedImages[offset];
        nextSession = nextSession.setPhoto(targetIndex, pickedImages[offset]);
      }
      final nextEmptyIndex = nextSession.draft.photoImageBytes.indexWhere(
        (photo) => photo == null,
      );

      setState(() {
        _session = nextSession;
        _backgroundImages = nextBackgroundImages;
        _selectedPhotoIndex = nextEmptyIndex >= 0
            ? nextEmptyIndex
            : targetIndices[pickedImages.length - 1];
      });
      _disposeImages(replacedImages);
    } catch (_) {
      if (mounted) {
        _showSnackBar('사진을 불러오지 못했어요.');
      }
    } finally {
      if (mounted) {
        setState(() => _isPickingGallery = false);
      }
    }
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
      _session = _session.undoLastStroke();
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

  Future<Color?> _enterColorSampler() async {
    if (_session.tool != StoryCardEditorTool.drawing ||
        _activePointer != null ||
        _isPickingColor) {
      return null;
    }
    setState(() => _isPickingColor = true);
    final color = await showAppCanvasColorPicker(
      context: context,
      canvasKey: _previewKey,
      backgroundColor: Colors.black,
      keyPrefix: 'story-card-drawing',
      canOpen: () => mounted && _isPickingColor,
    );
    if (!mounted) return null;
    setState(() => _isPickingColor = false);
    return color;
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
    setState(() {
      _session = _session.toggleCanvasBackground();
    });
  }

  void _toggleFilmSelector() {
    final nextTool = _session.tool == StoryCardEditorTool.film
        ? StoryCardEditorTool.background
        : StoryCardEditorTool.film;
    setState(() {
      _session = _session.selectTool(nextTool);
    });
    if (nextTool == StoryCardEditorTool.film) {
      unawaited(_prepareFilmProgram());
    }
  }

  void _selectFilmLook(StoryCardFilmLook look) {
    final currentFilm = _draft.scene.film;
    final nextFilm = currentFilm.copyWith(
      look: look,
      seed: currentFilm.seed > 0 ? currentFilm.seed : StoryCardFilmSeed.now(),
    );
    setState(() {
      _session = _session.setFilm(nextFilm);
      _cameraFilm = nextFilm;
    });
    if (look != StoryCardFilmLook.original) {
      unawaited(_prepareFilmProgram());
    }
  }

  void _enterBlankDecorator(StoryCardEditorTool tool) {
    final previousImages = _backgroundImages;
    setState(() {
      _backgroundImages = const [null];
      _session = _session.enterBlankDecorator(tool: tool);
    });
    _disposeImages(previousImages);
  }

  void _enterBlankTextDecorator() {
    final previousImages = _backgroundImages;
    setState(() {
      _backgroundImages = const [null];
      _session = _session.enterBlankDecorator(
        tool: StoryCardEditorTool.text,
        background: StoryCardCanvasBackground.black,
      );
      _isTextInputActive = true;
    });
    _disposeImages(previousImages);
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
      _session = _session.setCaption(nextCaption).selectTool(nextTool);
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
      _session = _session
          .addTextLayer(
            StoryCardTextLayer(
              id: const Uuid().v4(),
              text: text,
              x: 0.5,
              y: 0.5,
              color: color,
            ),
          )
          .selectTool(StoryCardEditorTool.none);
    });
  }

  Future<void> _useBackgroundImage(StoryCardCameraSelection selection) async {
    if (_isSaving) {
      return;
    }

    try {
      final normalizedImageBytes = await const StoryCardImageNormalizer()
          .normalize(
            selection.imageBytes,
            characterComposition: selection.characterComposition,
          );
      if (!mounted) {
        return;
      }

      final backgroundImage = await _decodeUiImage(normalizedImageBytes);
      if (!mounted) {
        backgroundImage.dispose();
        return;
      }

      final previousImages = _backgroundImages;
      if (_draft.scene.cardType.isFourCut) {
        final selectedPhotoIndex = _selectedPhotoIndex;
        final nextImages = [..._backgroundImages];
        nextImages[selectedPhotoIndex] = backgroundImage;
        setState(() {
          _backgroundImages = nextImages;
          _session = _session
              .setPhoto(selectedPhotoIndex, normalizedImageBytes)
              .returnToFourCutAssembly();
          final nextEmptyIndex = _draft.photoImageBytes.indexWhere(
            (photo) => photo == null,
          );
          if (nextEmptyIndex >= 0) {
            _selectedPhotoIndex = nextEmptyIndex;
          }
        });
        previousImages[selectedPhotoIndex]?.dispose();
      } else {
        setState(() {
          _backgroundImages = [backgroundImage];
          _cameraFilm = selection.film;
          _session = _session.enterPhotoDecorator(
            normalizedImageBytes,
            film: selection.film,
          );
        });
        _disposeImages(previousImages);
        if (selection.film.look != StoryCardFilmLook.original) {
          unawaited(_prepareFilmProgram());
        }
      }
    } catch (_) {
      if (mounted) {
        _showSnackBar('사진을 불러오지 못했어요.');
      }
    }
  }

  Future<Uint8List?> _loadCoupleCharacterImage() async {
    final character = await ref.read(coupleCharacterControllerProvider.future);
    if (character == null) {
      return null;
    }
    return ref
        .read(coupleCharacterControllerProvider.notifier)
        .fetchImageBytes(character);
  }

  Future<void> _loadBackgroundImages(List<Uint8List?> bytes) async {
    if (bytes.every((imageBytes) => imageBytes == null)) {
      return;
    }

    try {
      final decoded = await _decodeUiImages(bytes);
      if (!mounted) {
        _disposeImages(decoded);
        return;
      }

      final previousImages = _backgroundImages;
      setState(() {
        _backgroundImages = decoded;
      });
      _disposeImages(previousImages);
    } catch (_) {
      if (mounted) {
        _showSnackBar('기존 사진을 불러오지 못했어요.');
      }
    }
  }

  Future<List<ui.Image?>> _decodeUiImages(
    Iterable<Uint8List?> imageBytes,
  ) async {
    final decodedImages = <ui.Image?>[];
    try {
      for (final bytes in imageBytes) {
        decodedImages.add(bytes == null ? null : await _decodeUiImage(bytes));
      }
      return decodedImages;
    } catch (_) {
      _disposeImages(decodedImages);
      rethrow;
    }
  }

  void _disposeImages(Iterable<ui.Image?> images) {
    for (final image in images) {
      image?.dispose();
    }
  }

  Future<ui.Image> _decodeUiImage(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    codec.dispose();
    return frame.image;
  }

  Future<ui.FragmentProgram> _ensureFilmProgram() {
    final currentProgram = _filmProgram;
    if (currentProgram != null) {
      return Future.value(currentProgram);
    }

    return _filmProgramFuture ??= StoryCardFilmShaderProgram.load().then((
      program,
    ) {
      _filmProgram = program;
      if (mounted) {
        setState(() {});
      }
      return program;
    });
  }

  Future<void> _prepareFilmProgram() async {
    try {
      await _ensureFilmProgram();
    } catch (_) {
      if (mounted) {
        _showSnackBar('필름 효과를 준비하지 못했어요.');
      }
    }
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
        _session = _session.appendStroke(activeStroke);
      }
    });
  }

  void _startBackgroundTransform(int photoIndex, ScaleStartDetails details) {
    if (photoIndex < 0 || photoIndex >= _draft.scene.photoTransforms.length) {
      return;
    }
    final transform = _draft.scene.photoTransforms[photoIndex];
    _backgroundTransformPhotoIndex = photoIndex;
    _backgroundScaleStart = transform.scale;
    _backgroundOffsetStart = Offset(transform.offsetX, transform.offsetY);
    _backgroundFocalPointStart = details.localFocalPoint;
  }

  void _updateBackgroundTransform(
    int photoIndex,
    ScaleUpdateDetails details,
    Size size,
  ) {
    if (_backgroundTransformPhotoIndex != photoIndex ||
        photoIndex < 0 ||
        photoIndex >= _backgroundImages.length) {
      return;
    }
    final image = _backgroundImages[photoIndex];
    if (image == null || size.isEmpty) {
      return;
    }

    final layout = StoryCardLayout.fromSize(
      type: _draft.scene.cardType,
      size: size,
    );
    final photoRect = layout.photoRects[photoIndex];
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
      _session = _session.setPhotoTransform(
        photoIndex,
        StoryCardBackgroundTransform(
          scale: scale,
          offsetX: offset.dx,
          offsetY: offset.dy,
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
      final layer = _draft.scene.textLayers.firstWhere(
        (layer) => layer.id == layerId,
      );
      _session = _session.replaceTextLayer(
        layer.copyWith(x: x, y: y, scale: scale, rotation: rotation),
      );
    });
  }

  void _endTextLayerTransform() {
    final layerId = _textLayerTransformStart?.id;
    final shouldDelete = _isTextOverTrash && layerId != null;
    setState(() {
      if (shouldDelete) {
        _session = _session.removeTextLayer(layerId);
      }
      _textLayerTransformStart = null;
      _backgroundTransformPhotoIndex = null;
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
    if (_draft.scene.film.look != StoryCardFilmLook.original &&
        _filmProgram == null) {
      await _ensureFilmProgram();
    }
    await WidgetsBinding.instance.endOfFrame;
    final renderObject = _previewKey.currentContext?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) {
      throw StateError('Story card preview boundary is unavailable.');
    }

    if (renderObject.size.width <= 0) {
      throw StateError('Story card preview boundary has an invalid size.');
    }
    final pixelRatio =
        _draft.scene.cardType.previewSize.width / renderObject.size.width;
    final image = await renderObject.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (byteData == null) {
      throw StateError('Story card preview export failed.');
    }

    return byteData.buffer.asUint8List();
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
        StoryLoopWriteFailureReason.invalidCardFormat =>
          '네 장의 사진을 모두 채운 뒤 다시 시도해 주세요.',
        StoryLoopWriteFailureReason.invalidTextContent =>
          '텍스트 개수 또는 글자 수를 확인해 주세요.',
        StoryLoopWriteFailureReason.cardLocked =>
          '올린 카드는 수정할 수 없어요. 새 카드로 올려 주세요.',
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
