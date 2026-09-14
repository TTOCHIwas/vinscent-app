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
import '../../../core/presentation/widgets/app_hsv_color_picker_sheet.dart';
import '../../characters/application/couple_character_controller.dart';
import '../application/story_card_camera_selection.dart';
import '../application/story_card_editor_controller.dart';
import '../application/story_card_editor_session.dart';
import '../application/story_card_film_shader.dart';
import '../application/story_card_gallery_picker.dart';
import '../application/story_card_image_normalizer.dart';
import '../application/story_card_local_draft_repository.dart';
import '../data/story_card_draft.dart';
import '../data/story_card_film_look.dart';
import '../data/story_card_scene.dart';
import '../data/story_card_type.dart';
import '../data/story_loop_write_failure.dart';
import 'widgets/story_card_camera_stage.dart';
import 'widgets/story_card_appearance_picker.dart';
import 'widgets/story_card_draft_exit_dialog.dart';
import 'widgets/story_card_drawing_controls.dart';
import 'widgets/story_card_editor_action_bar.dart';
import 'widgets/story_card_editor_canvas.dart';
import 'widgets/story_card_editor_header.dart';
import 'widgets/story_card_film_look_selector.dart';
import 'widgets/story_card_interactive_viewport.dart';
import 'widgets/story_card_local_draft_sheet.dart';
import 'widgets/story_card_photo_adjustment_screen.dart';
import 'widgets/story_card_photo_slot_controls.dart';
import 'widgets/story_card_text_input_overlay.dart';
import 'widgets/story_card_text_trash_target.dart';

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
  final _viewportController = StoryCardViewportController();

  late StoryCardEditorSession _session;
  late List<ui.Image?> _backgroundImages;
  StoryCardStroke? _activeStroke;
  StoryCardDrawingTool _selectedDrawingTool = StoryCardDrawingTool.pen;
  Color _selectedColor = storyCardColorPalette.first;
  double _selectedStrokeWidth = storyCardNormalStrokeWidth;
  int? _activePointer;
  int _selectedPhotoIndex = 0;
  int? _selectedEmptyPhotoIndex;
  int? _cameraTargetPhotoIndex;
  StoryCardTextLayer? _textLayerTransformStart;
  Offset _textLayerFocalPointStart = Offset.zero;
  bool _isTextInputActive = false;
  bool _isDraggingText = false;
  bool _isTextOverTrash = false;
  bool _isPickingColor = false;
  bool _isPickingGallery = false;
  bool _isSaving = false;
  bool _isSavingLocalDraft = false;
  bool _isLocalDraftActive = false;
  List<StoryCardLocalDraftSummary> _localDrafts = const [];
  bool _isCardTypeSelectorVisible = false;
  bool _isCardTypeGuideMounted = false;
  bool _isCardTypeGuideVisible = false;
  bool _isInitialCardTypeSelectorPinned = false;
  bool _hasShownCardTypeOnboarding = false;
  Timer? _cardTypeSelectorHideTimer;
  Timer? _cardTypeGuideFadeTimer;
  Timer? _cardTypeGuideRemovalTimer;
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
    _backgroundImages = List<ui.Image?>.filled(4, null, growable: false);
    unawaited(_loadBackgroundImages(_draft.storedPhotoImageBytes));
    unawaited(_refreshLocalDrafts());
    if (_draft.scene.photoFilms.any(
      (film) => film.look != StoryCardFilmLook.original,
    )) {
      unawaited(_prepareFilmProgram());
    }
    if (!_session.hasPersistedCard &&
        _session.stage == StoryCardEditorStage.decorating &&
        _draft.hasDraftContent) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showCardTypeOnboarding();
      });
    }
  }

  @override
  void dispose() {
    _cardTypeSelectorHideTimer?.cancel();
    _cardTypeGuideFadeTimer?.cancel();
    _cardTypeGuideRemovalTimer?.cancel();
    _viewportController.dispose();
    _disposeImages(_backgroundImages);
    super.dispose();
  }

  StoryCardDraft get _draft => _session.draft;

  List<StoryCardStroke> get _visibleStrokes {
    return [..._draft.scene.strokes, ?_activeStroke];
  }

  bool get _canSave =>
      !_isTextInputActive &&
      !_isPickingColor &&
      !_isPickingGallery &&
      !_isSaving &&
      !_isSavingLocalDraft &&
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
        StoryCardEditorStage.formatSelection ||
        StoryCardEditorStage.camera => _buildCameraStage(),
        StoryCardEditorStage.assembling ||
        StoryCardEditorStage.decorating => _buildDecorator(),
      },
    );
  }

  Widget _buildCameraStage() {
    final targetIndex = _cameraTargetPhotoIndex;
    final guideAspectRatio = targetIndex == null
        ? null
        : StoryCardLayout.fromSize(
            type: _draft.scene.cardType,
            size: _draft.scene.cardType.previewSize,
          ).photoAspectRatio(targetIndex);
    return StoryCardCameraStage(
      onBack: _handleBack,
      onImageSelected: _useBackgroundImage,
      initialFilm: _cameraFilm,
      onFilmChanged: (film) => _cameraFilm = film,
      initialCardType: _draft.scene.cardType,
      onCardTypeChanged: targetIndex == null ? _selectCameraCardType : null,
      loadCharacterImage: _loadCoupleCharacterImage,
      onTextSelected: _enterBlankTextDecorator,
      onDrawingSelected: () =>
          _enterBlankDecorator(StoryCardEditorTool.drawing),
      showEditorTools: targetIndex == null,
      showGalleryButton: targetIndex == null,
      guideAspectRatio: guideAspectRatio,
      draftCount: _localDrafts.length,
      onDraftsPressed: targetIndex == null
          ? () => unawaited(_showLocalDrafts())
          : null,
    );
  }

  Widget _buildDecorator() {
    final content = ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRect(
            child: SafeArea(
              child: Padding(
                padding: storyCardEditorViewportInsets,
                child: StoryCardInteractiveViewport(
                  controller: _viewportController,
                  aspectRatio: _draft.scene.cardType.canvasAspectRatio,
                  clipContent: false,
                  builder: (context, contentSize, viewportGestures) => Stack(
                    key: const ValueKey('story-card-editor-canvas'),
                    fit: StackFit.expand,
                    children: [
                      RepaintBoundary(
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
                          onStrokeCancel: _cancelStroke,
                          onPhotoTapped: _handlePhotoTapped,
                          onPhotosReordered: _reorderPhotos,
                          onCardTypeStep: _stepCardType,
                          onCanvasTapped: _handleCanvasTapped,
                          onTextLayerScaleStart: _startTextLayerTransform,
                          onTextLayerScaleUpdate: _updateTextLayerTransform,
                          onTextLayerScaleEnd: _endTextLayerTransform,
                          viewportGestures: viewportGestures,
                        ),
                      ),
                      if (_session.tool != StoryCardEditorTool.drawing &&
                          !_isTextInputActive)
                        StoryCardPhotoSlotControls(
                          cardType: _draft.scene.cardType,
                          hasPhotos: _draft.photoImageBytes
                              .map((bytes) => bytes != null)
                              .toList(growable: false),
                          selectedEmptyIndex: _selectedEmptyPhotoIndex,
                          isPickingGallery: _isPickingGallery,
                          onCameraPressed: _openPhotoSlotCamera,
                          onGalleryPressed: (index) =>
                              unawaited(_pickPhotoForSlot(index)),
                        ),
                    ],
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
                    cardType: _draft.scene.cardType,
                    onAddTextPressed: _selectTextTool,
                    onDrawingModePressed: () =>
                        _selectTool(StoryCardEditorTool.drawing),
                    onFilmPressed: _selectedPhotoBytes == null
                        ? null
                        : _toggleFilmSelector,
                    onCardTypePressed: _toggleCardTypeSelector,
                    isFilmSelected: _session.tool == StoryCardEditorTool.film,
                    isCardTypeSelected: _isCardTypeSelectorVisible,
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
                    selectedLook: _selectedPhotoFilm.look,
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
                  cardAspectRatio: _draft.scene.cardType.canvasAspectRatio,
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
          if (_session.tool != StoryCardEditorTool.drawing)
            Positioned(
              left: 12,
              right: 12,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AnimatedSlide(
                    key: const ValueKey(
                      'story-card-editor-type-selector-slide',
                    ),
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    offset: _isCardTypeSelectorVisible
                        ? Offset.zero
                        : const Offset(0, 1.3),
                    child: IgnorePointer(
                      ignoring: !_isCardTypeSelectorVisible,
                      child: StoryCardAppearancePicker(
                        key: const ValueKey('story-card-editor-type-selector'),
                        selectedType: _draft.scene.cardType,
                        selectedBackgroundColor:
                            _draft.scene.appearance.backgroundColor,
                        onTypeSelected: _selectCardType,
                        onBackgroundColorSelected: _selectCardBackgroundColor,
                        onCustomColorPressed: () =>
                            unawaited(_selectCustomCardBackgroundColor()),
                        typeKeyPrefix: 'story-card-editor-type',
                        backgroundKeyPrefix: 'story-card-editor-background',
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (_isCardTypeGuideMounted)
            Positioned.fill(
              child: IgnorePointer(
                key: const ValueKey('story-card-editor-type-guide'),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  opacity: _isCardTypeGuideVisible ? 1 : 0,
                  child: Center(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xB3000000),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        child: Text(
                          '좌우로 밀어 카드 유형을 바꿔보세요.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) {
        if (_isCardTypeGuideMounted) {
          _dismissCardTypeGuide();
        }
      },
      child: content,
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
    if (_isCardTypeGuideMounted) {
      _dismissCardTypeGuide();
      return;
    }
    if (_isCardTypeSelectorVisible) {
      _hideCardTypeSelector();
      return;
    }

    if (_isSaving || _isSavingLocalDraft) {
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
      if (_cameraTargetPhotoIndex != null) {
        setState(() {
          _cameraTargetPhotoIndex = null;
          _session = _session.returnToDecorator();
        });
      } else {
        context.go('/home');
      }
      return;
    }

    if (!_session.hasUnsavedChanges && !_isLocalDraftActive) {
      context.go('/home');
      return;
    }

    if (!_session.hasPersistedCard) {
      final action = await showStoryCardDraftExitDialog(context: context);
      if (!mounted || action == null) {
        return;
      }
      switch (action) {
        case StoryCardDraftExitAction.saveDraft:
          await _saveLocalDraft();
          return;
        case StoryCardDraftExitAction.discard:
          context.go('/home');
          return;
        case StoryCardDraftExitAction.continueEditing:
          return;
      }
    }

    if (!mounted) {
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

  Future<void> _discardUnsavedChanges() async {
    final nextSession = _session.discardChanges();
    late final List<ui.Image?> nextBackgroundImages;
    try {
      nextBackgroundImages = await _decodeUiImages(
        _paddedPhotoBytes(nextSession.draft.storedPhotoImageBytes),
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
      _selectedEmptyPhotoIndex = null;
      _activeStroke = null;
      _activePointer = null;
      _session = nextSession;
      _cameraFilm = nextSession.draft.scene.film.seed > 0
          ? nextSession.draft.scene.film
          : _cameraFilm;
    });
    _disposeImages(previousImages);
  }

  Uint8List? get _selectedPhotoBytes {
    final photos = _draft.photoImageBytes;
    return _selectedPhotoIndex >= 0 && _selectedPhotoIndex < photos.length
        ? photos[_selectedPhotoIndex]
        : null;
  }

  StoryCardFilmState get _selectedPhotoFilm {
    final films = _draft.scene.photoFilms;
    return _selectedPhotoIndex >= 0 && _selectedPhotoIndex < films.length
        ? films[_selectedPhotoIndex]
        : const StoryCardFilmState.original();
  }

  void _selectEmptyPhotoSlot(int index) {
    if (index < 0 || index >= _draft.scene.cardType.requiredPhotoCount) {
      return;
    }
    setState(() {
      _selectedPhotoIndex = index;
      _selectedEmptyPhotoIndex = index;
      _session = _session.selectTool(StoryCardEditorTool.background);
    });
  }

  void _handlePhotoTapped(int index) {
    final photos = _draft.photoImageBytes;
    if (index < 0 || index >= photos.length) {
      return;
    }
    if (photos[index] == null) {
      _selectEmptyPhotoSlot(index);
      return;
    }
    unawaited(_openPhotoAdjustment(index));
  }

  bool _handleCanvasTapped() {
    if (_isCardTypeGuideMounted) {
      _dismissCardTypeGuide();
      return true;
    }
    if (_isCardTypeSelectorVisible) {
      _hideCardTypeSelector();
      return true;
    }
    return false;
  }

  void _openPhotoSlotCamera(int index) {
    if (_isPickingGallery ||
        index < 0 ||
        index >= _draft.scene.cardType.requiredPhotoCount) {
      return;
    }
    final film = _draft.scene.photoFilms[index];
    setState(() {
      _selectedPhotoIndex = index;
      _selectedEmptyPhotoIndex = null;
      _cameraTargetPhotoIndex = index;
      _cameraFilm = film.seed > 0
          ? film
          : film.copyWith(seed: StoryCardFilmSeed.now());
      _session = _session.enterPhotoCamera();
    });
  }

  Future<void> _pickPhotoForSlot(int index) async {
    if (_isPickingGallery ||
        _isSaving ||
        index < 0 ||
        index >= _draft.scene.cardType.requiredPhotoCount) {
      return;
    }

    setState(() => _isPickingGallery = true);
    try {
      final pickedImages = await _galleryPicker.pickNormalizedImages(limit: 1);
      if (!mounted || pickedImages.isEmpty) {
        return;
      }
      final bytes = pickedImages.single;
      final decoded = await _decodeUiImage(bytes);
      if (!mounted) {
        decoded.dispose();
        return;
      }
      final nextBackgroundImages = [..._backgroundImages];
      final replacedImage = nextBackgroundImages[index];
      nextBackgroundImages[index] = decoded;
      setState(() {
        _session = _session.setPhoto(index, bytes);
        _backgroundImages = nextBackgroundImages;
        _selectedPhotoIndex = index;
        _selectedEmptyPhotoIndex = null;
      });
      replacedImage?.dispose();
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

  Future<void> _openPhotoAdjustment(int index) async {
    final photos = _draft.photoImageBytes;
    if (index < 0 || index >= photos.length || photos[index] == null) {
      return;
    }
    setState(() {
      _selectedPhotoIndex = index;
      _selectedEmptyPhotoIndex = null;
      _session = _session.selectTool(StoryCardEditorTool.background);
    });
    final layout = StoryCardLayout.fromSize(
      type: _draft.scene.cardType,
      size: _draft.scene.cardType.previewSize,
    );
    final result = await Navigator.of(context).push<_PhotoAdjustmentResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (routeContext) => StoryCardPhotoAdjustmentScreen(
          imageBytes: photos[index]!,
          cropAspectRatio: layout.photoAspectRatio(index),
          initialTransform: _draft.scene.photoTransforms[index],
          initialFilm: _draft.scene.photoFilms[index],
          onBack: () => Navigator.of(routeContext).pop(),
          onDone: (transform, film) => Navigator.of(routeContext).pop(
            _PhotoAdjustmentResult.updated(transform: transform, film: film),
          ),
          onRemove: () => Navigator.of(
            routeContext,
          ).pop(const _PhotoAdjustmentResult.removed()),
        ),
      ),
    );
    if (!mounted || result == null) {
      return;
    }
    if (result.removed) {
      final previousImage = _backgroundImages[index];
      final nextImages = [..._backgroundImages]..[index] = null;
      setState(() {
        _backgroundImages = nextImages;
        _session = _session.removePhoto(index);
        _selectedEmptyPhotoIndex = index;
      });
      previousImage?.dispose();
      return;
    }
    setState(() {
      _session = _session
          .setPhotoTransform(index, result.transform!)
          .setPhotoFilm(index, result.film!);
    });
    if (result.film!.look != StoryCardFilmLook.original) {
      unawaited(_prepareFilmProgram());
    }
  }

  void _reorderPhotos(int fromIndex, int toIndex) {
    if (!_draft.scene.cardType.isFourCut ||
        fromIndex < 0 ||
        toIndex < 0 ||
        fromIndex >= _draft.scene.cardType.requiredPhotoCount ||
        toIndex >= _draft.scene.cardType.requiredPhotoCount) {
      return;
    }
    final nextImages = [..._backgroundImages];
    final moved = nextImages[fromIndex];
    nextImages[fromIndex] = nextImages[toIndex];
    nextImages[toIndex] = moved;
    setState(() {
      _backgroundImages = nextImages;
      _session = _session.reorderPhotos(fromIndex, toIndex);
      _selectedPhotoIndex = toIndex;
      _selectedEmptyPhotoIndex = null;
    });
  }

  void _stepCardType(int step) {
    if (_session.tool == StoryCardEditorTool.drawing ||
        _viewportController.isZoomed ||
        step == 0) {
      return;
    }
    final types = StoryCardType.editorOrder;
    final currentIndex = types.indexOf(_draft.scene.cardType);
    final nextIndex = (currentIndex + step).clamp(0, types.length - 1);
    if (nextIndex == currentIndex) {
      return;
    }
    _selectCardType(types[nextIndex]);
  }

  void _selectCameraCardType(StoryCardType type) {
    if (_cameraTargetPhotoIndex != null || type == _draft.scene.cardType) {
      return;
    }
    _viewportController.reset();
    setState(() {
      _session = _session.changeCardType(type);
      _selectedPhotoIndex = 0;
      _selectedEmptyPhotoIndex = null;
    });
  }

  void _selectCardType(StoryCardType type) {
    _cardTypeSelectorHideTimer?.cancel();
    if (type != _draft.scene.cardType) {
      _viewportController.reset();
    }
    setState(() {
      if (type != _draft.scene.cardType) {
        _session = _session.changeCardType(type);
        _selectedPhotoIndex = 0;
        _selectedEmptyPhotoIndex = null;
      }
      _isCardTypeSelectorVisible = true;
      _isInitialCardTypeSelectorPinned = false;
    });
    _scheduleCardTypeSelectorHide();
  }

  void _toggleCardTypeSelector() {
    if (_isCardTypeSelectorVisible) {
      _hideCardTypeSelector();
      return;
    }

    _cardTypeSelectorHideTimer?.cancel();
    setState(() {
      _session = _session.selectTool(
        _draft.hasPhoto
            ? StoryCardEditorTool.background
            : StoryCardEditorTool.none,
      );
      _isCardTypeSelectorVisible = true;
      _isInitialCardTypeSelectorPinned = false;
    });
    _scheduleCardTypeSelectorHide();
  }

  void _hideCardTypeSelector() {
    _cardTypeSelectorHideTimer?.cancel();
    if (!_isCardTypeSelectorVisible) {
      return;
    }
    setState(() {
      _isCardTypeSelectorVisible = false;
      _isInitialCardTypeSelectorPinned = false;
    });
  }

  void _scheduleCardTypeSelectorHide() {
    _cardTypeSelectorHideTimer?.cancel();
    _cardTypeSelectorHideTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted || _isInitialCardTypeSelectorPinned) {
        return;
      }
      _hideCardTypeSelector();
    });
  }

  void _showCardTypeOnboarding() {
    if (!mounted ||
        _hasShownCardTypeOnboarding ||
        _session.hasPersistedCard ||
        _session.stage != StoryCardEditorStage.decorating ||
        !_draft.hasDraftContent) {
      return;
    }

    _cardTypeSelectorHideTimer?.cancel();
    _cardTypeGuideFadeTimer?.cancel();
    _cardTypeGuideRemovalTimer?.cancel();
    setState(() {
      _hasShownCardTypeOnboarding = true;
      _isCardTypeSelectorVisible = true;
      _isInitialCardTypeSelectorPinned = true;
      _isCardTypeGuideMounted = true;
      _isCardTypeGuideVisible = true;
    });
    _cardTypeGuideFadeTimer = Timer(
      const Duration(seconds: 2),
      _dismissCardTypeGuide,
    );
  }

  void _dismissCardTypeGuide() {
    _cardTypeGuideFadeTimer?.cancel();
    if (!mounted || !_isCardTypeGuideMounted) {
      return;
    }
    setState(() => _isCardTypeGuideVisible = false);
    _cardTypeGuideRemovalTimer?.cancel();
    _cardTypeGuideRemovalTimer = Timer(const Duration(milliseconds: 220), () {
      if (mounted) {
        setState(() => _isCardTypeGuideMounted = false);
      }
    });
  }

  void _selectTool(StoryCardEditorTool tool) {
    _cardTypeSelectorHideTimer?.cancel();
    setState(() {
      _isCardTypeSelectorVisible = false;
      _isInitialCardTypeSelectorPinned = false;
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
    _showCardTypeOnboarding();
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

    _cardTypeSelectorHideTimer?.cancel();
    setState(() {
      _isCardTypeSelectorVisible = false;
      _isInitialCardTypeSelectorPinned = false;
      _session = _session.selectTool(StoryCardEditorTool.text);
      _isTextInputActive = true;
    });
  }

  void _selectCardBackgroundColor(Color color) {
    _cardTypeSelectorHideTimer?.cancel();
    setState(() {
      _session = _session.setCardBackgroundColor(color);
      _isCardTypeSelectorVisible = true;
      _isInitialCardTypeSelectorPinned = false;
    });
    _scheduleCardTypeSelectorHide();
  }

  Future<void> _selectCustomCardBackgroundColor() async {
    _cardTypeSelectorHideTimer?.cancel();
    final selectedColor = await showAppHsvColorPickerSheet(
      context: context,
      initialColor: _draft.scene.appearance.backgroundColor,
    );
    if (!mounted) {
      return;
    }
    if (selectedColor != null) {
      setState(() {
        _session = _session.setCardBackgroundColor(selectedColor);
        _isCardTypeSelectorVisible = true;
        _isInitialCardTypeSelectorPinned = false;
      });
    }
    if (_isCardTypeSelectorVisible) {
      _scheduleCardTypeSelectorHide();
    }
  }

  void _toggleFilmSelector() {
    final nextTool = _session.tool == StoryCardEditorTool.film
        ? StoryCardEditorTool.background
        : StoryCardEditorTool.film;
    _cardTypeSelectorHideTimer?.cancel();
    setState(() {
      _isCardTypeSelectorVisible = false;
      _isInitialCardTypeSelectorPinned = false;
      _session = _session.selectTool(nextTool);
    });
    if (nextTool == StoryCardEditorTool.film) {
      unawaited(_prepareFilmProgram());
    }
  }

  void _selectFilmLook(StoryCardFilmLook look) {
    if (_selectedPhotoBytes == null) {
      return;
    }
    final currentFilm = _selectedPhotoFilm;
    final nextFilm = currentFilm.copyWith(
      look: look,
      seed: currentFilm.seed > 0 ? currentFilm.seed : StoryCardFilmSeed.now(),
    );
    setState(() {
      _session = _session.setPhotoFilm(_selectedPhotoIndex, nextFilm);
      _cameraFilm = nextFilm;
    });
    if (look != StoryCardFilmLook.original) {
      unawaited(_prepareFilmProgram());
    }
  }

  void _enterBlankDecorator(StoryCardEditorTool tool) {
    final previousImages = _backgroundImages;
    setState(() {
      _backgroundImages = List<ui.Image?>.filled(4, null, growable: false);
      _session = _session.enterBlankDecorator(tool: tool);
    });
    _disposeImages(previousImages);
  }

  void _enterBlankTextDecorator() {
    final previousImages = _backgroundImages;
    setState(() {
      _backgroundImages = List<ui.Image?>.filled(4, null, growable: false);
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
    _showCardTypeOnboarding();
  }

  Future<void> _useBackgroundImage(StoryCardCameraSelection selection) async {
    if (_isSaving || _isSavingLocalDraft) {
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

      final targetIndex = _cameraTargetPhotoIndex;
      if (targetIndex != null) {
        final nextImages = [..._backgroundImages];
        final replacedImage = nextImages[targetIndex];
        nextImages[targetIndex] = backgroundImage;
        setState(() {
          _backgroundImages = nextImages;
          _session = _session
              .setPhoto(targetIndex, normalizedImageBytes)
              .setPhotoFilm(targetIndex, selection.film)
              .returnToDecorator();
          _selectedPhotoIndex = targetIndex;
          _selectedEmptyPhotoIndex = null;
          _cameraTargetPhotoIndex = null;
          _cameraFilm = selection.film;
        });
        replacedImage?.dispose();
      } else {
        final previousImages = _backgroundImages;
        final nextImages = List<ui.Image?>.filled(4, null, growable: false)
          ..[0] = backgroundImage;
        setState(() {
          _backgroundImages = nextImages;
          _cameraFilm = selection.film;
          _session = _session
              .changeCardType(selection.cardType)
              .enterPhotoDecorator(normalizedImageBytes, film: selection.film);
          _selectedPhotoIndex = 0;
          _selectedEmptyPhotoIndex = null;
        });
        _disposeImages(previousImages);
        _showCardTypeOnboarding();
      }
      if (selection.film.look != StoryCardFilmLook.original) {
        unawaited(_prepareFilmProgram());
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

  Future<void> _refreshLocalDrafts() async {
    try {
      final drafts = await ref
          .read(storyCardLocalDraftRepositoryProvider)
          .list();
      if (mounted) {
        setState(() => _localDrafts = drafts);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _localDrafts = const []);
      }
    }
  }

  Future<void> _showLocalDrafts() async {
    await _refreshLocalDrafts();
    if (!mounted) {
      return;
    }
    final selected = await showModalBottomSheet<StoryCardLocalDraftSummary>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.72,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) => StoryCardLocalDraftSheet(
        drafts: _localDrafts,
        onSelected: (draft) => Navigator.of(sheetContext).pop(draft),
      ),
    );
    if (!mounted || selected == null) {
      return;
    }

    final draft = await ref
        .read(storyCardLocalDraftRepositoryProvider)
        .take(selected.id);
    if (draft == null) {
      await _refreshLocalDrafts();
      if (mounted) {
        _showSnackBar('임시 저장 카드가 만료되었어요.');
      }
      return;
    }

    late final List<ui.Image?> decoded;
    try {
      decoded = await _decodeUiImages(
        _paddedPhotoBytes(draft.storedPhotoImageBytes),
      );
    } catch (_) {
      if (mounted) {
        _showSnackBar('임시 저장 카드를 불러오지 못했어요.');
      }
      return;
    }
    if (!mounted) {
      _disposeImages(decoded);
      return;
    }

    final previousImages = _backgroundImages;
    final nextSession = StoryCardEditorSession.fromDraft(draft);
    setState(() {
      _session = nextSession;
      _backgroundImages = decoded;
      _cameraTargetPhotoIndex = null;
      _selectedPhotoIndex = 0;
      _selectedEmptyPhotoIndex = null;
      _isLocalDraftActive = true;
      _cameraFilm = draft.scene.photoFilms.first;
    });
    _disposeImages(previousImages);
    _showCardTypeOnboarding();
    await _refreshLocalDrafts();
    if (draft.scene.photoFilms.any(
      (film) => film.look != StoryCardFilmLook.original,
    )) {
      unawaited(_prepareFilmProgram());
    }
  }

  Future<void> _saveLocalDraft() async {
    if (_isSavingLocalDraft || !_draft.hasDraftContent) {
      return;
    }
    setState(() => _isSavingLocalDraft = true);
    try {
      final preview = await _capturePreview();
      await ref
          .read(storyCardLocalDraftRepositoryProvider)
          .save(draft: _draft, previewImageBytes: preview);
      if (mounted) {
        context.go('/home');
      }
    } catch (_) {
      if (mounted) {
        _showSnackBar('임시 저장하지 못했어요. 다시 시도해 주세요.');
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingLocalDraft = false);
      }
    }
  }

  Future<void> _loadBackgroundImages(List<Uint8List?> bytes) async {
    final paddedBytes = _paddedPhotoBytes(bytes);
    if (paddedBytes.every((imageBytes) => imageBytes == null)) {
      return;
    }

    try {
      final decoded = await _decodeUiImages(paddedBytes);
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

  List<Uint8List?> _paddedPhotoBytes(Iterable<Uint8List?> bytes) {
    final source = bytes.toList(growable: false);
    return List<Uint8List?>.generate(
      4,
      (index) => index < source.length ? source[index] : null,
      growable: false,
    );
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

  void _cancelStroke(int pointer) {
    if (_activePointer != pointer) {
      return;
    }
    setState(() {
      _activePointer = null;
      _activeStroke = null;
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
    if (_draft.scene.photoFilms.any(
          (film) => film.look != StoryCardFilmLook.original,
        ) &&
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

class _PhotoAdjustmentResult {
  const _PhotoAdjustmentResult.updated({
    required this.transform,
    required this.film,
  }) : removed = false;

  const _PhotoAdjustmentResult.removed()
    : removed = true,
      transform = null,
      film = null;

  final bool removed;
  final StoryCardBackgroundTransform? transform;
  final StoryCardFilmState? film;
}
