import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/calendar/presentation/calendar_month_layout_metrics.dart';

void main() {
  test('resolves expanded default and collapsed calendar values', () {
    final expanded = CalendarMonthLayoutMetrics.resolve(0);
    final standard = CalendarMonthLayoutMetrics.resolve(
      CalendarMonthLayoutMetrics.defaultScrollOffset,
    );
    final collapsed = CalendarMonthLayoutMetrics.resolve(
      CalendarMonthLayoutMetrics.collapsedScrollOffset,
    );

    expect(expanded.rowHeight, CalendarMonthLayoutMetrics.expandedRowHeight);
    expect(expanded.eventIndicatorLimit, 2);
    expect(standard.rowHeight, CalendarMonthLayoutMetrics.defaultRowHeight);
    expect(standard.collapseProgress, 0);
    expect(collapsed.rowHeight, CalendarMonthLayoutMetrics.collapsedRowHeight);
    expect(collapsed.collapseProgress, 1);
  });

  test('snaps an interrupted transition to the nearest stable state', () {
    expect(CalendarMonthLayoutMetrics.snapTarget(20), 0);
    expect(
      CalendarMonthLayoutMetrics.snapTarget(100),
      CalendarMonthLayoutMetrics.defaultScrollOffset,
    );
    expect(
      CalendarMonthLayoutMetrics.snapTarget(400),
      CalendarMonthLayoutMetrics.collapsedScrollOffset,
    );
  });
}
