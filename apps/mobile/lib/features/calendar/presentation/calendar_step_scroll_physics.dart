import 'package:flutter/widgets.dart';

import 'calendar_month_layout_metrics.dart';

class CalendarScrollBoundaryController {
  CalendarScrollBoundary? boundary;

  void clear() {
    boundary = null;
  }
}

class CalendarStepScrollPhysics extends ClampingScrollPhysics {
  const CalendarStepScrollPhysics({
    required this.boundaryController,
    super.parent,
  });

  final CalendarScrollBoundaryController boundaryController;

  @override
  CalendarStepScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return CalendarStepScrollPhysics(
      boundaryController: boundaryController,
      parent: buildParent(ancestor),
    );
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
