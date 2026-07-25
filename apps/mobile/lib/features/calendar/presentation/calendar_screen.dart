import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/date/app_date_policy.dart';
import '../../../core/presentation/widgets/app_horizontal_swipe_region.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../couple/application/couple_controller.dart';
import '../../couple/application/couple_current_date_provider.dart';
import 'calendar_month_layout_metrics.dart';
import 'widgets/calendar_responsive_month.dart';
import 'widgets/calendar_selected_day_detail.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key, this.initialDate});

  final DateTime? initialDate;

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late final ScrollController _scrollController;
  late DateTime _visibleMonth;
  DateTime? _selectedDate;
  bool _didSetInitialScrollPosition = false;
  bool _isSnapScheduled = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    final today = calendarDateOnly(ref.read(coupleCurrentDateProvider));
    final initialDate = calendarDateOnly(widget.initialDate ?? today);
    _visibleMonth = _monthOnly(initialDate);
    _selectedDate = initialDate;
  }

  @override
  void didUpdateWidget(covariant CalendarScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previousDate = oldWidget.initialDate;
    final nextDate = widget.initialDate;
    if (_isSameOptionalDate(previousDate, nextDate)) {
      return;
    }

    final today = calendarDateOnly(ref.read(coupleCurrentDateProvider));
    final targetDate = calendarDateOnly(nextDate ?? today);
    _visibleMonth = _monthOnly(targetDate);
    _selectedDate = targetDate;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(coupleCurrentDateProvider);
    final couple = ref.watch(coupleControllerProvider);
    final bottomNavigationClearance = MediaQuery.paddingOf(context).bottom;

    return couple.when(
      loading: () => const _CenteredLoader(),
      error: (error, stackTrace) => const _CalendarStateMessage(
        title: '커플 정보를 불러오지 못했어요',
        message: '잠시 후 다시 시도해 주세요',
      ),
      data: (couple) {
        if (couple == null ||
            !couple.canReadSharedData ||
            !couple.hasRelationshipStartDate) {
          return const _CalendarStateMessage(
            title: '달력을 볼 수 없어요',
            message: '커플 연결과 시작일 설정을 먼저 완료해 주세요',
          );
        }

        final relationshipStartMonth = _monthOnly(
          couple.relationshipStartDate!,
        );
        final canGoPrevious = _canGoPrevious(relationshipStartMonth);
        final canGoNext = _canGoNext();

        return AppHorizontalSwipeRegion(
          key: const Key('calendar-date-swipe-region'),
          onSwipeRight: () => _moveSelectedDate(
            -1,
            relationshipStartDate: couple.relationshipStartDate!,
          ),
          onSwipeLeft: () => _moveSelectedDate(
            1,
            relationshipStartDate: couple.relationshipStartDate!,
          ),
          child: Column(
            children: [
              _CalendarMonthHeader(
                visibleMonth: _visibleMonth,
                canGoPrevious: canGoPrevious,
                canGoNext: canGoNext,
                onPreviousPressed: canGoPrevious
                    ? () => _showPreviousMonth(relationshipStartMonth)
                    : null,
                onNextPressed: canGoNext ? _showNextMonth : null,
                onAddPressed: couple.canEditSharedData
                    ? () => _addEvent(
                        relationshipStartDate: couple.relationshipStartDate!,
                        today: today,
                      )
                    : null,
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    _scheduleInitialScrollPosition();
                    final detailMinHeight = math.max(
                      0.0,
                      constraints.maxHeight -
                          CalendarMonthLayoutMetrics.collapsedExtent,
                    );

                    return NotificationListener<ScrollEndNotification>(
                      onNotification: _handleScrollEnd,
                      child: CustomScrollView(
                        key: const Key('calendar-scroll-view'),
                        controller: _scrollController,
                        slivers: [
                          CalendarResponsiveMonth(
                            visibleMonth: _visibleMonth,
                            relationshipStartDate:
                                couple.relationshipStartDate!,
                            selectedDate: _selectedDate,
                            onDatePressed: _handleDatePressed,
                          ),
                          SliverToBoxAdapter(
                            child: Padding(
                              key: const Key('calendar-detail-padding'),
                              padding: EdgeInsets.fromLTRB(
                                20,
                                24,
                                20,
                                40 + bottomNavigationClearance,
                              ),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: detailMinHeight,
                                ),
                                child: _CalendarDetail(
                                  selectedDate: _selectedDate,
                                  today: today,
                                  relationshipStartDate:
                                      couple.relationshipStartDate!,
                                  canEdit: couple.canEditSharedData,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  bool _canGoPrevious(DateTime relationshipStartMonth) {
    return _visibleMonth.isAfter(relationshipStartMonth);
  }

  bool _canGoNext() {
    return _visibleMonth.isBefore(DateTime(2100, 12));
  }

  void _showPreviousMonth(DateTime relationshipStartMonth) {
    final previousMonth = DateTime(_visibleMonth.year, _visibleMonth.month - 1);
    if (previousMonth.isBefore(relationshipStartMonth)) {
      return;
    }

    setState(() {
      _visibleMonth = previousMonth;
      _selectedDate = null;
    });
  }

  void _showNextMonth() {
    final nextMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1);
    if (nextMonth.isAfter(DateTime(2100, 12))) {
      return;
    }

    setState(() {
      _visibleMonth = nextMonth;
      _selectedDate = null;
    });
  }

  void _handleDatePressed(DateTime date) {
    setState(() {
      _selectedDate = calendarDateOnly(date);
    });
  }

  void _moveSelectedDate(
    int dayOffset, {
    required DateTime relationshipStartDate,
  }) {
    final selectedDate = _selectedDate;
    if (selectedDate == null) {
      return;
    }

    final targetDate = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day + dayOffset,
    );
    final firstDate = calendarDateOnly(relationshipStartDate);
    if (targetDate.isBefore(firstDate) || targetDate.year > 2100) {
      return;
    }

    setState(() {
      _selectedDate = targetDate;
      _visibleMonth = _monthOnly(targetDate);
    });
  }

  void _addEvent({
    required DateTime relationshipStartDate,
    required DateTime today,
  }) {
    final selectedDate = _selectedDate;
    final initialDate =
        selectedDate != null &&
            !selectedDate.isBefore(calendarDateOnly(relationshipStartDate))
        ? selectedDate
        : calendarDateOnly(today);
    context.push('/calendar/event/new?date=${_formatRouteDate(initialDate)}');
  }

  void _scheduleInitialScrollPosition() {
    if (_didSetInitialScrollPosition) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _didSetInitialScrollPosition ||
          !_scrollController.hasClients) {
        return;
      }
      _didSetInitialScrollPosition = true;
      _scrollController.jumpTo(
        math.min(
          CalendarMonthLayoutMetrics.defaultScrollOffset,
          _scrollController.position.maxScrollExtent,
        ),
      );
    });
  }

  bool _handleScrollEnd(ScrollEndNotification notification) {
    if (notification.depth != 0 || !_scrollController.hasClients) {
      return false;
    }
    final offset = _scrollController.offset;
    if (offset > CalendarMonthLayoutMetrics.collapsedScrollOffset + 0.5) {
      return false;
    }
    final target = CalendarMonthLayoutMetrics.snapTarget(offset);
    if ((target - offset).abs() <= 0.5) {
      return false;
    }
    if (_isSnapScheduled) {
      return false;
    }
    _isSnapScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_snapToNearestCalendarState());
    });
    return false;
  }

  Future<void> _snapToNearestCalendarState() async {
    try {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }
      final offset = _scrollController.offset;
      if (offset > CalendarMonthLayoutMetrics.collapsedScrollOffset + 0.5) {
        return;
      }
      final target = CalendarMonthLayoutMetrics.snapTarget(offset);
      if ((target - offset).abs() <= 0.5) {
        return;
      }
      await _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    } finally {
      _isSnapScheduled = false;
    }
  }
}

class _CalendarMonthHeader extends StatelessWidget {
  const _CalendarMonthHeader({
    required this.visibleMonth,
    required this.canGoPrevious,
    required this.canGoNext,
    required this.onPreviousPressed,
    required this.onNextPressed,
    required this.onAddPressed,
  });

  final DateTime visibleMonth;
  final bool canGoPrevious;
  final bool canGoNext;
  final VoidCallback? onPreviousPressed;
  final VoidCallback? onNextPressed;
  final VoidCallback? onAddPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 12,
            top: 0,
            bottom: 0,
            child: _MonthIconButton(
              icon: Icons.chevron_left,
              semanticLabel: '이전 달',
              onPressed: canGoPrevious ? onPreviousPressed : null,
            ),
          ),
          Positioned(
            left: 92,
            right: 92,
            top: 0,
            bottom: 0,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _formatMonth(visibleMonth),
                  maxLines: 1,
                  style: AppTextStyles.pageTitle,
                ),
              ),
            ),
          ),
          Positioned(
            right: 12,
            top: 0,
            bottom: 0,
            child: Row(
              children: [
                _MonthIconButton(
                  icon: Icons.chevron_right,
                  semanticLabel: '다음 달',
                  onPressed: canGoNext ? onNextPressed : null,
                ),
                _MonthIconButton(
                  key: const Key('calendar-add-event'),
                  icon: Icons.add,
                  semanticLabel: '일정 추가',
                  onPressed: onAddPressed,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthIconButton extends StatelessWidget {
  const _MonthIconButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;

    return Semantics(
      button: true,
      label: semanticLabel,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: SizedBox.square(
          dimension: 40,
          child: Icon(
            icon,
            size: 24,
            color: enabled ? AppColors.textPrimary : AppColors.textPlaceholder,
          ),
        ),
      ),
    );
  }
}

class _CalendarDetail extends StatelessWidget {
  const _CalendarDetail({
    required this.selectedDate,
    required this.today,
    required this.relationshipStartDate,
    required this.canEdit,
  });

  final DateTime? selectedDate;
  final DateTime today;
  final DateTime relationshipStartDate;
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    final selected = selectedDate;
    if (selected == null) {
      return const _CalendarStateMessage(
        title: '날짜를 선택해 주세요',
        message: '질문 기록과 함께 일정을 확인할 수 있어요',
      );
    }

    return CalendarSelectedDayDetail(
      key: ValueKey('calendar-selected-detail-${_formatRouteDate(selected)}'),
      selectedDate: selected,
      today: today,
      relationshipStartDate: relationshipStartDate,
      canEdit: canEdit,
    );
  }
}

class _CenteredLoader extends StatelessWidget {
  const _CenteredLoader();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox.square(
        dimension: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}

class _CalendarStateMessage extends StatelessWidget {
  const _CalendarStateMessage({required this.title, required this.message});

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

DateTime _monthOnly(DateTime date) {
  return DateTime(date.year, date.month);
}

String _formatMonth(DateTime date) {
  return '${date.year}년 ${_twoDigits(date.month)}월';
}

String _twoDigits(int value) {
  return value.toString().padLeft(2, '0');
}

String _formatRouteDate(DateTime date) {
  return '${date.year.toString().padLeft(4, '0')}-'
      '${_twoDigits(date.month)}-${_twoDigits(date.day)}';
}

bool _isSameOptionalDate(DateTime? left, DateTime? right) {
  if (left == null || right == null) {
    return left == right;
  }
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}
