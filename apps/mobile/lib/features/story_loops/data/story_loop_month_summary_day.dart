import 'story_loop_card_preview.dart';
import 'story_loop_status.dart';

class StoryLoopMonthSummaryDay {
  const StoryLoopMonthSummaryDay({
    required this.coupleDate,
    required this.loopStatus,
    required this.cardCount,
    required this.cards,
  });

  final DateTime coupleDate;
  final StoryLoopStatus loopStatus;
  final int cardCount;
  final List<StoryLoopCardPreview> cards;
}
