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

  @override
  bool operator ==(Object other) {
    return other is SafetyReportTarget &&
        other.type == type &&
        other.id == id &&
        other.contentSnapshot == contentSnapshot;
  }

  @override
  int get hashCode => Object.hash(type, id, contentSnapshot);
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

  @override
  bool operator ==(Object other) {
    return other is SafetyReportRequest &&
        other.target == target &&
        other.reason == reason &&
        other.details == details;
  }

  @override
  int get hashCode => Object.hash(target, reason, details);
}
