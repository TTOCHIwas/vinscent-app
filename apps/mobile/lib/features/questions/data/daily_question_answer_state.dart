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
    this.partnerAnswerId,
    this.partnerAnswerText,
    this.partnerAnswerAnsweredAt,
    this.partnerAnswerUpdatedAt,
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
      partnerAnswerId: json['partner_answer_id'] as String?,
      partnerAnswerText: json['partner_answer_text'] as String?,
      partnerAnswerAnsweredAt: _parseOptionalDateTime(
        json['partner_answer_answered_at'],
      ),
      partnerAnswerUpdatedAt: _parseOptionalDateTime(
        json['partner_answer_updated_at'],
      ),
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
  final String? partnerAnswerId;
  final String? partnerAnswerText;
  final DateTime? partnerAnswerAnsweredAt;
  final DateTime? partnerAnswerUpdatedAt;
  final int answerCount;

  bool get hasMyAnswer => myAnswerId != null;

  bool get hasPartnerAnswer => partnerAnswerId != null;

  bool get canRevealPartnerAnswer => hasMyAnswer && hasPartnerAnswer;
}

DateTime? _parseOptionalDateTime(Object? value) {
  if (value == null) {
    return null;
  }

  return DateTime.parse(value as String);
}
