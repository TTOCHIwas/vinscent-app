import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/date/app_date_policy.dart';
import '../../../../core/presentation/widgets/app_action_button.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../profile/application/profile_controller.dart';
import '../../../story_loops/application/story_loop_detail_provider.dart';
import '../../application/couple_anniversary_resolver.dart';
import '../../application/couple_calendar_event_provider.dart';
import '../../application/couple_calendar_event_realtime_controller.dart';
import '../../data/calendar_cell_preview_mode.dart';
import '../../data/couple_calendar_event.dart';
import '../../data/couple_calendar_event_failure.dart';
import '../../data/couple_calendar_event_repository.dart';
import 'calendar_event_detail_list.dart';
import 'calendar_story_loop_detail.dart';

class CalendarSelectedDayDetail extends ConsumerStatefulWidget {
  const CalendarSelectedDayDetail({
    super.key,
    required this.selectedDate,
    required this.today,
    required this.relationshipStartDate,
    required this.canEdit,
    required this.previewMode,
  });

  final DateTime selectedDate;
  final DateTime today;
  final DateTime relationshipStartDate;
  final bool canEdit;
  final CalendarCellPreviewMode previewMode;

  @override
  ConsumerState<CalendarSelectedDayDetail> createState() =>
      _CalendarSelectedDayDetailState();
}

class _CalendarSelectedDayDetailState
    extends ConsumerState<CalendarSelectedDayDetail> {
  final Set<String> _deletingEventIds = {};

  @override
  Widget build(BuildContext context) {
    final selectedDate = calendarDateOnly(widget.selectedDate);
    final selectedMonth = calendarMonthOnly(selectedDate);
    final calendarEvents = widget.previewMode.includesEvents
        ? ref.watch(coupleCalendarEventMonthProvider(selectedMonth))
        : ref.watch(coupleCalendarEventDateProvider(selectedDate));
    final events =
        calendarEvents.asData?.value
            .where(
              (event) => calendarDateOnly(event.occurrenceDate) == selectedDate,
            )
            .toList(growable: false) ??
        const <CoupleCalendarEvent>[];
    final anniversaries = const CoupleAnniversaryResolver().resolve(
      startDate: widget.relationshipStartDate,
      date: selectedDate,
    );
    final hasCalendarEntries = events.isNotEmpty || anniversaries.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (calendarEvents.hasError) ...[
          _CalendarEventLoadFailure(
            onRetry: () {
              if (widget.previewMode.includesEvents) {
                ref.invalidate(coupleCalendarEventMonthProvider(selectedMonth));
              } else {
                ref.invalidate(coupleCalendarEventDateProvider(selectedDate));
              }
            },
          ),
        ] else if (hasCalendarEntries) ...[
          CalendarEventDetailList(
            events: events,
            anniversaries: anniversaries,
            canEdit: widget.canEdit,
            onEdit: _editEvent,
            onDelete: _confirmDeleteEvent,
          ),
        ],
        if (selectedDate.isAfter(calendarDateOnly(widget.today))) ...[
          if (!hasCalendarEntries) ...[
            const SizedBox(height: 28),
            const _FutureDateMessage(),
          ],
        ] else ...[
          const SizedBox(height: 20),
          _StoryDetail(selectedDate: selectedDate),
        ],
      ],
    );
  }

  void _editEvent(CoupleCalendarEvent event) {
    context.push('/calendar/event/${event.id}');
  }

  Future<void> _confirmDeleteEvent(CoupleCalendarEvent event) async {
    if (_deletingEventIds.contains(event.id)) {
      return;
    }
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('일정을 삭제할까요?'),
        content: Text(event.title),
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
    if (shouldDelete != true || !mounted) {
      return;
    }

    setState(() {
      _deletingEventIds.add(event.id);
    });
    try {
      await ref
          .read(coupleCalendarEventRepositoryProvider)
          .deleteEvent(eventId: event.id, expectedRevision: event.revision);
      ref
          .read(coupleCalendarEventRealtimeControllerProvider.notifier)
          .refreshReadModels();
      if (mounted) {
        _showMessage('일정을 삭제했어요');
      }
    } catch (error) {
      if (mounted) {
        _showMessage(_deleteFailureMessage(error));
      }
    } finally {
      if (mounted) {
        setState(() {
          _deletingEventIds.remove(event.id);
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _deleteFailureMessage(Object error) {
    if (error is CoupleCalendarEventRepositoryException &&
        error.reason == CoupleCalendarEventFailureReason.conflict) {
      return '상대방이 일정을 먼저 수정했어요. 다시 확인해 주세요';
    }
    return '일정을 삭제하지 못했어요';
  }
}

class _StoryDetail extends ConsumerWidget {
  const _StoryDetail({required this.selectedDate});

  final DateTime selectedDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(
      profileControllerProvider.select(
        (state) => state.maybeWhen(data: (value) => value, orElse: () => null),
      ),
    );
    final detail = ref.watch(storyLoopDetailProvider(selectedDate));
    return detail.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: SizedBox.square(
            dimension: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (error, stackTrace) => _StoryDetailLoadFailure(
        onRetry: () => ref.invalidate(storyLoopDetailProvider(selectedDate)),
      ),
      data: (storyLoopState) => CalendarStoryLoopDetail(
        storyLoopState: storyLoopState,
        currentUserId: profile?.id,
        showDateHeader: false,
      ),
    );
  }
}

class _CalendarEventLoadFailure extends StatelessWidget {
  const _CalendarEventLoadFailure({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Text('일정을 불러오지 못했어요', style: AppTextStyles.homeCharacterLabel),
        ),
        TextButton(onPressed: onRetry, child: const Text('다시 시도')),
      ],
    );
  }
}

class _StoryDetailLoadFailure extends StatelessWidget {
  const _StoryDetailLoadFailure({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _StateMessage(title: '기록을 불러오지 못했어요', message: '잠시 후 다시 시도해 주세요'),
        const SizedBox(height: 16),
        AppActionButton(
          key: const Key('calendar-story-detail-retry'),
          label: '다시 시도',
          enabled: true,
          onPressed: onRetry,
          isSecondary: true,
        ),
      ],
    );
  }
}

class _FutureDateMessage extends StatelessWidget {
  const _FutureDateMessage();

  @override
  Widget build(BuildContext context) {
    return const _StateMessage(
      title: '아직 일정이 없어요',
      message: '함께 기억하고 싶은 날을 추가할 수 있어요',
    );
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyles.homeBodyMedium,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.homeCharacterLabel.copyWith(
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
