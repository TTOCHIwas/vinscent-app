enum AiDirectQuestionStatus { queued, processing, completed, failed }

class AiDirectQuestionEntry {
  const AiDirectQuestionEntry({
    required this.id,
    required this.questionText,
    required this.status,
    required this.answerText,
    required this.failureCode,
    required this.createdAt,
    required this.answeredAt,
  });

  factory AiDirectQuestionEntry.fromJson(Map<String, dynamic> json) {
    final status = _status(json['status']);
    final answerText = _optionalString(json, 'answer_text');
    if (status == AiDirectQuestionStatus.completed && answerText == null) {
      throw const FormatException(
        'Completed direct question requires an answer',
      );
    }

    return AiDirectQuestionEntry(
      id: _requiredString(json, 'id'),
      questionText: _requiredString(json, 'question_text'),
      status: status,
      answerText: answerText,
      failureCode: _optionalString(json, 'failure_code'),
      createdAt: _dateTime(json, 'created_at'),
      answeredAt: _optionalDateTime(json, 'answered_at'),
    );
  }

  final String id;
  final String questionText;
  final AiDirectQuestionStatus status;
  final String? answerText;
  final String? failureCode;
  final DateTime createdAt;
  final DateTime? answeredAt;

  bool get isPending =>
      status == AiDirectQuestionStatus.queued ||
      status == AiDirectQuestionStatus.processing;
}

class AiDirectQuestionHistory {
  const AiDirectQuestionHistory({
    required this.dailyLimit,
    required this.remainingCount,
    required this.questions,
  });

  factory AiDirectQuestionHistory.fromJson(Map<String, dynamic> json) {
    final dailyLimit = json['daily_limit'];
    final remainingCount = json['remaining_count'];
    final questions = json['questions'];
    if (dailyLimit is! int ||
        dailyLimit < 1 ||
        remainingCount is! int ||
        remainingCount < 0 ||
        remainingCount > dailyLimit ||
        questions is! List) {
      throw const FormatException('Invalid direct question history');
    }

    return AiDirectQuestionHistory(
      dailyLimit: dailyLimit,
      remainingCount: remainingCount,
      questions: questions
          .map((question) {
            if (question is! Map) {
              throw const FormatException(
                'Invalid direct question history entry',
              );
            }
            return AiDirectQuestionEntry.fromJson(
              Map<String, dynamic>.from(question),
            );
          })
          .toList(growable: false),
    );
  }

  final int dailyLimit;
  final int remainingCount;
  final List<AiDirectQuestionEntry> questions;

  bool get hasPendingQuestion =>
      questions.any((question) => question.isPending);
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Invalid $key');
  }
  return value.trim();
}

String? _optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Invalid $key');
  }
  return value.trim();
}

DateTime _dateTime(Map<String, dynamic> json, String key) {
  final value = _requiredString(json, key);
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw FormatException('Invalid $key');
  }
  return parsed;
}

DateTime? _optionalDateTime(Map<String, dynamic> json, String key) {
  if (json[key] == null) {
    return null;
  }
  return _dateTime(json, key);
}

AiDirectQuestionStatus _status(Object? value) {
  return switch (value) {
    'queued' => AiDirectQuestionStatus.queued,
    'processing' => AiDirectQuestionStatus.processing,
    'completed' => AiDirectQuestionStatus.completed,
    'failed' => AiDirectQuestionStatus.failed,
    _ => throw const FormatException('Invalid direct question status'),
  };
}
