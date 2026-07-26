import 'package:flutter/material.dart';

import '../../../../core/presentation/widgets/word_boundary_text.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../application/couple_anniversary_resolver.dart';
import '../../data/couple_calendar_event.dart';
import 'calendar_event_artwork.dart';

class CalendarEventDetailList extends StatefulWidget {
  const CalendarEventDetailList({
    super.key,
    required this.events,
    required this.anniversaries,
    required this.canEdit,
    required this.onEdit,
    required this.onDelete,
  });

  final List<CoupleCalendarEvent> events;
  final List<CoupleAnniversaryOccurrence> anniversaries;
  final bool canEdit;
  final ValueChanged<CoupleCalendarEvent> onEdit;
  final ValueChanged<CoupleCalendarEvent> onDelete;

  @override
  State<CalendarEventDetailList> createState() =>
      _CalendarEventDetailListState();
}

class _CalendarEventDetailListState extends State<CalendarEventDetailList> {
  String? _expandedEventId;

  @override
  void didUpdateWidget(covariant CalendarEventDetailList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_expandedEventId != null &&
        !widget.events.any((event) => event.id == _expandedEventId)) {
      _expandedEventId = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.events.isEmpty && widget.anniversaries.isEmpty) {
      return const SizedBox.shrink();
    }

    final sortedEvents = [...widget.events]
      ..sort((left, right) {
        final artworkOrder = (right.artwork == null ? 0 : 1).compareTo(
          left.artwork == null ? 0 : 1,
        );
        if (artworkOrder != 0) {
          return artworkOrder;
        }
        return left.title.compareTo(right.title);
      });
    final rows = <({String id, Widget child})>[
      for (final anniversary in widget.anniversaries)
        (
          id: 'anniversary-${anniversary.kind.name}',
          child: _AnniversaryRow(anniversary: anniversary),
        ),
      for (final event in sortedEvents)
        (
          id: event.id,
          child: _EventRow(
            event: event,
            isExpanded: _expandedEventId == event.id,
            canEdit: widget.canEdit,
            onToggle: () => _toggleEvent(event.id),
            onEdit: () => widget.onEdit(event),
            onDelete: () => widget.onDelete(event),
          ),
        ),
    ];

    return DecoratedBox(
      key: const Key('calendar-event-detail-surface'),
      decoration: const BoxDecoration(
        border: Border.symmetric(
          horizontal: BorderSide(color: AppColors.settingsDivider),
        ),
      ),
      child: Column(
        key: const Key('calendar-event-detail-list'),
        children: [
          for (var index = 0; index < rows.length; index++) ...[
            rows[index].child,
            if (index < rows.length - 1)
              Divider(
                key: Key('calendar-event-divider-${rows[index].id}'),
                height: 1,
                thickness: 1,
                indent: 56,
                color: AppColors.settingsDivider,
              ),
          ],
        ],
      ),
    );
  }

  void _toggleEvent(String eventId) {
    setState(() {
      _expandedEventId = _expandedEventId == eventId ? null : eventId;
    });
  }
}

class _AnniversaryRow extends StatelessWidget {
  const _AnniversaryRow({required this.anniversary});

  final CoupleAnniversaryOccurrence anniversary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: ValueKey('calendar-anniversary-detail-${anniversary.kind.name}'),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const SizedBox(width: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              anniversary.label,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({
    required this.event,
    required this.isExpanded,
    required this.canEdit,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final CoupleCalendarEvent event;
  final bool isExpanded;
  final bool canEdit;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      key: ValueKey('calendar-event-detail-${event.id}'),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: isExpanded ? const Color(0xFFF4F4F4) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(
          children: [
            InkWell(
              key: Key('calendar-event-toggle-${event.id}'),
              onTap: onToggle,
              splashColor: AppColors.settingsPressed,
              highlightColor: AppColors.settingsPressed,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    CalendarEventArtwork(event: event, size: 44),
                    const SizedBox(width: 12),
                    Expanded(
                      child: WordBoundaryText(
                        event.title,
                        maxLines: isExpanded ? null : 2,
                        overflow: isExpanded ? null : TextOverflow.ellipsis,
                        style: AppTextStyles.homeBodyMedium,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      isExpanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 22,
                      color: AppColors.textMuted,
                    ),
                    if (canEdit)
                      PopupMenuButton<_CalendarEventAction>(
                        key: ValueKey('calendar-event-menu-${event.id}'),
                        tooltip: '일정 메뉴',
                        icon: const Icon(Icons.more_horiz),
                        onSelected: (action) {
                          switch (action) {
                            case _CalendarEventAction.edit:
                              onEdit();
                            case _CalendarEventAction.delete:
                              onDelete();
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: _CalendarEventAction.edit,
                            child: Text('수정'),
                          ),
                          PopupMenuItem(
                            value: _CalendarEventAction.delete,
                            child: Text('삭제'),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            ClipRect(
              child: AnimatedSize(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: isExpanded
                    ? _EventExpandedDetail(
                        key: Key('calendar-event-expanded-${event.id}'),
                        event: event,
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventExpandedDetail extends StatelessWidget {
  const _EventExpandedDetail({super.key, required this.event});

  final CoupleCalendarEvent event;

  @override
  Widget build(BuildContext context) {
    final memo = event.memo?.trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(56, 4, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (memo != null && memo.isNotEmpty) ...[
            WordBoundaryText(memo, style: AppTextStyles.homeCharacterLabel),
            const SizedBox(height: 12),
          ],
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _EventMetadata(
                icon: Icons.repeat_rounded,
                label: switch (event.repeatRule) {
                  CoupleCalendarEventRepeatRule.none => '반복 안 함',
                  CoupleCalendarEventRepeatRule.yearly => '매년 반복',
                },
              ),
              _EventMetadata(
                icon: Icons.notifications_none_rounded,
                label: _reminderLabel(context, event.reminder),
              ),
            ],
          ),
        ],
      ),
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
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTextStyles.homeCharacterLabel.copyWith(
            color: AppColors.textMuted,
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

enum _CalendarEventAction { edit, delete }
