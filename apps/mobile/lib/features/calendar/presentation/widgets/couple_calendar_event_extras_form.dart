import 'package:flutter/material.dart';

import '../../../../core/drawing/app_drawing.dart';
import '../../../../core/drawing/app_drawing_controller.dart';
import '../../../../core/drawing/widgets/app_drawing_canvas.dart';
import '../../../../core/drawing/widgets/app_canvas_color_picker.dart';
import '../../../../core/drawing/widgets/app_drawing_canvas_layout.dart';
import '../../../../core/drawing/widgets/app_drawing_style_controls.dart';
import '../../../../core/drawing/widgets/app_drawing_toolbar.dart';
import '../../../../core/presentation/widgets/app_back_button.dart';
import '../../../../core/presentation/widgets/app_page_header.dart';
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
    this.onBackPressed,
    this.onSavePressed,
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
  final VoidCallback? onBackPressed;
  final VoidCallback? onSavePressed;

  bool get _isEnabled => canEdit && !isSaving;

  @override
  Widget build(BuildContext context) {
    final isDrawing = mode == CalendarEventExtrasMode.drawing;
    final saveIcon = isSaving
        ? const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.check_rounded);
    return Material(
      color: isDrawing ? Colors.black : AppColors.background,
      child: Column(
        key: const Key('calendar-event-extras-step'),
        children: [
          if (isDrawing)
            AppDrawingToolbar(
              keyPrefix: 'calendar-event-drawing',
              selectedTool: drawingController.selectedTool,
              isReadOnly: !_isEnabled,
              canUndo: drawingController.canUndo,
              canClear: drawingController.canClear,
              onToolChanged: drawingController.selectTool,
              onUndoPressed: drawingController.undo,
              onClearPressed: onClearDrawing,
              leading: AppBackButton(
                onPressed: onBackPressed,
                color: Colors.white,
              ),
              trailing: AppDrawingToolButton(
                buttonKey: const Key('calendar-event-save'),
                tooltip: '일정 저장',
                isSelected: true,
                onPressed: _isEnabled ? onSavePressed : null,
                icon: saveIcon,
              ),
            )
          else
            AppPageHeader(
              title: '',
              onBackPressed: onBackPressed,
              action: IconButton(
                key: const Key('calendar-event-save'),
                tooltip: '일정 저장',
                onPressed: _isEnabled ? onSavePressed : null,
                icon: saveIcon,
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SizedBox(
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
                style: isDrawing
                    ? CalendarEventFormStyle.segmentedButton.copyWith(
                        foregroundColor: WidgetStateProperty.resolveWith(
                          (states) => states.contains(WidgetState.selected)
                              ? AppColors.onBrandAction
                              : Colors.white70,
                        ),
                      )
                    : CalendarEventFormStyle.segmentedButton,
                onSelectionChanged: _isEnabled
                    ? (selection) => onModeChanged(selection.single)
                    : null,
              ),
            ),
          ),
          Expanded(
            child: isDrawing
                ? _DrawingEditor(
                    controller: drawingController,
                    isEnabled: _isEnabled,
                  )
                : Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    child: TextField(
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
          ),
        ],
      ),
    );
  }
}

class _DrawingEditor extends StatefulWidget {
  const _DrawingEditor({required this.controller, required this.isEnabled});

  final AppDrawingController controller;
  final bool isEnabled;

  @override
  State<_DrawingEditor> createState() => _DrawingEditorState();
}

class _DrawingEditorState extends State<_DrawingEditor> {
  final _colorSamplingKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final isEnabled = widget.isEnabled;
    return AppDrawingCanvasLayout(
      canvasRegionKey: const Key('calendar-event-drawing-canvas-region'),
      maxCanvasSize: CoupleCalendarEventExtrasForm._maxCanvasSize,
      canvas: RepaintBoundary(
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
      controlsBuilder: (canvasExtent) => AppDrawingStyleControls(
        keyPrefix: 'calendar-event-drawing',
        canvasExtent: canvasExtent,
        selectedColor: controller.selectedColor,
        selectedStrokeWidth: controller.selectedStrokeWidth,
        showColorSelection: controller.selectedTool == AppDrawingTool.pen,
        onColorChanged: isEnabled ? controller.selectColor : null,
        onPickColor: isEnabled
            ? () => showAppCanvasColorPicker(
                context: context,
                canvasKey: _colorSamplingKey,
                backgroundColor: Colors.black,
                keyPrefix: 'calendar-event-drawing',
                canOpen: () => mounted && widget.isEnabled,
              )
            : null,
        onStrokeWidthChanged: isEnabled ? controller.selectStrokeWidth : null,
      ),
    );
  }
}
