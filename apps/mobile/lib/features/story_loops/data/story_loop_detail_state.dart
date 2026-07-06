import 'story_loop_detail.dart';

enum StoryLoopDetailUnavailableReason {
  unavailable,
  beforeRelationshipStartDate,
  futureDate,
}

sealed class StoryLoopDetailState {
  const StoryLoopDetailState({
    required this.targetDate,
  });

  final DateTime targetDate;
}

class LoadedStoryLoopDetailState extends StoryLoopDetailState {
  const LoadedStoryLoopDetailState({
    required super.targetDate,
    required this.detail,
  });

  final StoryLoopDetail detail;
}

class EmptyStoryLoopDetailState extends StoryLoopDetailState {
  const EmptyStoryLoopDetailState({
    required super.targetDate,
    required this.detail,
  });

  final StoryLoopDetail detail;
}

class UnavailableStoryLoopDetailState extends StoryLoopDetailState {
  const UnavailableStoryLoopDetailState({
    required super.targetDate,
    required this.reason,
  });

  final StoryLoopDetailUnavailableReason reason;
}
