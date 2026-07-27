import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/date/app_date_policy.dart';
import '../../../core/presentation/widgets/app_horizontal_page_transition.dart';
import '../../../core/presentation/widgets/app_horizontal_swipe_region.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../couple/application/couple_controller.dart';
import '../../couple/application/couple_current_date_provider.dart';
import '../../shell/presentation/widgets/shell_bottom_bar_visibility_notification.dart';
import '../application/calendar_cell_preview_mode_controller.dart';
import '../application/couple_anniversary_resolver.dart';
import '../data/calendar_cell_preview_mode.dart';
import 'calendar_date_navigation.dart';
import 'calendar_month_layout_metrics.dart';
import 'calendar_step_scroll_controller.dart';
import 'calendar_step_scroll_physics.dart';
import 'calendar_viewport_motion_controller.dart';
import 'widgets/calendar_cell_preview_filter_button.dart';
import 'widgets/calendar_detail_date_header.dart';
import 'widgets/calendar_responsive_month.dart';
import 'widgets/calendar_selected_day_detail.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key, this.initialDate});

  final DateTime? initialDate;

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  static const _dateNavigation = CalendarDateNavigation();
  static const _viewportSnapDuration = Duration(milliseconds: 180);
  static const _viewportSnapCurve = Cubic(0.22, 0.25, 0, 1);

  late final CalendarStepScrollController _scrollController;
  late final CalendarScrollBoundaryController _scrollBoundaryController;
  late final CalendarViewportMotionController _viewportMotionController;
  late DateTime _visibleMonth;
  DateTime? _selectedDate;
  CalendarMonthLayoutMetrics? _layoutMetrics;
  CalendarViewportState _viewportState = CalendarViewportState.standard;
  _CalendarGestureSession? _activeGesture;
  bool _didSetInitialScrollPosition = false;
  bool _isMetricAdjustmentScheduled = false;
  bool _shouldResetViewportAfterRouteChange = false;
  bool _isRouteViewportResetScheduled = false;
  int _gestureGeneration = 0;
  int _calendarPageRevision = 0;
  int _detailPageRevision = 0;
  AppHorizontalPageDirection _calendarPageDirection =
      AppHorizontalPageDirection.next;
  AppHorizontalPageDirection _detailPageDirection =
      AppHorizontalPageDirection.next;

  @override
  void initState() {
    super.initState();
    _viewportMotionController = CalendarViewportMotionController();
    _scrollController = CalendarStepScrollController(
      motionController: _viewportMotionController,
    );
    _scrollBoundaryController = CalendarScrollBoundaryController();
    final today = calendarDateOnly(ref.read(coupleCurrentDateProvider));
    final initialDate = clampCalendarDate(widget.initialDate ?? today);
    _visibleMonth = calendarMonthOnly(initialDate);
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
    final targetDate = clampCalendarDate(nextDate ?? today);
    final previousSelectedDate = _selectedDate;
    if (previousSelectedDate != null &&
        isSameCalendarDate(previousSelectedDate, targetDate)) {
      return;
    }
    final direction =
        previousSelectedDate != null &&
            targetDate.isBefore(previousSelectedDate)
        ? AppHorizontalPageDirection.previous
        : AppHorizontalPageDirection.next;
    _calendarPageRevision += 1;
    _calendarPageDirection = direction;
    _detailPageRevision += 1;
    _detailPageDirection = direction;
    _visibleMonth = calendarMonthOnly(targetDate);
    _selectedDate = targetDate;
    _prepareViewportForRouteChange();
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
    final previewMode = ref
        .watch(calendarCellPreviewModeControllerProvider)
        .asData
        ?.value;
    final selectedPreviewMode = previewMode ?? CalendarCellPreviewMode.all;
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

        final relationshipStartMonth = calendarMonthOnly(
          couple.relationshipStartDate!,
        );
        final selectedDate = _selectedDate;
        final selectedAnniversaryLabels = selectedDate == null
            ? const <String>[]
            : const CoupleAnniversaryResolver()
                  .resolve(
                    startDate: couple.relationshipStartDate!,
                    date: selectedDate,
                  )
                  .map((occurrence) => occurrence.label)
                  .toList(growable: false);
        final canGoPrevious = _canGoPrevious(relationshipStartMonth);
        final canGoNext = _canGoNext();

        return Column(
          children: [
            _CalendarMonthHeader(
              visibleMonth: _visibleMonth,
              canGoPrevious: canGoPrevious,
              canGoNext: canGoNext,
              previewMode: selectedPreviewMode,
              onPreviousPressed: canGoPrevious
                  ? () => _moveSelectedMonth(
                      -1,
                      relationshipStartDate: couple.relationshipStartDate!,
                    )
                  : null,
              onNextPressed: canGoNext
                  ? () => _moveSelectedMonth(
                      1,
                      relationshipStartDate: couple.relationshipStartDate!,
                    )
                  : null,
              onAddPressed: couple.canEditSharedData
                  ? () => _addEvent(
                      relationshipStartDate: couple.relationshipStartDate!,
                      today: today,
                    )
                  : null,
              onPreviewModeSelected: previewMode == null
                  ? null
                  : _selectPreviewMode,
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final metrics = CalendarMonthLayoutMetrics.forViewport(
                    constraints.maxHeight,
                  );
                  final detailHeaderExtent =
                      CalendarDetailDateHeader.resolveExtent(
                        context,
                        anniversaryLabels: selectedAnniversaryLabels,
                      );
                  _adoptLayoutMetrics(metrics);
                  _scheduleInitialScrollPosition(metrics);
                  _scheduleRouteViewportReset(metrics);
                  final detailMinHeight = math.max(
                    0.0,
                    constraints.maxHeight -
                        metrics.weeklyExtent -
                        detailHeaderExtent,
                  );

                  return NotificationListener<ScrollNotification>(
                    onNotification: _handleScrollNotification,
                    child: CustomScrollView(
                      key: const Key('calendar-scroll-view'),
                      controller: _scrollController,
                      physics: CalendarStepScrollPhysics(
                        boundaryController: _scrollBoundaryController,
                        motionController: _viewportMotionController,
                      ),
                      slivers: [
                        CalendarResponsiveMonth(
                          visibleMonth: _visibleMonth,
                          relationshipStartDate: couple.relationshipStartDate!,
                          selectedDate: _selectedDate,
                          selectedAnniversaryLabels: selectedAnniversaryLabels,
                          previewMode: previewMode,
                          calendarTransitionKey: _calendarPageRevision,
                          calendarTransitionDirection: _calendarPageDirection,
                          detailTransitionKey: _detailPageRevision,
                          detailTransitionDirection: _detailPageDirection,
                          onDatePressed: _handleDatePressed,
                          metrics: metrics,
                          onSwipeRight: () => _moveCalendarPeriod(
                            -1,
                            relationshipStartDate:
                                couple.relationshipStartDate!,
                          ),
                          onSwipeLeft: () => _moveCalendarPeriod(
                            1,
                            relationshipStartDate:
                                couple.relationshipStartDate!,
                          ),
                          onDetailSwipeRight: () => _moveSelectedDate(
                            -1,
                            relationshipStartDate:
                                couple.relationshipStartDate!,
                          ),
                          onDetailSwipeLeft: () => _moveSelectedDate(
                            1,
                            relationshipStartDate:
                                couple.relationshipStartDate!,
                          ),
                          detailHeaderExtent: detailHeaderExtent,
                        ),
                        SliverToBoxAdapter(
                          child: AppHorizontalSwipeRegion(
                            key: const Key('calendar-detail-swipe-region'),
                            onSwipeRight: () => _moveSelectedDate(
                              -1,
                              relationshipStartDate:
                                  couple.relationshipStartDate!,
                            ),
                            onSwipeLeft: () => _moveSelectedDate(
                              1,
                              relationshipStartDate:
                                  couple.relationshipStartDate!,
                            ),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: detailMinHeight,
                              ),
                              child: Padding(
                                key: const Key('calendar-detail-padding'),
                                padding: EdgeInsets.fromLTRB(
                                  20,
                                  16,
                                  20,
                                  40 + bottomNavigationClearance,
                                ),
                                child: AppHorizontalPageTransition(
                                  key: const Key(
                                    'calendar-detail-content-transition',
                                  ),
                                  transitionKey: _detailPageRevision,
                                  direction: _detailPageDirection,
                                  child: _CalendarDetail(
                                    selectedDate: _selectedDate,
                                    today: today,
                                    hasDefaultAnniversary:
                                        selectedAnniversaryLabels.isNotEmpty,
                                    canEdit: couple.canEditSharedData,
                                  ),
                                ),
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
        );
      },
    );
  }

  bool _canGoPrevious(DateTime relationshipStartMonth) {
    return _visibleMonth.isAfter(relationshipStartMonth);
  }

  bool _canGoNext() {
    return _visibleMonth.isBefore(
      calendarMonthOnly(appCalendarLastSupportedDate),
    );
  }

  void _handleDatePressed(DateTime date) {
    final selectedDate = calendarDateOnly(date);
    setState(() {
      _selectedDate = selectedDate;
    });
    _replaceCalendarRoute(selectedDate);
  }

  void _moveCalendarPeriod(
    int offset, {
    required DateTime relationshipStartDate,
  }) {
    if (_viewportState == CalendarViewportState.weekly) {
      _moveSelectedWeek(offset, relationshipStartDate: relationshipStartDate);
      return;
    }
    _moveSelectedMonth(offset, relationshipStartDate: relationshipStartDate);
  }

  void _moveSelectedMonth(
    int monthOffset, {
    required DateTime relationshipStartDate,
  }) {
    final selectedDate = _selectedDate;
    if (selectedDate == null) {
      return;
    }
    final targetDate = _dateNavigation.moveByMonth(
      selectedDate: selectedDate,
      monthOffset: monthOffset,
      relationshipStartDate: relationshipStartDate,
    );
    if (targetDate != null) {
      _selectDate(
        targetDate,
        direction: _directionForOffset(monthOffset),
        animateCalendar: true,
        animateDetail: true,
      );
    }
  }

  void _moveSelectedWeek(
    int weekOffset, {
    required DateTime relationshipStartDate,
  }) {
    final selectedDate = _selectedDate;
    if (selectedDate == null) {
      return;
    }
    final targetDate = _dateNavigation.moveByWeek(
      selectedDate: selectedDate,
      weekOffset: weekOffset,
      relationshipStartDate: relationshipStartDate,
    );
    if (targetDate != null) {
      _selectDate(
        targetDate,
        direction: _directionForOffset(weekOffset),
        animateCalendar: true,
        animateDetail: true,
      );
    }
  }

  void _moveSelectedDate(
    int dayOffset, {
    required DateTime relationshipStartDate,
  }) {
    final selectedDate = _selectedDate;
    if (selectedDate == null) {
      return;
    }

    final targetDate = _dateNavigation.moveByDay(
      selectedDate: selectedDate,
      dayOffset: dayOffset,
      relationshipStartDate: relationshipStartDate,
    );
    if (targetDate != null) {
      _selectDate(
        targetDate,
        direction: _directionForOffset(dayOffset),
        animateCalendar: !isSameCalendarMonth(targetDate, selectedDate),
        animateDetail: true,
      );
    }
  }

  void _selectDate(
    DateTime date, {
    required AppHorizontalPageDirection direction,
    required bool animateCalendar,
    required bool animateDetail,
  }) {
    setState(() {
      if (animateCalendar) {
        _calendarPageRevision += 1;
        _calendarPageDirection = direction;
      }
      if (animateDetail) {
        _detailPageRevision += 1;
        _detailPageDirection = direction;
      }
      _selectedDate = date;
      _visibleMonth = calendarMonthOnly(date);
    });
    _replaceCalendarRoute(date);
  }

  void _replaceCalendarRoute(DateTime date) {
    final formattedDate = formatCalendarDate(date);
    final currentUri = GoRouterState.of(context).uri;
    if (currentUri.path == '/calendar' &&
        currentUri.queryParameters['date'] == formattedDate) {
      return;
    }
    context.replace('/calendar?date=$formattedDate');
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
    context.push('/calendar/event/new?date=${formatCalendarDate(initialDate)}');
  }

  Future<void> _selectPreviewMode(CalendarCellPreviewMode mode) async {
    try {
      await ref.read(calendarCellPreviewModeControllerProvider.future);
      if (!mounted) {
        return;
      }
      await ref
          .read(calendarCellPreviewModeControllerProvider.notifier)
          .selectMode(mode);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('캘린더 표시 설정을 저장하지 못했어요')));
    }
  }

  void _adoptLayoutMetrics(CalendarMonthLayoutMetrics metrics) {
    final previous = _layoutMetrics;
    if (previous == null) {
      _layoutMetrics = metrics;
      return;
    }
    if ((previous.expandedExtent - metrics.expandedExtent).abs() <= 0.5 &&
        (previous.standardExtent - metrics.standardExtent).abs() <= 0.5) {
      return;
    }

    final previousOffset = _scrollController.hasClients
        ? _scrollController.offset
        : previous.offsetFor(_viewportState);
    final detailOffset = math.max(
      0.0,
      previousOffset - previous.weeklyScrollOffset,
    );
    _layoutMetrics = metrics;
    if (!_didSetInitialScrollPosition || _isMetricAdjustmentScheduled) {
      return;
    }

    _isMetricAdjustmentScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isMetricAdjustmentScheduled = false;
      if (!mounted || !_scrollController.hasClients) {
        return;
      }
      final target = detailOffset > 0.5
          ? metrics.weeklyScrollOffset + detailOffset
          : metrics.offsetFor(_viewportState);
      _scrollController.jumpTo(
        target.clamp(0.0, _scrollController.position.maxScrollExtent),
      );
    });
  }

  void _scheduleInitialScrollPosition(CalendarMonthLayoutMetrics metrics) {
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
          metrics.standardScrollOffset,
          _scrollController.position.maxScrollExtent,
        ),
      );
    });
  }

  void _prepareViewportForRouteChange() {
    _gestureGeneration += 1;
    _activeGesture = null;
    _viewportState = CalendarViewportState.standard;
    _shouldResetViewportAfterRouteChange = true;
    _clearCalendarGesture();
  }

  void _scheduleRouteViewportReset(CalendarMonthLayoutMetrics metrics) {
    if (!_shouldResetViewportAfterRouteChange ||
        _isRouteViewportResetScheduled) {
      return;
    }

    _isRouteViewportResetScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isRouteViewportResetScheduled = false;
      if (!mounted || !_scrollController.hasClients) {
        return;
      }

      _shouldResetViewportAfterRouteChange = false;
      final target = metrics.standardScrollOffset.clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );
      _scrollController.jumpTo(target);
      const ShellBottomBarVisibilityNotification(
        isHidden: false,
      ).dispatch(context);
    });
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.depth != 0 || !_scrollController.hasClients) {
      return false;
    }

    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _beginCalendarGesture();
    } else if (notification is ScrollEndNotification) {
      final gesture = _activeGesture;
      if (gesture != null) {
        _activeGesture = null;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && gesture.generation == _gestureGeneration) {
            unawaited(_completeCalendarGesture(gesture));
          }
        });
      }
    }

    return false;
  }

  void _beginCalendarGesture() {
    final metrics = _layoutMetrics;
    if (metrics == null || !_scrollController.hasClients) {
      return;
    }

    final generation = ++_gestureGeneration;
    final offset = _scrollController.offset;
    final boundary = metrics.gestureBoundary(
      state: _viewportState,
      scrollOffset: offset,
      maxScrollExtent: _scrollController.position.maxScrollExtent,
    );
    _scrollBoundaryController.boundary = boundary;
    _viewportMotionController.begin(
      startState: _viewportState,
      startedInDetail: boundary.startedInDetail,
    );
    _activeGesture = _CalendarGestureSession(
      generation: generation,
      startState: _viewportState,
      startOffset: offset,
      boundary: boundary,
    );
  }

  Future<void> _completeCalendarGesture(_CalendarGestureSession gesture) async {
    final metrics = _layoutMetrics;
    if (gesture.generation != _gestureGeneration) {
      return;
    }
    if (metrics == null || !_scrollController.hasClients) {
      _clearCalendarGesture();
      return;
    }

    final currentOffset = _viewportMotionController.isViewportTransition
        ? gesture.startOffset +
              _viewportMotionController.effectiveScrollDisplacement
        : _scrollController.offset;
    final decision = metrics.resolveSnap(
      startState: gesture.startState,
      startOffset: gesture.startOffset,
      currentOffset: currentOffset,
      startedInDetail: gesture.boundary.startedInDetail,
    );
    if (decision == null) {
      _clearCalendarGesture();
      return;
    }

    if (_viewportState != decision.state) {
      _viewportState = decision.state;
      ShellBottomBarVisibilityNotification(
        isHidden: decision.state == CalendarViewportState.expanded,
      ).dispatch(context);
    }
    final target = decision.offset.clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    try {
      if ((target - _scrollController.offset).abs() > 0.5) {
        await _scrollController.animateTo(
          target,
          duration: _viewportSnapDuration,
          curve: _viewportSnapCurve,
        );
      }
    } finally {
      if (gesture.generation == _gestureGeneration) {
        _clearCalendarGesture();
      }
    }
  }

  void _clearCalendarGesture() {
    _scrollBoundaryController.clear();
    _viewportMotionController.clear();
  }
}

class _CalendarGestureSession {
  const _CalendarGestureSession({
    required this.generation,
    required this.startState,
    required this.startOffset,
    required this.boundary,
  });

  final int generation;
  final CalendarViewportState startState;
  final double startOffset;
  final CalendarScrollBoundary boundary;
}

class _CalendarMonthHeader extends StatelessWidget {
  const _CalendarMonthHeader({
    required this.visibleMonth,
    required this.canGoPrevious,
    required this.canGoNext,
    required this.previewMode,
    required this.onPreviousPressed,
    required this.onNextPressed,
    required this.onAddPressed,
    required this.onPreviewModeSelected,
  });

  final DateTime visibleMonth;
  final bool canGoPrevious;
  final bool canGoNext;
  final CalendarCellPreviewMode previewMode;
  final VoidCallback? onPreviousPressed;
  final VoidCallback? onNextPressed;
  final VoidCallback? onAddPressed;
  final ValueChanged<CalendarCellPreviewMode>? onPreviewModeSelected;

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
            child: CalendarCellPreviewFilterButton(
              key: const Key('calendar-cell-preview-filter'),
              selectedMode: previewMode,
              onSelected: onPreviewModeSelected,
            ),
          ),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MonthIconButton(
                  key: const Key('calendar-previous-month'),
                  icon: Icons.chevron_left,
                  semanticLabel: '이전 달',
                  onPressed: canGoPrevious ? onPreviousPressed : null,
                ),
                const SizedBox(width: 4),
                Text(
                  _formatMonth(visibleMonth),
                  maxLines: 1,
                  style: AppTextStyles.pageTitle,
                ),
                const SizedBox(width: 4),
                _MonthIconButton(
                  key: const Key('calendar-next-month'),
                  icon: Icons.chevron_right,
                  semanticLabel: '다음 달',
                  onPressed: canGoNext ? onNextPressed : null,
                ),
              ],
            ),
          ),
          Positioned(
            right: 12,
            top: 0,
            bottom: 0,
            child: _MonthIconButton(
              key: const Key('calendar-add-event'),
              icon: Icons.add,
              semanticLabel: '일정 추가',
              onPressed: onAddPressed,
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
    required this.hasDefaultAnniversary,
    required this.canEdit,
  });

  final DateTime? selectedDate;
  final DateTime today;
  final bool hasDefaultAnniversary;
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
      key: ValueKey('calendar-selected-detail-${formatCalendarDate(selected)}'),
      selectedDate: selected,
      today: today,
      hasDefaultAnniversary: hasDefaultAnniversary,
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

String _formatMonth(DateTime date) {
  return '${date.year}년 ${_twoDigits(date.month)}월';
}

String _twoDigits(int value) {
  return value.toString().padLeft(2, '0');
}

bool _isSameOptionalDate(DateTime? left, DateTime? right) {
  if (left == null || right == null) {
    return left == right;
  }
  return isSameCalendarDate(left, right);
}

AppHorizontalPageDirection _directionForOffset(int offset) {
  return offset < 0
      ? AppHorizontalPageDirection.previous
      : AppHorizontalPageDirection.next;
}
