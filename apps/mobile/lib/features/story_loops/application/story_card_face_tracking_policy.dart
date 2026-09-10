import 'story_card_face_effect.dart';

class StoryCardFaceTrackingPolicy {
  StoryCardFaceTrackingPolicy({
    this.smoothingFactor = 0.36,
    this.maxConsecutiveMisses = 2,
  }) : assert(smoothingFactor >= 0 && smoothingFactor <= 1),
       assert(maxConsecutiveMisses >= 0);

  final double smoothingFactor;
  final int maxConsecutiveMisses;

  StoryCardFaceObservation? _current;
  StoryCardCharacterSide? _characterSide;
  int _consecutiveMisses = 0;

  StoryCardFaceObservation? update(StoryCardFaceObservation? observation) {
    if (observation == null) {
      _consecutiveMisses += 1;
      if (_consecutiveMisses > maxConsecutiveMisses) {
        _current = null;
        _characterSide = null;
      }
      return _current;
    }

    _consecutiveMisses = 0;
    final characterSide = _characterSide ??=
        StoryCardCharacterPlacement.preferredSide(observation.normalizedBounds);
    final anchoredObservation = observation.withCharacterSide(characterSide);
    final previous = _current;
    _current = previous == null
        ? anchoredObservation
        : previous.interpolateTo(anchoredObservation, smoothingFactor);
    return _current;
  }

  void reset() {
    _current = null;
    _characterSide = null;
    _consecutiveMisses = 0;
  }
}
