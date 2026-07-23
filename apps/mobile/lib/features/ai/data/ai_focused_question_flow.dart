enum AiFocusedQuestionStatus {
  answering,
  waitingPartner,
  completed;

  factory AiFocusedQuestionStatus.fromJson(String value) {
    return switch (value) {
      'answering' => AiFocusedQuestionStatus.answering,
      'waiting_partner' => AiFocusedQuestionStatus.waitingPartner,
      'completed' => AiFocusedQuestionStatus.completed,
      _ => throw FormatException('Unknown focused question status: $value'),
    };
  }
}

class AiFocusedQuestionProgress {
  const AiFocusedQuestionProgress({
    required this.curriculumVersion,
    required this.myAnsweredCount,
    required this.partnerAnsweredCount,
    required this.coupleCompletedCount,
    required this.totalCount,
  });

  factory AiFocusedQuestionProgress.fromJson(Map<String, dynamic> json) {
    final progress = AiFocusedQuestionProgress(
      curriculumVersion: _readInt(json, 'curriculum_version'),
      myAnsweredCount: _readInt(json, 'my_answered_count'),
      partnerAnsweredCount: _readInt(json, 'partner_answered_count'),
      coupleCompletedCount: _readInt(json, 'couple_completed_count'),
      totalCount: _readInt(json, 'total_count'),
    );

    if (progress.curriculumVersion <= 0 ||
        progress.totalCount <= 0 ||
        progress.myAnsweredCount < 0 ||
        progress.partnerAnsweredCount < 0 ||
        progress.coupleCompletedCount < 0 ||
        progress.myAnsweredCount > progress.totalCount ||
        progress.partnerAnsweredCount > progress.totalCount ||
        progress.coupleCompletedCount > progress.totalCount) {
      throw const FormatException('Invalid focused question progress');
    }

    return progress;
  }

  final int curriculumVersion;
  final int myAnsweredCount;
  final int partnerAnsweredCount;
  final int coupleCompletedCount;
  final int totalCount;

  double get myCompletionRatio {
    return (myAnsweredCount / totalCount).clamp(0.0, 1.0).toDouble();
  }
}

class AiFocusedQuestion {
  const AiFocusedQuestion({
    required this.id,
    required this.key,
    required this.text,
    required this.learningDomain,
    required this.depth,
    required this.curriculumPosition,
    required this.partnerAnswered,
  });

  factory AiFocusedQuestion.fromJson(Map<String, dynamic> json) {
    return AiFocusedQuestion(
      id: _readString(json, 'question_id'),
      key: _readString(json, 'question_key'),
      text: _readString(json, 'question_text'),
      learningDomain: _readString(json, 'learning_domain'),
      depth: _readString(json, 'question_depth'),
      curriculumPosition: _readInt(json, 'curriculum_position'),
      partnerAnswered: _readBool(json, 'partner_answered'),
    );
  }

  final String id;
  final String key;
  final String text;
  final String learningDomain;
  final String depth;
  final int curriculumPosition;
  final bool partnerAnswered;
}

class AiFocusedQuestionFlow {
  const AiFocusedQuestionFlow({
    required this.status,
    required this.progress,
    this.question,
  });

  factory AiFocusedQuestionFlow.fromJson(Map<String, dynamic> json) {
    final status = AiFocusedQuestionStatus.fromJson(
      _readString(json, 'status'),
    );
    final rawQuestion = json['question'];
    final question = rawQuestion == null
        ? null
        : AiFocusedQuestion.fromJson(_asMap(rawQuestion, 'question'));

    if (status == AiFocusedQuestionStatus.answering && question == null) {
      throw const FormatException(
        'An answering focused flow requires a question',
      );
    }

    if (status != AiFocusedQuestionStatus.answering && question != null) {
      throw const FormatException(
        'A finished focused flow cannot expose a question',
      );
    }

    return AiFocusedQuestionFlow(
      status: status,
      progress: AiFocusedQuestionProgress.fromJson(
        _asMap(json['progress'], 'progress'),
      ),
      question: question,
    );
  }

  final AiFocusedQuestionStatus status;
  final AiFocusedQuestionProgress progress;
  final AiFocusedQuestion? question;
}

Map<String, dynamic> _asMap(Object? value, String key) {
  if (value is Map<String, dynamic>) {
    return value;
  }

  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }

  throw FormatException('Invalid focused question field: $key');
}

String _readString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty) {
    return value;
  }

  throw FormatException('Invalid focused question string: $key');
}

int _readInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is num) {
    return value.toInt();
  }

  throw FormatException('Invalid focused question number: $key');
}

bool _readBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is bool) {
    return value;
  }

  throw FormatException('Invalid focused question boolean: $key');
}
