import 'package:flutter/material.dart';

import '../../../../core/presentation/widgets/word_boundary_text.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/couple_calendar_event.dart';
import 'calendar_event_artwork.dart';
import 'calendar_event_action_sheet.dart';
import 'calendar_event_detail_sheet.dart';

class CalendarEventDetailList extends StatelessWidget {
  const CalendarEventDetailList({
    super.key,
    required this.events,
    required this.canEdit,
    required this.onEdit,
    required this.onDelete,
    this.currentUserId,
    this.onReport,
  });

  final List<CoupleCalendarEvent> events;
  final bool canEdit;
  final ValueChanged<CoupleCalendarEvent> onEdit;
  final ValueChanged<CoupleCalendarEvent> onDelete;
  final String? currentUserId;
  final ValueChanged<CoupleCalendarEvent>? onReport;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
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
    final rows = [
      for (final event in sortedEvents)
        _EventRow(
          event: event,
          canEdit: canEdit,
          onOpen: () =>
              showCalendarEventDetailSheet(context: context, event: event),
          onEdit: () => onEdit(event),
          onDelete: () => onDelete(event),
          onReport:
              currentUserId != null &&
                  event.updatedByUserId != currentUserId &&
                  onReport != null
              ? () => onReport!(event)
              : null,
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

class _EventRow extends StatelessWidget {
  const _EventRow({
    required this.event,
    required this.canEdit,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
    required this.onReport,
  });

  final CoupleCalendarEvent event;
  final bool canEdit;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onReport;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(6);

    return Material(
      key: ValueKey('calendar-event-row-surface-${event.id}'),
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius,
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('calendar-event-open-${event.id}'),
        onTap: onOpen,
        splashColor: AppColors.settingsPressed,
        highlightColor: AppColors.settingsPressed,
        borderRadius: borderRadius,
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
              if (canEdit || onReport != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  key: ValueKey('calendar-event-menu-${event.id}'),
                  tooltip: '일정 메뉴',
                  onPressed: () => _openActionSheet(context),
                  icon: const Icon(Icons.more_horiz),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openActionSheet(BuildContext context) async {
    final action = await showCalendarEventActionSheet(
      context: context,
      eventId: event.id,
      showReport: onReport != null,
    );
    if (!context.mounted || action == null) {
      return;
    }

    switch (action) {
      case CalendarEventAction.edit:
        onEdit();
      case CalendarEventAction.report:
        onReport?.call();
      case CalendarEventAction.delete:
        onDelete();
    }
  }
}
