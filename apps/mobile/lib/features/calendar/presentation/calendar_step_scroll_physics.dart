import 'package:flutter/widgets.dart';

import 'calendar_month_layout_metrics.dart';
import 'calendar_viewport_motion_controller.dart';

class CalendarScrollBoundaryController {
  CalendarScrollBoundary? boundary;

  void clear() {
    boundary = null;
  }
}

class CalendarStepScrollPhysics extends ClampingScrollPhysics {
  const CalendarStepScrollPhysics({
    required this.boundaryController,
    required this.motionController,
    super.parent,
  });

  final CalendarScrollBoundaryController boundaryController;
  final CalendarViewportMotionController motionController;

  @override
  CalendarStepScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return CalendarStepScrollPhysics(
      boundaryController: boundaryController,
      motionController: motionController,
      parent: buildParent(ancestor),
    );
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    if (motionController.shouldSuppressBallisticMotion) {
      return null;
    }
    return super.createBallisticSimulation(position, velocity);
  }

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    final boundary = boundaryController.boundary;
    if (boundary != null) {
      if (value < boundary.minOffset) {
        return value - boundary.minOffset;
      }
      if (value > boundary.maxOffset) {
        return value - boundary.maxOffset;
      }
    }
    return super.applyBoundaryConditions(position, value);
  }
}
