import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/drawing/app_drawing.dart';
import '../../../core/drawing/app_drawing_controller.dart';
import '../../../core/drawing/app_drawing_painter.dart';
import '../../../core/drawing/widgets/app_drawing_canvas.dart';
import '../../../core/drawing/widgets/app_drawing_toolbar.dart';
import '../../../core/presentation/widgets/app_back_button.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../couple/application/couple_controller.dart';
import '../../couple/data/couple_failure.dart';
import '../../profile/application/profile_controller.dart';
import '../application/couple_character_controller.dart';
import '../data/couple_character_failure.dart';

class CharacterEditorScreen extends ConsumerStatefulWidget {
  const CharacterEditorScreen({super.key}) : isInitialSetup = false;

  const CharacterEditorScreen.initialSetup({super.key}) : isInitialSetup = true;

  final bool isInitialSetup;

  @override
  ConsumerState<CharacterEditorScreen> createState() =>
      _CharacterEditorScreenState();
}

class _CharacterEditorScreenState extends ConsumerState<CharacterEditorScreen> {
  static const _exportSize = 512;

  late final AppDrawingController _drawingController;
  bool _isLoadingDrawing = true;
  bool _isSaving = false;

  bool get _isReadOnly {
    final couple = ref
        .read(coupleControllerProvider)
        .maybeWhen(data: (value) => value, orElse: () => null);
    if (couple == null || !couple.canEditSharedData) {
      return true;
    }
    if (!widget.isInitialSetup) {
      return false;
    }

    final profileId = ref
        .read(profileControllerProvider)
        .maybeWhen(data: (profile) => profile?.id, orElse: () => null);
    return profileId == null ||
        !couple.isInitialSetupOwner(profileId) ||
        !couple.isCharacterSetupPending ||
        !couple.hasRelationshipStartDate;
  }

  bool get _canSave {
    return !_isReadOnly &&
        !_isLoadingDrawing &&
        !_isSaving &&
        _drawingController.hasVisibleContent;
  }

  bool get _canClear {
    return !_isReadOnly &&
        !_isLoadingDrawing &&
        !_isSaving &&
        _drawingController.canClear;
  }

  bool get _canUndo {
    return !_isReadOnly &&
        !_isLoadingDrawing &&
        !_isSaving &&
        _drawingController.canUndo;
  }

  bool get _canSkip =>
      widget.isInitialSetup && !_isReadOnly && !_isLoadingDrawing && !_isSaving;

  @override
  void initState() {
    super.initState();
    _drawingController = AppDrawingController()
      ..addListener(_handleDrawingChanged);
    if (widget.isInitialSetup) {
      _isLoadingDrawing = false;
    } else {
      Future<void>.microtask(_loadExistingDrawing);
    }
  }

  @override
  void dispose() {
    _drawingController
      ..removeListener(_handleDrawingChanged)
      ..dispose();
    super.dispose();
  }

  void _handleDrawingChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadExistingDrawing() async {
    try {
      final character = await ref.read(
        coupleCharacterControllerProvider.future,
      );
      if (!mounted || character == null) {
        return;
      }

      final drawingDataJson = await ref
          .read(coupleCharacterControllerProvider.notifier)
          .fetchDrawingData(character);
      if (!mounted || drawingDataJson == null) {
        return;
      }

      final drawingData = AppDrawingData.fromJsonString(drawingDataJson);
      _drawingController.replaceStrokes(drawingData.strokes);
    } catch (_) {
      if (mounted) {
        _showSnackBar('캐릭터를 불러오지 못했어요.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingDrawing = false;
        });
      }
    }
  }

  void _startStroke(AppDrawingPoint point) {
    if (_isReadOnly) {
      return;
    }

    _drawingController.startStroke(point);
  }

  void _updateStroke(AppDrawingPoint point) {
    if (_isReadOnly) {
      return;
    }

    _drawingController.updateStroke(point);
  }

  void _endStroke() {
    if (_isReadOnly) {
      return;
    }

    _drawingController.endStroke();
  }

  void _undoLastStroke() {
    if (!_canUndo) {
      return;
    }

    _drawingController.undo();
  }

  Future<void> _confirmClearCanvas() async {
    if (!_canClear) {
      return;
    }

    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('그림을 모두 지울까요?'),
          content: const Text('저장하기 전까지는 현재 화면에서만 지워져요.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('삭제'),
            ),
          ],
        );
      },
    );

    if (!mounted || shouldClear != true) {
      return;
    }

    _drawingController.clear();
  }

  Future<void> _save() async {
    if (!_canSave) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final drawingData = _drawingController.drawingData;
      final imageBytes = await _renderPng(drawingData);

      await ref
          .read(coupleCharacterControllerProvider.notifier)
          .saveCharacter(
            imageBytes: imageBytes,
            drawingDataJson: drawingData.toJsonString(),
          );

      if (mounted) {
        _closeEditor();
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

  Future<void> _useDefaultCharacter() async {
    if (!_canSkip) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await ref.read(coupleControllerProvider.notifier).useDefaultCharacter();
      if (mounted) {
        _closeEditor();
      }
    } catch (error) {
      if (mounted) {
        _showSnackBar(_defaultCharacterFailureMessage(error));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<Uint8List> _renderPng(AppDrawingData drawingData) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = Size.square(_exportSize.toDouble());

    AppDrawingPainter(strokes: drawingData.strokes).paint(canvas, size);

    final picture = recorder.endRecording();
    final image = await picture.toImage(_exportSize, _exportSize);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    picture.dispose();
    image.dispose();

    if (byteData == null) {
      throw StateError('Character image export failed.');
    }

    return byteData.buffer.asUint8List();
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _closeEditor() {
    context.go(widget.isInitialSetup ? '/home' : '/settings');
  }

  String _defaultCharacterFailureMessage(Object error) {
    if (error is CoupleRepositoryException) {
      return switch (error.reason) {
        CoupleFailureReason.initialSetupOwnerRequired =>
          '초대 코드를 입력한 사용자만 설정할 수 있어요.',
        CoupleFailureReason.relationshipDateRequired => '만난 날짜를 먼저 저장해주세요.',
        _ => '기본 캐릭터를 설정하지 못했어요.',
      };
    }
    return '기본 캐릭터를 설정하지 못했어요.';
  }

  String _saveFailureMessage(Object error) {
    if (error is CoupleCharacterRepositoryException) {
      return switch (error.reason) {
        CoupleCharacterFailureReason.configMissing =>
          'Supabase 설정이 없어 저장할 수 없어요.',
        CoupleCharacterFailureReason.authRequired => '로그인이 필요해요.',
        CoupleCharacterFailureReason.activeCoupleRequired =>
          '커플 연결 상태를 다시 확인해 주세요.',
        CoupleCharacterFailureReason.initialSetupOwnerRequired =>
          '초대 코드를 입력한 사용자만 설정할 수 있어요.',
        CoupleCharacterFailureReason.relationshipDateRequired =>
          '만난 날짜를 먼저 저장해주세요.',
        CoupleCharacterFailureReason.invalidPath => '캐릭터 저장 경로가 올바르지 않아요.',
        CoupleCharacterFailureReason.requestTimeout => '요청 시간이 초과됐어요.',
        CoupleCharacterFailureReason.storage => '캐릭터 파일을 저장하지 못했어요.',
        CoupleCharacterFailureReason.unknown => '캐릭터를 저장하지 못했어요.',
      };
    }

    return '캐릭터를 저장하지 못했어요.';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isInitialSetup) {
      ref.watch(profileControllerProvider);
    }
    final couple = ref
        .watch(coupleControllerProvider)
        .maybeWhen(data: (couple) => couple, orElse: () => null);
    final isReadOnly = _isReadOnly;
    final isArchivedReadOnly = couple?.isArchivedReadOnly ?? false;

    return ColoredBox(
      color: AppColors.background,
      child: SafeArea(
        top: widget.isInitialSetup,
        bottom: false,
        child: Column(
          children: [
            _CharacterEditorHeader(
              canSave: _canSave,
              canSkip: _canSkip,
              showSkip: widget.isInitialSetup,
              isSaving: _isSaving,
              onBackPressed: _closeEditor,
              onSkipPressed: _useDefaultCharacter,
              onSavePressed: _save,
            ),
            Expanded(
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    if (isArchivedReadOnly)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            border: Border.all(
                              color: AppColors.wireframeBorder,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '보관 중에는 기존 캐릭터를 읽기 전용으로만 볼 수 있어요.',
                            style: AppTextStyles.homeCharacterLabel.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      ),
                    Expanded(
                      child: Padding(
                        key: const ValueKey('character-drawing-canvas-region'),
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: _exportSize.toDouble(),
                              maxHeight: _exportSize.toDouble(),
                            ),
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.white,
                                  border: Border.all(
                                    color: AppColors.wireframeBorder,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: _isLoadingDrawing
                                    ? const Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : AppDrawingCanvas(
                                        strokes:
                                            _drawingController.visibleStrokes,
                                        isReadOnly: isReadOnly,
                                        onStrokeStart: _startStroke,
                                        onStrokeUpdate: _updateStroke,
                                        onStrokeEnd: _endStroke,
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: AppDrawingToolbar(
                          selectedTool: _drawingController.selectedTool,
                          selectedColor: _drawingController.selectedColor,
                          selectedStrokeWidth:
                              _drawingController.selectedStrokeWidth,
                          isReadOnly: isReadOnly,
                          canUndo: _canUndo,
                          canClear: _canClear,
                          onToolChanged: _drawingController.selectTool,
                          onColorChanged: _drawingController.selectColor,
                          onStrokeWidthChanged:
                              _drawingController.selectStrokeWidth,
                          onUndoPressed: _undoLastStroke,
                          onClearPressed: _confirmClearCanvas,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CharacterEditorHeader extends StatelessWidget {
  const _CharacterEditorHeader({
    required this.canSave,
    required this.canSkip,
    required this.showSkip,
    required this.isSaving,
    required this.onBackPressed,
    required this.onSkipPressed,
    required this.onSavePressed,
  });

  final bool canSave;
  final bool canSkip;
  final bool showSkip;
  final bool isSaving;
  final VoidCallback onBackPressed;
  final VoidCallback onSkipPressed;
  final VoidCallback onSavePressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: showSkip
                  ? SizedBox(
                      width: 84,
                      child: TextButton(
                        onPressed: canSkip ? onSkipPressed : null,
                        child: const Text('건너뛰기'),
                      ),
                    )
                  : AppBackButton(onPressed: onBackPressed, iconSize: 32),
            ),
            const Text('캐릭터 그리기', style: AppTextStyles.shellTitle),
            Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: 72,
                child: TextButton(
                  onPressed: canSave ? onSavePressed : null,
                  child: isSaving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('저장'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
