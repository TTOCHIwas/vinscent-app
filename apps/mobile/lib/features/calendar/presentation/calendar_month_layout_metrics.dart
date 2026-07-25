class CalendarMonthLayoutMetrics {
  const CalendarMonthLayoutMetrics._();

  static const expandedRowHeight = 74.0;
  static const defaultRowHeight = 56.0;
  static const collapsedRowHeight = 60.0;
  static const expandedRowGap = 8.0;
  static const defaultRowGap = 6.0;
  static const collapsedRowGap = 6.0;
  static const expandedHorizontalPadding = 8.0;
  static const defaultHorizontalPadding = 16.0;
  static const collapsedHorizontalPadding = 16.0;

  static const expandedExtent = 532.0;
  static const defaultExtent = 414.0;
  static const collapsedExtent = 108.0;
  static const defaultScrollOffset = expandedExtent - defaultExtent;
  static const collapsedScrollOffset = expandedExtent - collapsedExtent;

  static CalendarMonthLayoutValues resolve(double shrinkOffset) {
    final offset = shrinkOffset.clamp(0.0, collapsedScrollOffset);
    if (offset <= defaultScrollOffset) {
      final progress = offset / defaultScrollOffset;
      return CalendarMonthLayoutValues(
        rowHeight: _lerp(expandedRowHeight, defaultRowHeight, progress),
        rowGap: _lerp(expandedRowGap, defaultRowGap, progress),
        horizontalPadding: _lerp(
          expandedHorizontalPadding,
          defaultHorizontalPadding,
          progress,
        ),
        collapseProgress: 0,
        eventIndicatorLimit: progress < 0.5 ? 2 : 1,
      );
    }

    final progress =
        (offset - defaultScrollOffset) /
        (collapsedScrollOffset - defaultScrollOffset);
    return CalendarMonthLayoutValues(
      rowHeight: _lerp(defaultRowHeight, collapsedRowHeight, progress),
      rowGap: _lerp(defaultRowGap, collapsedRowGap, progress),
      horizontalPadding: _lerp(
        defaultHorizontalPadding,
        collapsedHorizontalPadding,
        progress,
      ),
      collapseProgress: progress,
      eventIndicatorLimit: 1,
    );
  }

  static double snapTarget(double scrollOffset) {
    final offset = scrollOffset.clamp(0.0, collapsedScrollOffset);
    final expandedDefaultMidpoint = defaultScrollOffset / 2;
    final defaultCollapsedMidpoint =
        (defaultScrollOffset + collapsedScrollOffset) / 2;

    if (offset < expandedDefaultMidpoint) {
      return 0;
    }
    if (offset < defaultCollapsedMidpoint) {
      return defaultScrollOffset;
    }
    return collapsedScrollOffset;
  }

  static double _lerp(double start, double end, double progress) {
    return start + ((end - start) * progress);
  }
}

class CalendarMonthLayoutValues {
  const CalendarMonthLayoutValues({
    required this.rowHeight,
    required this.rowGap,
    required this.horizontalPadding,
    required this.collapseProgress,
    required this.eventIndicatorLimit,
  });

  final double rowHeight;
  final double rowGap;
  final double horizontalPadding;
  final double collapseProgress;
  final int eventIndicatorLimit;
}
