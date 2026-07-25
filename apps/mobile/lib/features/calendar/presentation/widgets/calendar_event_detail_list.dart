import 'package:flutter/material.dart';

import '../../application/couple_anniversary_resolver.dart';
import '../../data/couple_calendar_event.dart';
import 'calendar_event_artwork.dart';

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

    return Column(
      key: const Key('calendar-event-detail-list'),
      children: [
        for (final anniversary in anniversaries)
          _AnniversaryRow(anniversary: anniversary),
        for (final event in sortedEvents)
          _EventRow(
            event: event,
            canEdit: canEdit,
            onEdit: () => onEdit(event),
            onDelete: () => onDelete(event),
          ),
      ],
    );
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
    required this.canEdit,
    required this.onEdit,
    required this.onDelete,
  });

  final CoupleCalendarEvent event;
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: ValueKey('calendar-event-detail-${event.id}'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CalendarEventArtwork(event: event, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              event.title,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
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
    );
  }
}

enum _CalendarEventAction { edit, delete }
