class MonthlyRetrospective {
  MonthlyRetrospective.fromJson(Map<String, dynamic> row)
    : coupleId = row['couple_id'] as String,
      month = DateTime.parse(row['month'] as String),
      availableUntil = DateTime.parse(row['available_until'] as String),
      recordedDays = (row['recorded_days'] as num).toInt(),
      cardCount = (row['card_count'] as num?)?.toInt(),
      cardCountComplete = row['card_count_complete'] as bool,
      completedQuestions = (row['completed_questions'] as num).toInt(),
      hasRecords = row['has_records'] as bool,
      aiEnabled = row['ai_enabled'] as bool,
      title = row['title'] as String,
      summary = row['summary'] as String?,
      contentStatus = row['content_status'] as String,
      moments = (row['moments'] as List)
          .map((v) => RetrospectiveMoment.fromJson(Map<String, dynamic>.from(v as Map)))
          .toList(growable: false),
      conversation = row['conversation'] == null
          ? null : RetrospectiveConversation.fromJson(Map<String, dynamic>.from(row['conversation'] as Map)),
      reflection = row['reflection'] == null
          ? null : RetrospectiveReflection.fromJson(Map<String, dynamic>.from(row['reflection'] as Map));

  final String coupleId;
  final DateTime month;
  final DateTime availableUntil;
  final int recordedDays;
  final int? cardCount;
  final bool cardCountComplete;
  final int completedQuestions;
  final bool hasRecords;
  final bool aiEnabled;
  final String title;
  final String? summary;
  final String contentStatus;
  final List<RetrospectiveMoment> moments;
  final RetrospectiveConversation? conversation;
  final RetrospectiveReflection? reflection;

  bool get needsGeneration => hasRecords && aiEnabled && completedQuestions > 0 && contentStatus != 'ready';
}

class RetrospectiveMoment {
  RetrospectiveMoment.fromJson(Map<String, dynamic> row)
    : date = DateTime.parse(row['date'] as String), question = row['question'] as String?,
      cards = (row['cards'] as List).map((v) => RetrospectiveCard.fromJson(Map<String, dynamic>.from(v as Map))).toList(growable: false);
  final DateTime date;
  final String? question;
  final List<RetrospectiveCard> cards;
}

class RetrospectiveCard {
  RetrospectiveCard.fromJson(Map<String, dynamic> row)
    : id = row['id'] as String, previewPath = row['preview_path'] as String,
      authorUserId = row['author_user_id'] as String,
      aspectRatio = (row['aspect_ratio'] as num).toDouble();
  final String id;
  final String previewPath;
  final String authorUserId;
  final double aspectRatio;
}

class RetrospectiveConversation {
  RetrospectiveConversation.fromJson(Map<String, dynamic> row)
    : date = DateTime.parse(row['date'] as String), question = row['question'] as String,
      myAnswer = row['my_answer'] as String, partnerAnswer = row['partner_answer'] as String,
      partnerAnswerId = row['partner_answer_id'] as String;
  final DateTime date;
  final String question;
  final String myAnswer;
  final String partnerAnswer;
  final String partnerAnswerId;
}

class RetrospectiveReflection {
  RetrospectiveReflection.fromJson(Map<String, dynamic> row)
    : id = row['id'] as String, question = row['question'] as String?,
      source = row['source'] as String?, myAnswer = row['my_answer'] as String?,
      partnerAnswer = row['partner_answer'] as String?, partnerAnswerId = row['partner_answer_id'] as String?,
      partnerAnswerExists = row['partner_answer_exists'] as bool, version = (row['version'] as num).toInt();
  final String id;
  final String? question;
  final String? source;
  final String? myAnswer;
  final String? partnerAnswer;
  final String? partnerAnswerId;
  final bool partnerAnswerExists;
  final int version;
}
