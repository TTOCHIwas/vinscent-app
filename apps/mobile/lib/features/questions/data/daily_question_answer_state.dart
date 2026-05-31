import 'daily_question.dart';

class DailyQuestionAnswerState {
  const DailyQuestionAnswerState({
    required this.dailyQuestionId,
    required this.status,
    required this.partnerAnswerExists,
    required this.answerCount,
    this.myAnswerId,
    this.myAnswerText,
    this.myAnswerAnsweredAt,
    this.myAnswerUpdatedAt,
  });

  factory DailyQuestionAnswerState.fromJson(Map<String, dynamic> json) {
    return DailyQuestionAnswerState(
      dailyQuestionId: json['daily_question_id'] as String,
      status: DailyQuestionStatus.fromJson(json['status'] as String),
      myAnswerId: json['my_answer_id'] as String?,
      myAnswerText: json['my_answer_text'] as String?,
      myAnswerAnsweredAt: _parseOptionalDateTime(json['my_answer_answered_at']),
      myAnswerUpdatedAt: _parseOptionalDateTime(json['my_answer_updated_at']),
      partnerAnswerExists: json['partner_answer_exists'] as bool,
      answerCount: (json['answer_count'] as num).toInt(),
    );
  }

  final String dailyQuestionId;
  final DailyQuestionStatus status;
  final String? myAnswerId;
  final String? myAnswerText;
  final DateTime? myAnswerAnsweredAt;
  final DateTime? myAnswerUpdatedAt;
  final bool partnerAnswerExists;
  final int answerCount;

  bool get hasMyAnswer => myAnswerId != null;
}

DateTime? _parseOptionalDateTime(Object? value) {
  if (value == null) {
    return null;
  }

  return DateTime.parse(value as String);
}
