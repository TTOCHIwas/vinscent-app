import 'calendar_month_layout_metrics.dart';

class CalendarViewportMotionController {
  CalendarViewportMotionController({
    this.deadZone = 20,
    this.dragResistance = 0.32,
  }) : assert(deadZone >= 0),
       assert(dragResistance > 0 && dragResistance <= 1);

  final double deadZone;
  final double dragResistance;

  CalendarViewportState? _startState;
  _CalendarGestureMode _mode = _CalendarGestureMode.idle;
  double _rawUserOffset = 0;
  double _appliedUserOffset = 0;

  bool get isViewportTransition =>
      _mode == _CalendarGestureMode.viewportTransition;

  bool get shouldSuppressBallisticMotion => isViewportTransition;

  double get effectiveScrollDisplacement {
    if (!isViewportTransition) {
      return 0;
    }
    return -_outsideDeadZone(_rawUserOffset);
  }

  void begin({
    required CalendarViewportState startState,
    required bool startedInDetail,
  }) {
    _startState = startState;
    _mode = startedInDetail
        ? _CalendarGestureMode.detailScroll
        : _CalendarGestureMode.undecided;
    _rawUserOffset = 0;
    _appliedUserOffset = 0;
  }

  double applyUserOffset(double offset) {
    if (offset == 0) {
      return 0;
    }

    if (_mode == _CalendarGestureMode.idle) {
      return offset;
    }
    if (_mode == _CalendarGestureMode.detailScroll) {
      return offset;
    }
    if (_mode == _CalendarGestureMode.undecided) {
      if (_startState == CalendarViewportState.weekly && offset < 0) {
        _mode = _CalendarGestureMode.detailScroll;
        return offset;
      }
      _mode = _CalendarGestureMode.viewportTransition;
    }

    _rawUserOffset += offset;
    final targetUserOffset = _outsideDeadZone(_rawUserOffset) * dragResistance;
    final appliedDelta = targetUserOffset - _appliedUserOffset;
    _appliedUserOffset = targetUserOffset;
    return appliedDelta;
  }

  void clear() {
    _startState = null;
    _mode = _CalendarGestureMode.idle;
    _rawUserOffset = 0;
    _appliedUserOffset = 0;
  }

  double _outsideDeadZone(double value) {
    final magnitude = value.abs();
    if (magnitude <= deadZone) {
      return 0;
    }
    return value.sign * (magnitude - deadZone);
  }
}

enum _CalendarGestureMode { idle, undecided, viewportTransition, detailScroll }
