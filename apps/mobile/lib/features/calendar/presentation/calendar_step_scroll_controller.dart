import 'package:flutter/widgets.dart';

import 'calendar_viewport_motion_controller.dart';

class CalendarStepScrollController extends ScrollController {
  CalendarStepScrollController({
    required this.motionController,
    super.initialScrollOffset,
    super.keepScrollOffset,
    super.debugLabel,
  });

  final CalendarViewportMotionController motionController;

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) {
    return _CalendarStepScrollPosition(
      physics: physics,
      context: context,
      motionController: motionController,
      initialPixels: initialScrollOffset,
      keepScrollOffset: keepScrollOffset,
      oldPosition: oldPosition,
      debugLabel: debugLabel,
    );
  }
}

class _CalendarStepScrollPosition extends ScrollPositionWithSingleContext {
  _CalendarStepScrollPosition({
    required super.physics,
    required super.context,
    required this.motionController,
    super.initialPixels,
    super.keepScrollOffset,
    super.oldPosition,
    super.debugLabel,
  });

  final CalendarViewportMotionController motionController;

  @override
  void applyUserOffset(double delta) {
    super.applyUserOffset(motionController.applyUserOffset(delta));
  }
}
