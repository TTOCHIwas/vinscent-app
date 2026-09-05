import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/couple_calendar_event.dart';
import 'calendar_event_form_style.dart';
import 'calendar_event_reminder_offset_sheet.dart';

class CoupleCalendarEventBasicForm extends StatelessWidget {
  const CoupleCalendarEventBasicForm({
    super.key,
    required this.titleController,
    required this.selectedDate,
    required this.repeatRule,
    required this.reminder,
    required this.canEdit,
    required this.isSaving,
    required this.isReminderUnavailable,
    required this.onDatePressed,
    required this.onRepeatRuleChanged,
    required this.onReminderEnabledChanged,
    required this.onReminderOffsetPressed,
    required this.onReminderTimePressed,
  });

  static const _titleMaxLength = 30;

  final TextEditingController titleController;
  final DateTime selectedDate;
  final CoupleCalendarEventRepeatRule repeatRule;
  final CoupleCalendarEventReminder reminder;
  final bool canEdit;
  final bool isSaving;
  final bool isReminderUnavailable;
  final VoidCallback onDatePressed;
  final ValueChanged<CoupleCalendarEventRepeatRule> onRepeatRuleChanged;
  final ValueChanged<bool> onReminderEnabledChanged;
  final VoidCallback onReminderOffsetPressed;
  final VoidCallback onReminderTimePressed;

  bool get _isEnabled => canEdit && !isSaving;

  @override
  Widget build(BuildContext context) {
    final effectiveReminder = isReminderUnavailable
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
          style: AppTextStyles.homeBody,
          textInputAction: TextInputAction.next,
          decoration: CalendarEventFormStyle.titleInputDecoration('일정 제목'),
        ),
        const SizedBox(height: 24),
        const _SectionLabel(label: '일정'),
        _FormGroup(
          children: [
            _SelectionRow(
              key: const Key('calendar-event-date'),
              icon: Icons.calendar_today_outlined,
              title: '날짜',
              value: _formatDate(selectedDate),
              enabled: _isEnabled,
              onTap: onDatePressed,
            ),
            const _FormDivider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '반복',
                    style: AppTextStyles.homeCharacterLabel.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SegmentedButton<CoupleCalendarEventRepeatRule>(
                    key: const Key('calendar-event-repeat-control'),
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
                    style: CalendarEventFormStyle.segmentedButton,
                    onSelectionChanged: _isEnabled
                        ? (value) => onRepeatRuleChanged(value.single)
                        : null,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const _SectionLabel(label: '알림'),
        _FormGroup(
          children: [
            SwitchListTile(
              key: const Key('calendar-event-reminder-toggle'),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              title: Text('이 일정 알림 받기', style: AppTextStyles.homeBodyMedium),
              subtitle: isReminderUnavailable
                  ? Text(
                      '지난 일회성 일정에는 설정할 수 없어요',
                      style: AppTextStyles.homeCharacterLabel.copyWith(
                        color: AppColors.textMuted,
                      ),
                    )
                  : null,
              activeThumbColor: AppColors.onSelection,
              activeTrackColor: AppColors.selection,
              value: effectiveReminder.isEnabled,
              onChanged: _isEnabled && !isReminderUnavailable
                  ? onReminderEnabledChanged
                  : null,
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: effectiveReminder.isEnabled
                  ? Column(
                      children: [
                        const _FormDivider(),
                        _SelectionRow(
                          key: const Key('calendar-event-reminder-offset'),
                          icon: Icons.notifications_active_outlined,
                          title: '알림 날짜',
                          value: calendarEventReminderOffsetLabel(
                            effectiveReminder.offsetDays,
                          ),
                          enabled: _isEnabled,
                          onTap: onReminderOffsetPressed,
                        ),
                        const _FormDivider(),
                        _SelectionRow(
                          key: const Key('calendar-event-reminder-time'),
                          icon: Icons.schedule_outlined,
                          title: '알림 시간',
                          value: TimeOfDay(
                            hour: effectiveReminder.hour,
                            minute: effectiveReminder.minute,
                          ).format(context),
                          enabled: _isEnabled,
                          onTap: onReminderTimePressed,
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
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
    required this.title,
    required this.value,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        splashColor: AppColors.settingsPressed,
        highlightColor: AppColors.settingsPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 20, color: AppColors.textMuted),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.homeCharacterLabel.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(value, style: AppTextStyles.homeBodyMedium),
                  ],
                ),
              ),
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

class _FormGroup extends StatelessWidget {
  const _FormGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(children: children);
  }
}

class _FormDivider extends StatelessWidget {
  const _FormDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(left: 50),
      child: Divider(height: 1, thickness: 1, color: AppColors.settingsDivider),
    );
  }
}

String _formatDate(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year.$month.$day';
}
