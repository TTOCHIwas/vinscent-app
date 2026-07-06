class StoryLoopDetailNavigationState {
  const StoryLoopDetailNavigationState({
    required this.currentDate,
    this.previousDate,
    this.nextDate,
  });

  final DateTime currentDate;
  final DateTime? previousDate;
  final DateTime? nextDate;

  bool get canMovePrevious => previousDate != null;

  bool get canMoveNext => nextDate != null;
}
