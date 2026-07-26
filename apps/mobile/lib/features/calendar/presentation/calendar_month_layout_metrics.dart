import 'dart:math' as math;

enum CalendarViewportState { expanded, standard, weekly }

class CalendarMonthLayoutMetrics {
  const CalendarMonthLayoutMetrics._({
    required this.expandedExtent,
    required this.standardExtent,
  });

  factory CalendarMonthLayoutMetrics.forViewport(double viewportExtent) {
    final expandedExtent = math.max(viewportExtent, weeklyCalendarExtent);
    final standardExtent = math.max(
      weeklyCalendarExtent,
      math.min(
        standardCalendarExtent,
        expandedExtent - minimumExpandedStandardDistance,
      ),
    );
    return CalendarMonthLayoutMetrics._(
      expandedExtent: expandedExtent,
      standardExtent: standardExtent,
    );
  }

  static const standardRowHeight = 56.0;
  static const weeklyRowHeight = 60.0;
  static const standardRowGap = 6.0;
  static const weeklyRowGap = 6.0;
  static const standardHorizontalPadding = 16.0;
  static const weeklyHorizontalPadding = 16.0;
  static const standardCalendarExtent = 414.0;
  static const weeklyCalendarExtent = 108.0;
  static const minimumExpandedStandardDistance = 96.0;
  static const minimumTransitionThreshold = 48.0;
  static const maximumTransitionThreshold = 72.0;

  static const _expandedRowGap = 8.0;
  static const _expandedHorizontalPadding = 8.0;
  static const _expandedFixedHeight = 88.0;

  final double expandedExtent;
  final double standardExtent;

  double get weeklyExtent => weeklyCalendarExtent;

  double get expandedRowHeight => (expandedExtent - _expandedFixedHeight) / 6;

  double get standardScrollOffset => expandedExtent - standardExtent;

  double get weeklyScrollOffset => expandedExtent - weeklyCalendarExtent;

  CalendarMonthLayoutValues resolve(double shrinkOffset) {
    final offset = shrinkOffset.clamp(0.0, weeklyScrollOffset);
    if (offset <= standardScrollOffset) {
      final progress = standardScrollOffset == 0
          ? 1.0
          : offset / standardScrollOffset;
      return CalendarMonthLayoutValues(
        rowHeight: _lerp(expandedRowHeight, standardRowHeight, progress),
        rowGap: _lerp(_expandedRowGap, standardRowGap, progress),
        horizontalPadding: _lerp(
          _expandedHorizontalPadding,
          standardHorizontalPadding,
          progress,
        ),
        expandedContentProgress: 1 - progress,
        collapseProgress: 0,
      );
    }

    final progress =
        (offset - standardScrollOffset) /
        (weeklyScrollOffset - standardScrollOffset);
    return CalendarMonthLayoutValues(
      rowHeight: _lerp(standardRowHeight, weeklyRowHeight, progress),
      rowGap: _lerp(standardRowGap, weeklyRowGap, progress),
      horizontalPadding: _lerp(
        standardHorizontalPadding,
        weeklyHorizontalPadding,
        progress,
      ),
      expandedContentProgress: 0,
      collapseProgress: progress,
    );
  }

  double offsetFor(CalendarViewportState state) {
    return switch (state) {
      CalendarViewportState.expanded => 0,
      CalendarViewportState.standard => standardScrollOffset,
      CalendarViewportState.weekly => weeklyScrollOffset,
    };
  }

  double transitionThreshold(
    CalendarViewportState from,
    CalendarViewportState to,
  ) {
    final distance = (offsetFor(from) - offsetFor(to)).abs();
    return (distance * 0.25).clamp(
      minimumTransitionThreshold,
      maximumTransitionThreshold,
    );
  }

  CalendarScrollBoundary gestureBoundary({
    required CalendarViewportState state,
    required double scrollOffset,
    required double maxScrollExtent,
  }) {
    final startedInDetail = scrollOffset > weeklyScrollOffset + 0.5;
    if (startedInDetail) {
      return CalendarScrollBoundary(
        minOffset: weeklyScrollOffset,
        maxOffset: maxScrollExtent,
        startedInDetail: true,
      );
    }

    return switch (state) {
      CalendarViewportState.expanded => CalendarScrollBoundary(
        minOffset: 0,
        maxOffset: standardScrollOffset,
        startedInDetail: false,
      ),
      CalendarViewportState.standard => CalendarScrollBoundary(
        minOffset: 0,
        maxOffset: weeklyScrollOffset,
        startedInDetail: false,
      ),
      CalendarViewportState.weekly => CalendarScrollBoundary(
        minOffset: standardScrollOffset,
        maxOffset: maxScrollExtent,
        startedInDetail: false,
      ),
    };
  }

  CalendarViewportSnap? resolveSnap({
    required CalendarViewportState startState,
    required double startOffset,
    required double currentOffset,
    required bool startedInDetail,
  }) {
    if (startedInDetail) {
      return null;
    }

    return switch (startState) {
      CalendarViewportState.expanded =>
        currentOffset - startOffset >=
                transitionThreshold(
                  CalendarViewportState.expanded,
                  CalendarViewportState.standard,
                )
            ? CalendarViewportSnap(
                state: CalendarViewportState.standard,
                offset: standardScrollOffset,
              )
            : const CalendarViewportSnap(
                state: CalendarViewportState.expanded,
                offset: 0,
              ),
      CalendarViewportState.standard =>
        currentOffset <=
                startOffset -
                    transitionThreshold(
                      CalendarViewportState.standard,
                      CalendarViewportState.expanded,
                    )
            ? const CalendarViewportSnap(
                state: CalendarViewportState.expanded,
                offset: 0,
              )
            : currentOffset >=
                  startOffset +
                      transitionThreshold(
                        CalendarViewportState.standard,
                        CalendarViewportState.weekly,
                      )
            ? CalendarViewportSnap(
                state: CalendarViewportState.weekly,
                offset: weeklyScrollOffset,
              )
            : CalendarViewportSnap(
                state: CalendarViewportState.standard,
                offset: standardScrollOffset,
              ),
      CalendarViewportState.weekly =>
        currentOffset > weeklyScrollOffset + 0.5
            ? null
            : currentOffset <=
                  startOffset -
                      transitionThreshold(
                        CalendarViewportState.weekly,
                        CalendarViewportState.standard,
                      )
            ? CalendarViewportSnap(
                state: CalendarViewportState.standard,
                offset: standardScrollOffset,
              )
            : CalendarViewportSnap(
                state: CalendarViewportState.weekly,
                offset: weeklyScrollOffset,
              ),
    };
  }

  static double _lerp(double start, double end, double progress) {
    return start + ((end - start) * progress);
  }
}

class CalendarScrollBoundary {
  const CalendarScrollBoundary({
    required this.minOffset,
    required this.maxOffset,
    required this.startedInDetail,
  });

  final double minOffset;
  final double maxOffset;
  final bool startedInDetail;

  @override
  bool operator ==(Object other) {
    return other is CalendarScrollBoundary &&
        other.minOffset == minOffset &&
        other.maxOffset == maxOffset &&
        other.startedInDetail == startedInDetail;
  }

  @override
  int get hashCode => Object.hash(minOffset, maxOffset, startedInDetail);
}

class CalendarViewportSnap {
  const CalendarViewportSnap({required this.state, required this.offset});

  final CalendarViewportState state;
  final double offset;

  @override
  bool operator ==(Object other) {
    return other is CalendarViewportSnap &&
        other.state == state &&
        other.offset == offset;
  }

  @override
  int get hashCode => Object.hash(state, offset);
}

class CalendarMonthLayoutValues {
  const CalendarMonthLayoutValues({
    required this.rowHeight,
    required this.rowGap,
    required this.horizontalPadding,
    required this.expandedContentProgress,
    required this.collapseProgress,
  });

  final double rowHeight;
  final double rowGap;
  final double horizontalPadding;
  final double expandedContentProgress;
  final double collapseProgress;
}
