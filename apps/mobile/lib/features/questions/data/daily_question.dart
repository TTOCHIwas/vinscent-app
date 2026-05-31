import '../../../core/date/app_date_policy.dart';

enum QuestionSource {
  curated,
  ai;

  factory QuestionSource.fromJson(String value) {
    return switch (value) {
      'curated' => QuestionSource.curated,
      'ai' => QuestionSource.ai,
      _ => throw FormatException('Unknown question source: $value'),
    };
  }
}

enum DailyQuestionStatus {
  pending,
  answeredByOne,
  completed;

  factory DailyQuestionStatus.fromJson(String value) {
    return switch (value) {
      'pending' => DailyQuestionStatus.pending,
      'answered_by_one' => DailyQuestionStatus.answeredByOne,
      'completed' => DailyQuestionStatus.completed,
      _ => throw FormatException('Unknown daily question status: $value'),
    };
  }
}

class DailyQuestion {
  const DailyQuestion({
    required this.dailyQuestionId,
    required this.coupleId,
    required this.questionId,
    required this.questionText,
    required this.questionSource,
    required this.questionCategory,
    required this.assignedDate,
    required this.status,
    this.questionMood,
  });

  factory DailyQuestion.fromJson(Map<String, dynamic> json) {
    return DailyQuestion(
      dailyQuestionId: json['daily_question_id'] as String,
      coupleId: json['couple_id'] as String,
      questionId: json['question_id'] as String,
      questionText: json['question_text'] as String,
      questionSource: QuestionSource.fromJson(
        json['question_source'] as String,
      ),
      questionCategory: json['question_category'] as String,
      questionMood: json['question_mood'] as String?,
      assignedDate: calendarDateOnly(
        DateTime.parse(json['assigned_date'] as String),
      ),
      status: DailyQuestionStatus.fromJson(json['status'] as String),
    );
  }

  final String dailyQuestionId;
  final String coupleId;
  final String questionId;
  final String questionText;
  final QuestionSource questionSource;
  final String questionCategory;
  final String? questionMood;
  final DateTime assignedDate;
  final DailyQuestionStatus status;
}
