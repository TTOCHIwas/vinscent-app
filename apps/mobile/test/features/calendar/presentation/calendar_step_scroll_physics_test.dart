import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/calendar/presentation/calendar_month_layout_metrics.dart';
import 'package:vinscent/features/calendar/presentation/calendar_step_scroll_physics.dart';
import 'package:vinscent/features/calendar/presentation/calendar_viewport_motion_controller.dart';

void main() {
  test('suppresses fling only while a viewport transition is active', () {
    final motionController = CalendarViewportMotionController();
    final physics = CalendarStepScrollPhysics(
      boundaryController: CalendarScrollBoundaryController(),
      motionController: motionController,
    );
    final metrics = FixedScrollMetrics(
      minScrollExtent: 0,
      maxScrollExtent: 1200,
      pixels: 300,
      viewportDimension: 700,
      axisDirection: AxisDirection.down,
      devicePixelRatio: 1,
    );

    motionController.begin(
      startState: CalendarViewportState.standard,
      startedInDetail: false,
    );
    motionController.applyUserOffset(-40);

    expect(physics.createBallisticSimulation(metrics, 2400), isNull);

    motionController.clear();

    expect(physics.createBallisticSimulation(metrics, 2400), isNotNull);
  });
}
