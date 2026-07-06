import 'today_story_loop_summary.dart';

enum TodayStoryLoopSummaryUnavailableReason {
  unavailable,
}

sealed class TodayStoryLoopSummaryState {
  const TodayStoryLoopSummaryState();
}

class LoadedTodayStoryLoopSummaryState extends TodayStoryLoopSummaryState {
  const LoadedTodayStoryLoopSummaryState({
    required this.summary,
  });

  final TodayStoryLoopSummary summary;
}

class EmptyTodayStoryLoopSummaryState extends TodayStoryLoopSummaryState {
  const EmptyTodayStoryLoopSummaryState({
    required this.summary,
  });

  final TodayStoryLoopSummary summary;
}

class UnavailableTodayStoryLoopSummaryState extends TodayStoryLoopSummaryState {
  const UnavailableTodayStoryLoopSummaryState({
    required this.reason,
  });

  final TodayStoryLoopSummaryUnavailableReason reason;
}
