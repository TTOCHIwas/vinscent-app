class AiFocusedQuestionHistoryEntry {
  const AiFocusedQuestionHistoryEntry({
    required this.questionId,
    required this.questionKey,
    required this.questionText,
    required this.learningDomain,
    required this.depth,
    required this.curriculumPosition,
    required this.myAnswerText,
    required this.partnerAnswerText,
  });

  factory AiFocusedQuestionHistoryEntry.fromJson(Map<String, dynamic> json) {
    final entry = AiFocusedQuestionHistoryEntry(
      questionId: _readString(json, 'question_id'),
      questionKey: _readString(json, 'question_key'),
      questionText: _readString(json, 'question_text'),
      learningDomain: _readString(json, 'learning_domain'),
      depth: _readString(json, 'question_depth'),
      curriculumPosition: _readInt(json, 'curriculum_position'),
      myAnswerText: _readString(json, 'my_answer_text'),
      partnerAnswerText: _readString(json, 'partner_answer_text'),
    );

    if (entry.curriculumPosition <= 0) {
      throw const FormatException('Invalid focused question history position');
    }

    return entry;
  }

  final String questionId;
  final String questionKey;
  final String questionText;
  final String learningDomain;
  final String depth;
  final int curriculumPosition;
  final String myAnswerText;
  final String partnerAnswerText;
}

String _readString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }

  throw FormatException('Invalid focused question history string: $key');
}

int _readInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is num) {
    return value.toInt();
  }

  throw FormatException('Invalid focused question history number: $key');
}
