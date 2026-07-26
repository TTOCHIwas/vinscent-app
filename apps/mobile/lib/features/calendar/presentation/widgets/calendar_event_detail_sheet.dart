import 'package:flutter/material.dart';

import '../../../../core/presentation/widgets/word_boundary_text.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/couple_calendar_event.dart';
import 'calendar_event_artwork.dart';

Future<void> showCalendarEventDetailSheet({
  required BuildContext context,
  required CoupleCalendarEvent event,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    clipBehavior: Clip.antiAlias,
    builder: (context) => CalendarEventDetailSheet(event: event),
  );
}

class CalendarEventDetailSheet extends StatelessWidget {
  const CalendarEventDetailSheet({super.key, required this.event});

  final CoupleCalendarEvent event;

  @override
  Widget build(BuildContext context) {
    final memo = event.memo?.trim();

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          key: ValueKey('calendar-event-detail-sheet-${event.id}'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(child: _SheetHandle()),
            Padding(
              key: ValueKey('calendar-event-detail-sheet-header-${event.id}'),
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CalendarEventArtwork(event: event, size: 64),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: WordBoundaryText(
                        event.title,
                        style: AppTextStyles.sectionTitle,
                      ),
                    ),
                  ),
                  IconButton(
                    key: ValueKey(
                      'calendar-event-detail-sheet-close-${event.id}',
                    ),
                    tooltip: '닫기',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            if (memo != null && memo.isNotEmpty) ...[
              Text(
                '메모',
                style: AppTextStyles.homeCharacterLabel.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 8),
              WordBoundaryText(memo, style: AppTextStyles.homeBody),
              const SizedBox(height: 24),
            ],
            Column(
              children: [
                _EventMetadata(
                  icon: Icons.repeat_rounded,
                  label: switch (event.repeatRule) {
                    CoupleCalendarEventRepeatRule.none => '반복 안 함',
                    CoupleCalendarEventRepeatRule.yearly => '매년 반복',
                  },
                ),
                const SizedBox(height: 12),
                _EventMetadata(
                  icon: Icons.notifications_none_rounded,
                  label: _reminderLabel(context, event.reminder),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.settingsDivider,
        borderRadius: BorderRadius.circular(2),
      ),
      child: const SizedBox(width: 36, height: 4),
    );
  }
}

class _EventMetadata extends StatelessWidget {
  const _EventMetadata({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textMuted),
        const SizedBox(width: 6),
        Expanded(
          child: WordBoundaryText(
            label,
            style: AppTextStyles.homeCharacterLabel.copyWith(
              color: AppColors.textMuted,
            ),
          ),
        ),
      ],
    );
  }
}

String _reminderLabel(
  BuildContext context,
  CoupleCalendarEventReminder reminder,
) {
  if (!reminder.isEnabled) {
    return '알림 없음';
  }

  final offsetLabel = reminder.offsetDays == 0
      ? '당일'
      : '${reminder.offsetDays}일 전';
  final timeLabel = MaterialLocalizations.of(context).formatTimeOfDay(
    TimeOfDay(hour: reminder.hour, minute: reminder.minute),
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
  return '$offsetLabel $timeLabel 알림';
}
