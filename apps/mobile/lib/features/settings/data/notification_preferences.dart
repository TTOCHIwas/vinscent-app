class NotificationPreferences {
  const NotificationPreferences({
    required this.userId,
    required this.partnerAnswerEnabled,
    required this.dailyQuestionEnabled,
    required this.reminderEnabled,
    required this.coupleDisconnectEnabled,
    required this.recordingEnabled,
    required this.partnerStoryCardEnabled,
    required this.createdAt,
    required this.updatedAt,
  });

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      userId: json['user_id'] as String,
      partnerAnswerEnabled: json['partner_answer_enabled'] as bool,
      dailyQuestionEnabled: json['daily_question_enabled'] as bool,
      reminderEnabled: json['reminder_enabled'] as bool,
      coupleDisconnectEnabled: json['couple_disconnect_enabled'] as bool,
      recordingEnabled: json['recording_enabled'] as bool,
      partnerStoryCardEnabled: json['partner_story_card_enabled'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  final String userId;
  final bool partnerAnswerEnabled;
  final bool dailyQuestionEnabled;
  final bool reminderEnabled;
  final bool coupleDisconnectEnabled;
  final bool recordingEnabled;
  final bool partnerStoryCardEnabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  NotificationPreferences copyWith({
    bool? partnerAnswerEnabled,
    bool? dailyQuestionEnabled,
    bool? reminderEnabled,
    bool? coupleDisconnectEnabled,
    bool? recordingEnabled,
    bool? partnerStoryCardEnabled,
  }) {
    return NotificationPreferences(
      userId: userId,
      partnerAnswerEnabled: partnerAnswerEnabled ?? this.partnerAnswerEnabled,
      dailyQuestionEnabled: dailyQuestionEnabled ?? this.dailyQuestionEnabled,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      coupleDisconnectEnabled:
          coupleDisconnectEnabled ?? this.coupleDisconnectEnabled,
      recordingEnabled: recordingEnabled ?? this.recordingEnabled,
      partnerStoryCardEnabled:
          partnerStoryCardEnabled ?? this.partnerStoryCardEnabled,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
