enum SafetyReportTargetType {
  partner('partner'),
  storyCard('story_card'),
  questionAnswer('question_answer'),
  recording('recording'),
  calendarEvent('calendar_event'),
  character('character'),
  aiQuestion('ai_question'),
  aiFeedback('ai_feedback'),
  aiDirectAnswer('ai_direct_answer'),
  aiProactiveSuggestion('ai_proactive_suggestion'),
  aiMemory('ai_memory');

  const SafetyReportTargetType(this.rpcValue);

  final String rpcValue;
}

enum SafetyReportReason {
  inappropriate('inappropriate'),
  harassment('harassment'),
  privacy('privacy'),
  spam('spam'),
  unsafeAi('unsafe_ai'),
  other('other');

  const SafetyReportReason(this.rpcValue);

  final String rpcValue;
}

class SafetyReportTarget {
  const SafetyReportTarget({
    required this.type,
    required this.id,
    this.contentSnapshot,
  });

  final SafetyReportTargetType type;
  final String id;
  final String? contentSnapshot;
}

class SafetyReportRequest {
  const SafetyReportRequest({
    required this.target,
    required this.reason,
    this.details,
  });

  final SafetyReportTarget target;
  final SafetyReportReason reason;
  final String? details;
}
