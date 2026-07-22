import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/drawing/app_drawing.dart';
import '../../../core/drawing/app_drawing_controller.dart';
import '../../../core/drawing/widgets/app_drawing_canvas.dart';
import '../../../core/drawing/widgets/app_drawing_toolbar.dart';
import '../../../core/presentation/widgets/app_back_button.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../couple/application/couple_controller.dart';
import '../application/couple_recording_overview_controller.dart';
import '../application/recording_slot_artwork_codec.dart';
import '../data/couple_recording.dart';
import '../data/couple_recording_failure.dart';
import '../data/couple_recording_repository.dart';

class RecordingSlotArtworkEditorScreen extends ConsumerStatefulWidget {
  const RecordingSlotArtworkEditorScreen({super.key, required this.slotId})
    : slotIndex = 0,
      isCreating = false;

  const RecordingSlotArtworkEditorScreen.create({
    super.key,
    required this.slotIndex,
  }) : slotId = '',
       isCreating = true;

  final String slotId;
  final int slotIndex;
  final bool isCreating;

  @override
  ConsumerState<RecordingSlotArtworkEditorScreen> createState() =>
      _RecordingSlotArtworkEditorScreenState();
}

class _RecordingSlotArtworkEditorScreenState
    extends ConsumerState<RecordingSlotArtworkEditorScreen> {
  static const _maxCanvasSize = 512.0;

  late final AppDrawingController _drawingController;
  CoupleRecordingSlot? _slot;
  bool _isLoading = true;
  bool _loadFailed = false;
  bool _isSaving = false;
  late final TextEditingController _titleController;
  CoupleRecordingSlotSaveResult? _createdSlot;

  bool get _isReadOnly {
    final couple = ref
        .read(coupleControllerProvider)
        .maybeWhen(data: (value) => value, orElse: () => null);
    return couple == null || !couple.canEditSharedData;
  }

  bool get _canSave =>
      !_isReadOnly &&
      !_isLoading &&
      !_loadFailed &&
      !_isSaving &&
      (widget.isCreating ? _isTitleValid : _slot != null) &&
      _drawingController.hasVisibleContent;

  bool get _isTitleValid {
    final title = _titleController.text.trim();
    return title.isNotEmpty && title.length <= 20;
  }

  bool get _canUndo =>
      !_isReadOnly && !_isLoading && !_isSaving && _drawingController.canUndo;

  bool get _canClear =>
      !_isReadOnly && !_isLoading && !_isSaving && _drawingController.canClear;

  @override
  void initState() {
    super.initState();
    _drawingController = AppDrawingController()
      ..addListener(_handleDrawingChanged);
    _titleController = TextEditingController();
    _titleController.addListener(_handleTitleChanged);
    Future<void>.microtask(widget.isCreating ? _prepareNewSlot : _loadSlot);
  }

  @override
  void dispose() {
    _drawingController
      ..removeListener(_handleDrawingChanged)
      ..dispose();
    _titleController
      ..removeListener(_handleTitleChanged)
      ..dispose();
    super.dispose();
  }

  void _handleTitleChanged() {
    setState(() {});
  }

  void _handleDrawingChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _prepareNewSlot() async {
    try {
      final overview = await ref.read(
        coupleRecordingOverviewControllerProvider.future,
      );
      final slotIndex = widget.slotIndex;
      final isAvailable =
          overview != null &&
          slotIndex >= 1 &&
          slotIndex <= overview.slotLimit &&
          overview.currentRecording != null &&
          !overview.savedSlots.any((slot) => slot.slotIndex == slotIndex);
      if (!isAvailable) {
        throw StateError('Recording slot is not available.');
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadFailed = true;
      });
      _showSnackBar('슬롯 정보를 불러오지 못했어요.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadSlot() async {
    try {
      final overview = await ref.read(
        coupleRecordingOverviewControllerProvider.future,
      );
      final slot = _findSlot(overview);
      if (slot == null) {
        throw StateError('Recording slot not found.');
      }

      var strokes = const <AppDrawingStroke>[];
      final artwork = slot.artwork;
      if (artwork != null) {
        final bytes = await ref
            .read(coupleRecordingRepositoryProvider)
            .fetchSlotArtworkDrawingData(
              drawingDataPath: artwork.drawingDataPath,
            );
        strokes = (await const RecordingSlotArtworkCodec().decodeDrawingData(
          bytes,
        )).strokes;
      }

      if (!mounted) {
        return;
      }
      _drawingController.replaceStrokes(strokes);
      setState(() {
        _slot = slot;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadFailed = true;
      });
      _showSnackBar('슬롯 그림을 불러오지 못했어요.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  CoupleRecordingSlot? _findSlot(CoupleRecordingOverview? overview) {
    if (overview == null) {
      return null;
    }

    for (final slot in overview.savedSlots) {
      if (slot.slotId == widget.slotId) {
        return slot;
      }
    }
    return null;
  }

  void _startStroke(AppDrawingPoint point) {
    if (_isReadOnly || _loadFailed) {
      return;
    }

    _drawingController.startStroke(point);
  }

  void _updateStroke(AppDrawingPoint point) {
    if (_isReadOnly || _loadFailed) {
      return;
    }
    _drawingController.updateStroke(point);
  }

  void _endStroke() {
    if (_isReadOnly || _loadFailed) {
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
      builder: (context) => AlertDialog(
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
      ),
    );
    if (!mounted || shouldClear != true) {
      return;
    }

    _drawingController.clear();
  }

  Future<void> _save() async {
    final slot = _slot;
    final couple = ref
        .read(coupleControllerProvider)
        .maybeWhen(data: (value) => value, orElse: () => null);
    if (!_canSave || couple == null || (!widget.isCreating && slot == null)) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final artifact = await const RecordingSlotArtworkCodec().encode(
        _drawingController.drawingData,
      );
      var targetSlot = _createdSlot;
      if (widget.isCreating && targetSlot == null) {
        targetSlot = await ref
            .read(coupleRecordingOverviewControllerProvider.notifier)
            .saveCurrentRecordingToSlot(
              slotIndex: widget.slotIndex,
              title: _titleController.text.trim(),
              expectedSlotRevision: null,
            );
        if (!mounted) {
          return;
        }
        setState(() {
          _createdSlot = targetSlot;
        });
      }

      final targetSlotId = widget.isCreating
          ? targetSlot!.slotId
          : slot!.slotId;
      final targetSlotRevision = widget.isCreating
          ? targetSlot!.slotRevision
          : slot!.slotRevision;
      await ref
          .read(coupleRecordingOverviewControllerProvider.notifier)
          .saveSlotArtwork(
            couple: couple,
            slotId: targetSlotId,
            expectedSlotRevision: targetSlotRevision,
            previewBytes: artifact.previewBytes,
            drawingDataBytes: artifact.drawingDataBytes,
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

  void _closeEditor() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/home/recordings');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _saveFailureMessage(Object error) {
    if (error is CoupleRecordingRepositoryException) {
      return switch (error.reason) {
        CoupleRecordingFailureReason.recordingSlotConflict =>
          '슬롯이 다른 기기에서 변경됐어요. 다시 열어 주세요.',
        CoupleRecordingFailureReason.currentRecordingRequired =>
          '저장할 현재 녹음이 없어요.',
        CoupleRecordingFailureReason.invalidRecordingSlotTitle =>
          '제목은 1자 이상 20자 이하로 입력해주세요.',
        CoupleRecordingFailureReason.invalidRecordingArtwork =>
          '그림을 저장할 수 있는 크기로 줄여 주세요.',
        CoupleRecordingFailureReason.recordingArtworkFileMissing =>
          '그림 파일 업로드를 완료하지 못했어요.',
        CoupleRecordingFailureReason.requestTimeout =>
          '요청 시간이 초과됐어요. 다시 시도해 주세요.',
        CoupleRecordingFailureReason.storage => '그림 저장 권한을 확인해 주세요.',
        _ => '슬롯 그림을 저장하지 못했어요.',
      };
    }
    return '슬롯 그림을 저장하지 못했어요.';
  }

  @override
  Widget build(BuildContext context) {
    final couple = ref
        .watch(coupleControllerProvider)
        .maybeWhen(data: (value) => value, orElse: () => null);
    final isReadOnly = couple == null || !couple.canEditSharedData;

    return Material(
      color: AppColors.background,
      child: Column(
        children: [
          _ArtworkEditorHeader(
            title: widget.isCreating ? '슬롯 만들기' : '슬롯 그림',
            canSave: _canSave,
            isSaving: _isSaving,
            onBackPressed: _closeEditor,
            onSavePressed: _save,
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  if (couple?.isArchivedReadOnly ?? false)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Text(
                        '보관 중에는 슬롯 그림을 읽기 전용으로만 볼 수 있어요.',
                        style: AppTextStyles.homeCharacterLabel.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  if (widget.isCreating)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: TextField(
                        key: const ValueKey('recording-slot-title-field'),
                        controller: _titleController,
                        enabled: _createdSlot == null && !_isSaving,
                        autofocus: true,
                        maxLength: 20,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          hintText: '슬롯 제목',
                          counterText: '',
                        ),
                      ),
                    ),
                  Expanded(
                    child: Padding(
                      key: const ValueKey('recording-artwork-canvas-region'),
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: _maxCanvasSize,
                            maxHeight: _maxCanvasSize,
                          ),
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0F0F0),
                                border: Border.all(
                                  color: AppColors.wireframeBorder,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(7),
                                child: _buildCanvas(isReadOnly),
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
                        isReadOnly: isReadOnly || _loadFailed,
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
    );
  }

  Widget _buildCanvas(bool isReadOnly) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_loadFailed) {
      return Center(
        child: Text(
          '그림을 불러오지 못했어요.',
          style: AppTextStyles.homeBody.copyWith(color: AppColors.textMuted),
        ),
      );
    }

    return AppDrawingCanvas(
      strokes: _drawingController.visibleStrokes,
      isReadOnly: isReadOnly,
      onStrokeStart: _startStroke,
      onStrokeUpdate: _updateStroke,
      onStrokeEnd: _endStroke,
    );
  }
}

class _ArtworkEditorHeader extends StatelessWidget {
  const _ArtworkEditorHeader({
    required this.title,
    required this.canSave,
    required this.isSaving,
    required this.onBackPressed,
    required this.onSavePressed,
  });

  final String title;
  final bool canSave;
  final bool isSaving;
  final VoidCallback onBackPressed;
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
              child: AppBackButton(onPressed: onBackPressed, iconSize: 32),
            ),
            Text(title, style: AppTextStyles.shellTitle),
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
