import '../../couple/data/couple.dart';
import 'story_loop_card_preview.dart';
import 'story_loop_question_summary.dart';
import 'story_loop_status.dart';

class TodayStoryLoopSummary {
  const TodayStoryLoopSummary({
    required this.coupleId,
    required this.coupleDate,
    required this.accessMode,
    required this.storyEditLocked,
    required this.canEditStory,
    required this.canAnswerQuestion,
    required this.cardCount,
    required this.cards,
    this.loopId,
    this.loopStatus,
    this.question,
  });

  final String coupleId;
  final DateTime coupleDate;
  final CoupleAccessMode accessMode;
  final String? loopId;
  final StoryLoopStatus? loopStatus;
  final bool storyEditLocked;
  final bool canEditStory;
  final bool canAnswerQuestion;
  final int cardCount;
  final List<StoryLoopCardPreview> cards;
  final StoryLoopQuestionSummary? question;

  bool get isEmpty => loopId == null && cardCount == 0 && question == null;
}
