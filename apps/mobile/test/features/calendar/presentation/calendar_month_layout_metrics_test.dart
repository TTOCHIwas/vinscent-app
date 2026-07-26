import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/calendar/presentation/calendar_month_layout_metrics.dart';

void main() {
  test('fills the viewport while preserving standard and weekly extents', () {
    final metrics = CalendarMonthLayoutMetrics.forViewport(720);

    expect(metrics.expandedExtent, 720);
    expect(metrics.standardExtent, 414);
    expect(metrics.weeklyExtent, 108);
    expect(metrics.standardScrollOffset, 306);
    expect(metrics.weeklyScrollOffset, 612);
  });

  test('does not exceed a compact viewport', () {
    final metrics = CalendarMonthLayoutMetrics.forViewport(460);

    expect(metrics.expandedExtent, 460);
    expect(metrics.standardExtent, 364);
    expect(metrics.standardScrollOffset, 96);
  });

  test('resolves expanded standard and weekly calendar values', () {
    final metrics = CalendarMonthLayoutMetrics.forViewport(720);
    final expanded = metrics.resolve(0);
    final transitioning = metrics.resolve(metrics.standardScrollOffset / 2);
    final standard = metrics.resolve(metrics.standardScrollOffset);
    final weekly = metrics.resolve(metrics.weeklyScrollOffset);

    expect(expanded.rowHeight, greaterThan(standard.rowHeight));
    expect(expanded.expandedContentProgress, 1);
    expect(transitioning.expandedContentProgress, closeTo(0.5, 0.001));
    expect(standard.rowHeight, CalendarMonthLayoutMetrics.standardRowHeight);
    expect(standard.expandedContentProgress, 0);
    expect(standard.collapseProgress, 0);
    expect(weekly.rowHeight, CalendarMonthLayoutMetrics.weeklyRowHeight);
    expect(weekly.expandedContentProgress, 0);
    expect(weekly.collapseProgress, 1);
  });

  test('clamps adjacent-state thresholds between 48 and 72 pixels', () {
    final compact = CalendarMonthLayoutMetrics.forViewport(510);
    final regular = CalendarMonthLayoutMetrics.forViewport(720);

    expect(
      compact.transitionThreshold(
        CalendarViewportState.expanded,
        CalendarViewportState.standard,
      ),
      48,
    );
    expect(
      regular.transitionThreshold(
        CalendarViewportState.standard,
        CalendarViewportState.weekly,
      ),
      72,
    );
  });

  test('limits each calendar gesture to adjacent state boundaries', () {
    final metrics = CalendarMonthLayoutMetrics.forViewport(720);

    expect(
      metrics.gestureBoundary(
        state: CalendarViewportState.expanded,
        scrollOffset: 0,
        maxScrollExtent: 1200,
      ),
      CalendarScrollBoundary(
        minOffset: 0,
        maxOffset: metrics.standardScrollOffset,
        startedInDetail: false,
      ),
    );
    expect(
      metrics.gestureBoundary(
        state: CalendarViewportState.standard,
        scrollOffset: metrics.standardScrollOffset,
        maxScrollExtent: 1200,
      ),
      CalendarScrollBoundary(
        minOffset: 0,
        maxOffset: metrics.weeklyScrollOffset,
        startedInDetail: false,
      ),
    );
    expect(
      metrics.gestureBoundary(
        state: CalendarViewportState.weekly,
        scrollOffset: metrics.weeklyScrollOffset + 100,
        maxScrollExtent: 1200,
      ),
      CalendarScrollBoundary(
        minOffset: metrics.weeklyScrollOffset,
        maxOffset: 1200,
        startedInDetail: true,
      ),
    );
  });

  test(
    'uses displacement threshold instead of fling velocity for snapping',
    () {
      final metrics = CalendarMonthLayoutMetrics.forViewport(720);

      expect(
        metrics.resolveSnap(
          startState: CalendarViewportState.standard,
          startOffset: metrics.standardScrollOffset,
          currentOffset: metrics.standardScrollOffset - 47,
          startedInDetail: false,
        ),
        CalendarViewportSnap(
          state: CalendarViewportState.standard,
          offset: metrics.standardScrollOffset,
        ),
      );
      expect(
        metrics.resolveSnap(
          startState: CalendarViewportState.standard,
          startOffset: metrics.standardScrollOffset,
          currentOffset: metrics.weeklyScrollOffset,
          startedInDetail: false,
        ),
        CalendarViewportSnap(
          state: CalendarViewportState.weekly,
          offset: metrics.weeklyScrollOffset,
        ),
      );
      expect(
        metrics.resolveSnap(
          startState: CalendarViewportState.weekly,
          startOffset: metrics.weeklyScrollOffset + 100,
          currentOffset: metrics.weeklyScrollOffset,
          startedInDetail: true,
        ),
        isNull,
      );
    },
  );
}
