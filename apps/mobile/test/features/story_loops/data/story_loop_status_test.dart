import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/story_loops/data/story_loop_status.dart';

void main() {
  test('parses supported story loop statuses', () {
    expect(
      StoryLoopStatus.fromJson('waiting_partner_card'),
      StoryLoopStatus.waitingPartnerCard,
    );
    expect(
      StoryLoopStatus.fromJson('question_generated'),
      StoryLoopStatus.questionGenerated,
    );
    expect(
      StoryLoopStatus.fromJson('card_only_completed'),
      StoryLoopStatus.cardOnlyCompleted,
    );
    expect(
      StoryLoopStatus.fromJson('question_preparing'),
      StoryLoopStatus.questionPreparing,
    );
    expect(
      StoryLoopStatus.fromJson('answered_by_one'),
      StoryLoopStatus.answeredByOne,
    );
    expect(StoryLoopStatus.fromJson('completed'), StoryLoopStatus.completed);
  });

  test('throws on unknown story loop status', () {
    expect(
      () => StoryLoopStatus.fromJson('draft'),
      throwsFormatException,
    );
  });
}
