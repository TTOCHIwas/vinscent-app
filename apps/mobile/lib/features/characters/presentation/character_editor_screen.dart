import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../application/couple_character_controller.dart';
import '../data/character_drawing.dart';
import 'widgets/character_canvas.dart';
import 'widgets/character_toolbar.dart';

class CharacterEditorScreen extends ConsumerStatefulWidget {
  const CharacterEditorScreen({super.key});

  @override
  ConsumerState<CharacterEditorScreen> createState() =>
      _CharacterEditorScreenState();
}

class _CharacterEditorScreenState extends ConsumerState<CharacterEditorScreen> {
  static const _exportSize = 512;

  List<CharacterDrawingStroke> _strokes = [];
  CharacterDrawingStroke? _activeStroke;
  CharacterDrawingTool _selectedTool = CharacterDrawingTool.pen;
  Color _selectedColor = characterColorPalette.first;
  double _selectedStrokeWidth = characterNormalStrokeWidth;
  bool _isLoadingDrawing = true;
  bool _isSaving = false;

  List<CharacterDrawingStroke> get _visibleStrokes {
    return [..._strokes, ?_activeStroke];
  }

  bool get _canSave {
    return !_isLoadingDrawing &&
        !_isSaving &&
        CharacterDrawingData(strokes: _strokes).hasVisibleContent;
  }

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_loadExistingDrawing);
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

      final drawingData = CharacterDrawingData.fromJsonString(drawingDataJson);
      setState(() {
        _strokes = drawingData.strokes;
      });
    } catch (_) {
      if (mounted) {
        _showSnackBar('캐릭터를 불러오지 못했어요');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingDrawing = false;
        });
      }
    }
  }

  void _startStroke(CharacterDrawingPoint point) {
    setState(() {
      _activeStroke = CharacterDrawingStroke(
        tool: _selectedTool,
        color: _selectedColor,
        width: _selectedStrokeWidth,
        points: [point],
      );
    });
  }

  void _updateStroke(CharacterDrawingPoint point) {
    final activeStroke = _activeStroke;
    if (activeStroke == null) {
      return;
    }

    setState(() {
      _activeStroke = activeStroke.copyWith(
        points: [...activeStroke.points, point],
      );
    });
  }

  void _endStroke() {
    final activeStroke = _activeStroke;
    if (activeStroke == null) {
      return;
    }

    setState(() {
      _strokes = [..._strokes, activeStroke];
      _activeStroke = null;
    });
  }

  Future<void> _save() async {
    if (!_canSave) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final drawingData = CharacterDrawingData(strokes: _strokes);
      final imageBytes = await _renderPng(drawingData);

      await ref
          .read(coupleCharacterControllerProvider.notifier)
          .saveCharacter(
            imageBytes: imageBytes,
            drawingDataJson: drawingData.toJsonString(),
          );

      if (mounted) {
        context.go('/home');
      }
    } catch (_) {
      if (mounted) {
        _showSnackBar('캐릭터를 저장하지 못했어요');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<Uint8List> _renderPng(CharacterDrawingData drawingData) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = Size.square(_exportSize.toDouble());

    CharacterDrawingPainter(strokes: drawingData.strokes).paint(canvas, size);

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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _CharacterEditorHeader(
          canSave: _canSave,
          isSaving: _isSaving,
          onBackPressed: () => context.go('/home'),
          onSavePressed: _save,
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
            child: Column(
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.wireframeBorder),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _isLoadingDrawing
                        ? const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : CharacterCanvas(
                            strokes: _visibleStrokes,
                            onStrokeStart: _startStroke,
                            onStrokeUpdate: _updateStroke,
                            onStrokeEnd: _endStroke,
                          ),
                  ),
                ),
                const SizedBox(height: 24),
                CharacterToolbar(
                  selectedTool: _selectedTool,
                  selectedColor: _selectedColor,
                  selectedStrokeWidth: _selectedStrokeWidth,
                  onToolChanged: (tool) {
                    setState(() {
                      _selectedTool = tool;
                    });
                  },
                  onColorChanged: (color) {
                    setState(() {
                      _selectedColor = color;
                      _selectedTool = CharacterDrawingTool.pen;
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
}

class _CharacterEditorHeader extends StatelessWidget {
  const _CharacterEditorHeader({
    required this.canSave,
    required this.isSaving,
    required this.onBackPressed,
    required this.onSavePressed,
  });

  final bool canSave;
  final bool isSaving;
  final VoidCallback onBackPressed;
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
            child: IconButton(
              onPressed: onBackPressed,
              icon: const Icon(Icons.chevron_left, size: 32),
            ),
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
    );
  }
}
