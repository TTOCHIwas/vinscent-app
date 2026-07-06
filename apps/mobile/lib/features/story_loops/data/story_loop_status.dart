enum StoryLoopStatus {
  waitingPartnerCard,
  questionGenerated,
  answeredByOne,
  completed;

  factory StoryLoopStatus.fromJson(String value) {
    return switch (value) {
      'waiting_partner_card' => StoryLoopStatus.waitingPartnerCard,
      'question_generated' => StoryLoopStatus.questionGenerated,
      'answered_by_one' => StoryLoopStatus.answeredByOne,
      'completed' => StoryLoopStatus.completed,
      _ => throw FormatException('Unknown story loop status: $value'),
    };
  }
}
