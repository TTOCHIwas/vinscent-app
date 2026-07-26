import 'package:flutter/material.dart';

import '../../../../core/presentation/widgets/word_boundary_text.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../application/couple_anniversary_resolver.dart';
import '../../data/couple_calendar_event.dart';
import 'calendar_event_artwork.dart';
import 'calendar_event_detail_sheet.dart';

class CalendarEventDetailList extends StatelessWidget {
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
  Widget build(BuildContext context) {
    if (events.isEmpty && anniversaries.isEmpty) {
      return const SizedBox.shrink();
    }

    final sortedEvents = [...events]
      ..sort((left, right) {
        final artworkOrder = (right.artwork == null ? 0 : 1).compareTo(
          left.artwork == null ? 0 : 1,
        );
        if (artworkOrder != 0) {
          return artworkOrder;
        }
        return left.title.compareTo(right.title);
      });
    final rows = <Widget>[
      for (final anniversary in anniversaries)
        _AnniversaryRow(anniversary: anniversary),
      for (final event in sortedEvents)
        _EventRow(
          event: event,
          canEdit: canEdit,
          onOpen: () =>
              showCalendarEventDetailSheet(context: context, event: event),
          onEdit: () => onEdit(event),
          onDelete: () => onDelete(event),
        ),
    ];

    return Column(
      key: const Key('calendar-event-detail-list'),
      children: [
        for (var index = 0; index < rows.length; index++) ...[
          if (index > 0) const SizedBox(height: 8),
          rows[index],
        ],
      ],
    );
  }
}

class _AnniversaryRow extends StatelessWidget {
  const _AnniversaryRow({required this.anniversary});

  final CoupleAnniversaryOccurrence anniversary;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: ValueKey('calendar-anniversary-detail-${anniversary.kind.name}'),
      color: const Color(0xFFF4F4F4),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Align(
          alignment: Alignment.centerLeft,
          child: WordBoundaryText(
            anniversary.label,
            style: AppTextStyles.homeBodyMedium,
          ),
        ),
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({
    required this.event,
    required this.canEdit,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  final CoupleCalendarEvent event;
  final bool canEdit;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: ValueKey('calendar-event-row-surface-${event.id}'),
      color: const Color(0xFFF4F4F4),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        key: ValueKey('calendar-event-open-${event.id}'),
        onTap: onOpen,
        splashColor: AppColors.settingsPressed,
        highlightColor: AppColors.settingsPressed,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          key: ValueKey('calendar-event-row-padding-${event.id}'),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CalendarEventArtwork(event: event, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: WordBoundaryText(
                  event.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.homeBodyMedium,
                ),
              ),
              if (canEdit) ...[
                const SizedBox(width: 8),
                PopupMenuButton<_CalendarEventAction>(
                  key: ValueKey('calendar-event-menu-${event.id}'),
                  tooltip: '일정 메뉴',
                  padding: EdgeInsets.zero,
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
            ],
          ),
        ),
      ),
    );
  }
}

enum _CalendarEventAction { edit, delete }
