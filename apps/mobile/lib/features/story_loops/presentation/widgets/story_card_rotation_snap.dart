import 'dart:math' as math;

const storyCardRotationSnapEnterThreshold = 4 * math.pi / 180;
const storyCardRotationSnapReleaseThreshold = 7 * math.pi / 180;

class StoryCardRotationSnapResult {
  const StoryCardRotationSnapResult({
    required this.angle,
    required this.isSnapped,
    required this.didSnap,
  });

  final double angle;
  final bool isSnapped;
  final bool didSnap;
}

class StoryCardRotationSnapController {
  StoryCardRotationSnapController({
    this.enterThreshold = storyCardRotationSnapEnterThreshold,
    this.releaseThreshold = storyCardRotationSnapReleaseThreshold,
  }) : assert(enterThreshold >= 0),
       assert(releaseThreshold >= enterThreshold);

  final double enterThreshold;
  final double releaseThreshold;

  double? _lockedAngle;

  void begin(double angle) {
    final target = _nearestRightAngle(angle);
    _lockedAngle = (angle - target).abs() <= enterThreshold ? target : null;
  }

  StoryCardRotationSnapResult resolve(double angle) {
    final lockedAngle = _lockedAngle;
    if (lockedAngle != null &&
        (angle - lockedAngle).abs() <= releaseThreshold) {
      return StoryCardRotationSnapResult(
        angle: _normalizeAngle(lockedAngle),
        isSnapped: true,
        didSnap: false,
      );
    }

    _lockedAngle = null;
    final target = _nearestRightAngle(angle);
    if ((angle - target).abs() <= enterThreshold) {
      _lockedAngle = target;
      return StoryCardRotationSnapResult(
        angle: _normalizeAngle(target),
        isSnapped: true,
        didSnap: true,
      );
    }

    return StoryCardRotationSnapResult(
      angle: _normalizeAngle(angle),
      isSnapped: false,
      didSnap: false,
    );
  }

  void end() {
    _lockedAngle = null;
  }
}

double _nearestRightAngle(double angle) {
  const rightAngle = math.pi / 2;
  return (angle / rightAngle).round() * rightAngle;
}

double _normalizeAngle(double angle) {
  final normalized = angle % (math.pi * 2);
  return normalized < 0 ? normalized + math.pi * 2 : normalized;
}
