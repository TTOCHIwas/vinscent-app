import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/drawing/app_drawing_controller.dart';
import '../../../../core/drawing/widgets/app_drawing_canvas.dart';
import '../../../../core/drawing/widgets/app_canvas_color_picker.dart';
import '../../../../core/drawing/widgets/app_drawing_toolbar.dart';
import '../../../../core/theme/app_colors.dart';
import 'calendar_event_form_style.dart';

enum CalendarEventExtrasMode { drawing, memo }

class CoupleCalendarEventExtrasForm extends StatelessWidget {
  const CoupleCalendarEventExtrasForm({
    super.key,
    required this.memoController,
    required this.drawingController,
    required this.mode,
    required this.canEdit,
    required this.isSaving,
    required this.onModeChanged,
    required this.onClearDrawing,
  });

  static const _maxCanvasSize = 360.0;
  static const _memoMaxLength = 500;

  final TextEditingController memoController;
  final AppDrawingController drawingController;
  final CalendarEventExtrasMode mode;
  final bool canEdit;
  final bool isSaving;
  final ValueChanged<CalendarEventExtrasMode> onModeChanged;
  final VoidCallback onClearDrawing;

  bool get _isEnabled => canEdit && !isSaving;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('calendar-event-extras-step'),
      children: [
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<CalendarEventExtrasMode>(
            segments: const [
              ButtonSegment(
                value: CalendarEventExtrasMode.drawing,
                icon: Icon(Icons.draw_outlined),
                label: Text('그림', key: Key('calendar-event-mode-drawing')),
              ),
              ButtonSegment(
                value: CalendarEventExtrasMode.memo,
                icon: Icon(Icons.notes_outlined),
                label: Text('메모', key: Key('calendar-event-mode-memo')),
              ),
            ],
            selected: {mode},
            showSelectedIcon: false,
            style: CalendarEventFormStyle.segmentedButton,
            onSelectionChanged: _isEnabled
                ? (selection) => onModeChanged(selection.single)
                : null,
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: mode == CalendarEventExtrasMode.drawing
              ? _DrawingEditor(
                  controller: drawingController,
                  isEnabled: _isEnabled,
                  onClearDrawing: onClearDrawing,
                )
              : TextField(
                  key: const Key('calendar-event-memo-field'),
                  controller: memoController,
                  enabled: _isEnabled,
                  expands: true,
                  minLines: null,
                  maxLines: null,
                  maxLength: _memoMaxLength,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: CalendarEventFormStyle.inputDecoration(
                    '함께 기억할 내용을 남겨도 좋아요',
                  ),
                ),
        ),
      ],
    );
  }
}

class _DrawingEditor extends StatefulWidget {
  const _DrawingEditor({
    required this.controller,
    required this.isEnabled,
    required this.onClearDrawing,
  });

  final AppDrawingController controller;
  final bool isEnabled;
  final VoidCallback onClearDrawing;

  @override
  State<_DrawingEditor> createState() => _DrawingEditorState();
}

class _DrawingEditorState extends State<_DrawingEditor> {
  final _colorSamplingKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final isEnabled = widget.isEnabled;
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final canvasSize = math.min(
                CoupleCalendarEventExtrasForm._maxCanvasSize,
                constraints.biggest.shortestSide,
              );
              return Center(
                child: SizedBox.square(
                  dimension: canvasSize,
                  child: RepaintBoundary(
                    key: _colorSamplingKey,
                    child: ColoredBox(
                      color: AppColors.formSurface,
                      child: AppDrawingCanvas(
                        key: const Key('calendar-event-drawing-canvas'),
                        strokes: controller.visibleStrokes,
                        isReadOnly: !isEnabled,
                        onStrokeStart: controller.startStroke,
                        onStrokeUpdate: controller.updateStroke,
                        onStrokeEnd: controller.endStroke,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: AppDrawingToolbar(
            keyPrefix: 'calendar-event-drawing',
            selectedTool: controller.selectedTool,
            selectedColor: controller.selectedColor,
            selectedStrokeWidth: controller.selectedStrokeWidth,
            isReadOnly: !isEnabled,
            canUndo: isEnabled && controller.canUndo,
            canClear: isEnabled && controller.canClear,
            onToolChanged: controller.selectTool,
            onColorChanged: controller.selectColor,
            onPickColor: () => showAppCanvasColorPicker(
              context: context,
              canvasKey: _colorSamplingKey,
              backgroundColor: AppColors.background,
              keyPrefix: 'calendar-event-drawing',
              canOpen: () => mounted && widget.isEnabled,
            ),
            onStrokeWidthChanged: controller.selectStrokeWidth,
            onUndoPressed: controller.undo,
            onClearPressed: widget.onClearDrawing,
          ),
        ),
      ],
    );
  }
}
