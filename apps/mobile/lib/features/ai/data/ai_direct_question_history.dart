enum AiDirectQuestionStatus { queued, processing, completed, failed }

enum AiDirectQuestionResultKind { answered, insufficient }

enum AiDirectQuestionFollowUpStatus { pending, approved, dismissed }

class AiDirectQuestionFollowUp {
  const AiDirectQuestionFollowUp({
    required this.id,
    required this.questionText,
    required this.status,
    required this.sharedQuestionId,
  }) : assert(
         status == AiDirectQuestionFollowUpStatus.approved
             ? sharedQuestionId != null
             : sharedQuestionId == null,
       );

  factory AiDirectQuestionFollowUp.fromJson(Map<String, dynamic> json) {
    final status = _followUpStatus(json['status']);
    final sharedQuestionId = _optionalString(json, 'shared_question_id');
    if (status == AiDirectQuestionFollowUpStatus.approved) {
      if (sharedQuestionId == null) {
        throw const FormatException(
          'Approved follow-up requires a shared question id',
        );
      }
    } else if (sharedQuestionId != null) {
      throw const FormatException(
        'Undecided follow-up cannot have a shared question id',
      );
    }

    return AiDirectQuestionFollowUp(
      id: _requiredString(json, 'id'),
      questionText: _requiredString(json, 'question_text'),
      status: status,
      sharedQuestionId: sharedQuestionId,
    );
  }

  final String id;
  final String questionText;
  final AiDirectQuestionFollowUpStatus status;
  final String? sharedQuestionId;
}

class AiDirectQuestionEntry {
  const AiDirectQuestionEntry({
    required this.id,
    required this.questionText,
    required this.status,
    required this.resultKind,
    required this.answerText,
    required this.followUp,
    required this.failureCode,
    required this.createdAt,
    required this.answeredAt,
  }) : assert(
         status == AiDirectQuestionStatus.completed
             ? resultKind != null
             : resultKind == null,
       ),
       assert(
         resultKind == AiDirectQuestionResultKind.insufficient ||
             followUp == null,
       );

  factory AiDirectQuestionEntry.fromJson(Map<String, dynamic> json) {
    final status = _status(json['status']);
    final resultKind = _resultKind(json['result_kind'], status);
    final answerText = _optionalString(json, 'answer_text');
    final followUp = _optionalFollowUp(json['follow_up']);
    if (status == AiDirectQuestionStatus.completed && answerText == null) {
      throw const FormatException(
        'Completed direct question requires an answer',
      );
    }
    if (status != AiDirectQuestionStatus.completed && followUp != null) {
      throw const FormatException(
        'Incomplete direct question cannot have a follow-up',
      );
    }
    if (resultKind != AiDirectQuestionResultKind.insufficient &&
        followUp != null) {
      throw const FormatException(
        'Answered direct question cannot have a follow-up',
      );
    }

    return AiDirectQuestionEntry(
      id: _requiredString(json, 'id'),
      questionText: _requiredString(json, 'question_text'),
      status: status,
      resultKind: resultKind,
      answerText: answerText,
      followUp: followUp,
      failureCode: _optionalString(json, 'failure_code'),
      createdAt: _dateTime(json, 'created_at'),
      answeredAt: _optionalDateTime(json, 'answered_at'),
    );
  }

  final String id;
  final String questionText;
  final AiDirectQuestionStatus status;
  final AiDirectQuestionResultKind? resultKind;
  final String? answerText;
  final AiDirectQuestionFollowUp? followUp;
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

AiDirectQuestionResultKind? _resultKind(
  Object? value,
  AiDirectQuestionStatus status,
) {
  if (status != AiDirectQuestionStatus.completed) {
    if (value != null) {
      throw const FormatException(
        'Incomplete direct question cannot have a result kind',
      );
    }
    return null;
  }

  return switch (value) {
    null || 'answered' => AiDirectQuestionResultKind.answered,
    'insufficient' => AiDirectQuestionResultKind.insufficient,
    _ => throw const FormatException('Invalid direct question result kind'),
  };
}

AiDirectQuestionFollowUp? _optionalFollowUp(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is! Map) {
    throw const FormatException('Invalid direct question follow-up');
  }
  return AiDirectQuestionFollowUp.fromJson(Map<String, dynamic>.from(value));
}

AiDirectQuestionFollowUpStatus _followUpStatus(Object? value) {
  return switch (value) {
    'pending' => AiDirectQuestionFollowUpStatus.pending,
    'approved' => AiDirectQuestionFollowUpStatus.approved,
    'dismissed' => AiDirectQuestionFollowUpStatus.dismissed,
    _ => throw const FormatException(
      'Invalid direct question follow-up status',
    ),
  };
}
