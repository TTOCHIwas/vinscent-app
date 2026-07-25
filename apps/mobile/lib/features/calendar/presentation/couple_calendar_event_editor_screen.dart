import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/date/app_date_policy.dart';
import '../../../core/drawing/app_drawing.dart';
import '../../../core/drawing/app_drawing_controller.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../couple/application/couple_controller.dart';
import '../../settings/presentation/widgets/settings_page_layout.dart';
import '../application/couple_calendar_event_editor_service.dart';
import '../application/couple_calendar_event_realtime_controller.dart';
import '../data/couple_calendar_event.dart';
import '../data/couple_calendar_event_failure.dart';
import '../data/couple_calendar_event_repository.dart';
import 'widgets/couple_calendar_event_form.dart';

class CoupleCalendarEventEditorScreen extends ConsumerStatefulWidget {
  const CoupleCalendarEventEditorScreen.create({
    super.key,
    required this.initialDate,
  }) : eventId = null;

  const CoupleCalendarEventEditorScreen.edit({
    super.key,
    required String this.eventId,
  }) : initialDate = null;

  final String? eventId;
  final DateTime? initialDate;

  bool get isCreating => eventId == null;

  @override
  ConsumerState<CoupleCalendarEventEditorScreen> createState() =>
      _CoupleCalendarEventEditorScreenState();
}

class _CoupleCalendarEventEditorScreenState
    extends ConsumerState<CoupleCalendarEventEditorScreen> {
  static const _titleMaxLength = 30;

  late final TextEditingController _titleController;
  late final TextEditingController _memoController;
  late final AppDrawingController _drawingController;
  late final String _eventId;
  late DateTime _selectedDate;
  CoupleCalendarEventRepeatRule _repeatRule =
      CoupleCalendarEventRepeatRule.none;
  CoupleCalendarEventReminder _reminder =
      const CoupleCalendarEventReminder.disabled();
  CoupleCalendarEvent? _existingEvent;
  String _originalDrawingJson = AppDrawingData.empty().toJsonString();
  bool _isLoading = false;
  bool _loadFailed = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _eventId = widget.eventId ?? const Uuid().v4();
    _selectedDate = calendarDateOnly(widget.initialDate ?? DateTime.now());
    _titleController = TextEditingController()..addListener(_handleChanged);
    _memoController = TextEditingController()..addListener(_handleChanged);
    _drawingController = AppDrawingController()..addListener(_handleChanged);
    if (!widget.isCreating) {
      _isLoading = true;
      Future<void>.microtask(_loadEvent);
    }
  }

  @override
  void dispose() {
    _titleController
      ..removeListener(_handleChanged)
      ..dispose();
    _memoController
      ..removeListener(_handleChanged)
      ..dispose();
    _drawingController
      ..removeListener(_handleChanged)
      ..dispose();
    super.dispose();
  }

  bool get _isDrawingChanged {
    return _drawingController.drawingData.toJsonString() !=
        _originalDrawingJson;
  }

  bool get _canSave {
    final titleLength = _titleController.text.trim().characters.length;
    return !_isLoading &&
        !_loadFailed &&
        !_isSaving &&
        titleLength >= 1 &&
        titleLength <= _titleMaxLength;
  }

  bool get _canEdit {
    final couple = ref
        .read(coupleControllerProvider)
        .maybeWhen(data: (value) => value, orElse: () => null);
    return couple?.canEditSharedData ?? false;
  }

  void _handleChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadEvent() async {
    try {
      final data = await ref
          .read(coupleCalendarEventEditorServiceProvider)
          .load(_eventId);
      if (!mounted) {
        return;
      }
      if (data == null) {
        throw StateError('Calendar event not found.');
      }

      final event = data.event;
      _titleController.text = event.title;
      _memoController.text = event.memo ?? '';
      _drawingController.replaceStrokes(data.drawing.strokes);
      setState(() {
        _existingEvent = event;
        _selectedDate = event.eventDate;
        _repeatRule = event.repeatRule;
        _reminder = event.reminder;
        _originalDrawingJson = data.drawing.toJsonString();
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadFailed = true;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _save() async {
    final couple = ref
        .read(coupleControllerProvider)
        .maybeWhen(data: (value) => value, orElse: () => null);
    if (!_canSave || !_canEdit || couple == null) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await ref
          .read(coupleCalendarEventEditorServiceProvider)
          .save(
            coupleId: couple.id,
            request: CoupleCalendarEventSaveRequest(
              eventId: _eventId,
              title: _titleController.text.trim(),
              eventDate: _selectedDate,
              repeatRule: _repeatRule,
              memo: _memoController.text.trim().isEmpty
                  ? null
                  : _memoController.text.trim(),
              expectedRevision: _existingEvent?.revision,
              removeArtwork: false,
              reminder:
                  _selectedDate.isBefore(
                    calendarDateOnly(couple.effectiveCurrentDate),
                  )
                  ? const CoupleCalendarEventReminder.disabled()
                  : _reminder,
            ),
            drawing: _drawingController.drawingData,
            drawingChanged: _isDrawingChanged,
          );
      ref
          .read(coupleCalendarEventRealtimeControllerProvider.notifier)
          .refreshReadModels();
      if (mounted) {
        _close();
      }
    } catch (error) {
      if (mounted) {
        _showMessage(_saveFailureMessage(error));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final couple = ref.watch(coupleControllerProvider).asData?.value;
    final canEdit = couple?.canEditSharedData ?? false;
    final today = calendarDateOnly(
      couple?.effectiveCurrentDate ?? DateTime.now(),
    );
    final relationshipStartDate = calendarDateOnly(
      couple?.relationshipStartDate ?? today,
    );
    final isPast = _selectedDate.isBefore(today);

    return SettingsPageLayout(
      title: widget.isCreating ? '일정 추가' : '일정 수정',
      onBackPressed: _close,
      action: SizedBox(
        width: 64,
        child: TextButton(
          key: const Key('calendar-event-save'),
          onPressed: _canSave && canEdit ? _save : null,
          child: _isSaving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('저장'),
        ),
      ),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _loadFailed
          ? _LoadFailure(onRetry: _loadEvent)
          : CoupleCalendarEventForm(
              titleController: _titleController,
              memoController: _memoController,
              drawingController: _drawingController,
              selectedDate: _selectedDate,
              repeatRule: _repeatRule,
              reminder: _reminder,
              canEdit: canEdit,
              isSaving: _isSaving,
              isPast: isPast,
              onDatePressed: () => _pickDate(relationshipStartDate, today),
              onRepeatRuleChanged: (value) {
                setState(() {
                  _repeatRule = value;
                });
              },
              onClearDrawing: _confirmClearDrawing,
              onReminderEnabledChanged: (value) {
                setState(() {
                  _reminder = CoupleCalendarEventReminder(
                    isEnabled: value,
                    offsetDays: _reminder.offsetDays,
                    hour: _reminder.hour,
                    minute: _reminder.minute,
                  );
                });
              },
              onReminderOffsetChanged: (value) {
                setState(() {
                  _reminder = CoupleCalendarEventReminder(
                    isEnabled: true,
                    offsetDays: value,
                    hour: _reminder.hour,
                    minute: _reminder.minute,
                  );
                });
              },
              onReminderTimePressed: _pickReminderTime,
            ),
    );
  }

  Future<void> _pickDate(DateTime relationshipStartDate, DateTime today) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isBefore(relationshipStartDate)
          ? relationshipStartDate
          : _selectedDate,
      firstDate: relationshipStartDate,
      lastDate: DateTime(2100, 12, 31),
    );
    if (selected != null && mounted) {
      setState(() {
        _selectedDate = calendarDateOnly(selected);
        if (_selectedDate.isBefore(today)) {
          _reminder = const CoupleCalendarEventReminder.disabled();
        }
      });
    }
  }

  Future<void> _pickReminderTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _reminder.hour, minute: _reminder.minute),
    );
    if (selected != null && mounted) {
      setState(() {
        _reminder = CoupleCalendarEventReminder(
          isEnabled: true,
          offsetDays: _reminder.offsetDays,
          hour: selected.hour,
          minute: selected.minute,
        );
      });
    }
  }

  Future<void> _confirmClearDrawing() async {
    if (!_drawingController.canClear) {
      return;
    }
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('그림을 모두 지울까요?'),
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
    if (shouldClear == true) {
      _drawingController.clear();
    }
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/calendar');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _saveFailureMessage(Object error) {
    if (error is! CoupleCalendarEventRepositoryException) {
      return '일정을 저장하지 못했어요';
    }
    return switch (error.reason) {
      CoupleCalendarEventFailureReason.invalidTitle =>
        '제목은 1자 이상 30자 이하로 입력해 주세요',
      CoupleCalendarEventFailureReason.invalidMemo => '메모는 500자 이하로 입력해 주세요',
      CoupleCalendarEventFailureReason.reminderInPast =>
        '지난 일정에는 알림을 설정할 수 없어요',
      CoupleCalendarEventFailureReason.beforeRelationshipStart =>
        '처음 만난 날 이후의 날짜를 선택해 주세요',
      CoupleCalendarEventFailureReason.conflict =>
        '상대방이 일정을 먼저 수정했어요. 다시 열어 주세요',
      CoupleCalendarEventFailureReason.artworkMissing ||
      CoupleCalendarEventFailureReason.storage => '그림을 저장하지 못했어요',
      CoupleCalendarEventFailureReason.requestTimeout =>
        '요청 시간이 초과됐어요. 다시 시도해 주세요',
      _ => '일정을 저장하지 못했어요',
    };
  }
}

class _LoadFailure extends StatelessWidget {
  const _LoadFailure({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('일정을 불러오지 못했어요', style: AppTextStyles.homeBodyMedium),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: const Text('다시 시도')),
        ],
      ),
    );
  }
}
