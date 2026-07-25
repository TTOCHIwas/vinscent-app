import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/couple_calendar_event.dart';

class CoupleCalendarEventBasicForm extends StatelessWidget {
  const CoupleCalendarEventBasicForm({
    super.key,
    required this.titleController,
    required this.selectedDate,
    required this.repeatRule,
    required this.reminder,
    required this.canEdit,
    required this.isSaving,
    required this.isPast,
    required this.onDatePressed,
    required this.onRepeatRuleChanged,
    required this.onReminderEnabledChanged,
    required this.onReminderOffsetChanged,
    required this.onReminderTimePressed,
  });

  static const _titleMaxLength = 30;

  final TextEditingController titleController;
  final DateTime selectedDate;
  final CoupleCalendarEventRepeatRule repeatRule;
  final CoupleCalendarEventReminder reminder;
  final bool canEdit;
  final bool isSaving;
  final bool isPast;
  final VoidCallback onDatePressed;
  final ValueChanged<CoupleCalendarEventRepeatRule> onRepeatRuleChanged;
  final ValueChanged<bool> onReminderEnabledChanged;
  final ValueChanged<int> onReminderOffsetChanged;
  final VoidCallback onReminderTimePressed;

  bool get _isEnabled => canEdit && !isSaving;

  @override
  Widget build(BuildContext context) {
    final effectiveReminder = isPast
        ? const CoupleCalendarEventReminder.disabled()
        : reminder;

    return ListView(
      key: const Key('calendar-event-basic-step'),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        const _SectionLabel(label: '제목'),
        TextField(
          key: const Key('calendar-event-title-field'),
          controller: titleController,
          enabled: _isEnabled,
          maxLength: _titleMaxLength,
          textInputAction: TextInputAction.next,
          decoration: calendarEventInputDecoration('일정 제목'),
        ),
        const SizedBox(height: 24),
        const _SectionLabel(label: '날짜'),
        _SelectionRow(
          key: const Key('calendar-event-date'),
          icon: Icons.calendar_today_outlined,
          label: _formatDate(selectedDate),
          enabled: _isEnabled,
          onTap: onDatePressed,
        ),
        const SizedBox(height: 24),
        const _SectionLabel(label: '반복'),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<CoupleCalendarEventRepeatRule>(
            segments: const [
              ButtonSegment(
                value: CoupleCalendarEventRepeatRule.none,
                label: Text('반복 안 함'),
              ),
              ButtonSegment(
                value: CoupleCalendarEventRepeatRule.yearly,
                label: Text('매년 반복'),
              ),
            ],
            selected: {repeatRule},
            showSelectedIcon: false,
            onSelectionChanged: _isEnabled
                ? (value) => onRepeatRuleChanged(value.single)
                : null,
          ),
        ),
        const SizedBox(height: 24),
        const _SectionLabel(label: '알림'),
        SwitchListTile(
          key: const Key('calendar-event-reminder-toggle'),
          contentPadding: EdgeInsets.zero,
          title: const Text('이 일정 알림 받기'),
          subtitle: isPast ? const Text('지난 일정에는 알림을 설정할 수 없어요') : null,
          value: effectiveReminder.isEnabled,
          onChanged: _isEnabled && !isPast ? onReminderEnabledChanged : null,
        ),
        if (effectiveReminder.isEnabled) ...[
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            key: const Key('calendar-event-reminder-offset'),
            initialValue: effectiveReminder.offsetDays,
            decoration: calendarEventInputDecoration('알림 시점'),
            items: const [
              DropdownMenuItem(value: 0, child: Text('당일')),
              DropdownMenuItem(value: 1, child: Text('1일 전')),
              DropdownMenuItem(value: 3, child: Text('3일 전')),
              DropdownMenuItem(value: 7, child: Text('7일 전')),
            ],
            onChanged: _isEnabled
                ? (value) {
                    if (value != null) {
                      onReminderOffsetChanged(value);
                    }
                  }
                : null,
          ),
          const SizedBox(height: 12),
          _SelectionRow(
            key: const Key('calendar-event-reminder-time'),
            icon: Icons.schedule_outlined,
            label: TimeOfDay(
              hour: effectiveReminder.hour,
              minute: effectiveReminder.minute,
            ).format(context),
            enabled: _isEnabled,
            onTap: onReminderTimePressed,
          ),
        ],
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(label, style: AppTextStyles.homeBodyMedium),
    );
  }
}

class _SelectionRow extends StatelessWidget {
  const _SelectionRow({
    super.key,
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF4F4F4),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Icon(icon, size: 20, color: AppColors.textMuted),
              const SizedBox(width: 12),
              Text(label, style: AppTextStyles.homeBody),
              const Spacer(),
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

InputDecoration calendarEventInputDecoration(String hintText) {
  return InputDecoration(
    hintText: hintText,
    filled: true,
    fillColor: const Color(0xFFF4F4F4),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: const BorderSide(color: AppColors.textPrimary),
    ),
  );
}

String _formatDate(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year.$month.$day';
}
