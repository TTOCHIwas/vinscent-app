enum StoryLoopStatus {
  waitingPartnerCard,
  cardOnlyCompleted,
  questionPreparing,
  questionGenerated,
  answeredByOne,
  completed;

  factory StoryLoopStatus.fromJson(String value) {
    return switch (value) {
      'waiting_partner_card' => StoryLoopStatus.waitingPartnerCard,
      'card_only_completed' => StoryLoopStatus.cardOnlyCompleted,
      'question_preparing' => StoryLoopStatus.questionPreparing,
      'question_generated' => StoryLoopStatus.questionGenerated,
      'answered_by_one' => StoryLoopStatus.answeredByOne,
      'completed' => StoryLoopStatus.completed,
      _ => throw FormatException('Unknown story loop status: $value'),
    };
  }
}
