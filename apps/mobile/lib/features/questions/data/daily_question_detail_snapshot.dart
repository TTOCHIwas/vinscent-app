import '../../../core/date/app_date_policy.dart';
import '../../../core/questions/daily_question.dart';
import '../../../core/questions/daily_question_answer_state.dart';
import '../../couple/data/couple.dart';

class DailyQuestionDetailSnapshot {
  const DailyQuestionDetailSnapshot({
    required this.coupleId,
    required this.coupleDate,
    required this.accessMode,
    required this.canAnswerQuestion,
    required this.question,
    required this.answerState,
  });

  factory DailyQuestionDetailSnapshot.fromJson(Map<String, dynamic> json) {
    final dailyQuestionId = json['daily_question_id'] as String;
    final questionStatus = json['question_status'] as String;
    final coupleDate = calendarDateOnly(
      DateTime.parse(json['couple_date'] as String),
    );
    return DailyQuestionDetailSnapshot(
      coupleId: json['couple_id'] as String,
      coupleDate: coupleDate,
      accessMode: CoupleAccessMode.fromJson(json['access_mode'] as String),
      canAnswerQuestion: json['can_answer_question'] as bool? ?? false,
      question: DailyQuestion.fromJson({
        'daily_question_id': dailyQuestionId,
        'couple_id': json['couple_id'],
        'question_id': json['question_id'],
        'question_text': json['question_text'],
        'question_source': json['question_source'],
        'question_category': json['question_category'],
        'question_mood': json['question_mood'],
        'assigned_date': json['couple_date'],
        'status': questionStatus,
      }),
      answerState: DailyQuestionAnswerState.fromJson({
        'daily_question_id': dailyQuestionId,
        'status': questionStatus,
        'my_answer_id': json['my_answer_id'],
        'my_answer_text': json['my_answer_text'],
        'my_answer_answered_at': json['my_answer_answered_at'],
        'my_answer_updated_at': json['my_answer_updated_at'],
        'partner_answer_exists':
            json['partner_answer_exists'] as bool? ?? false,
        'partner_answer_id': json['partner_answer_id'],
        'partner_answer_text': json['partner_answer_text'],
        'partner_answer_answered_at': json['partner_answer_answered_at'],
        'partner_answer_updated_at': json['partner_answer_updated_at'],
        'answer_count': (json['answer_count'] as num?)?.toInt() ?? 0,
      }),
    );
  }

  final String coupleId;
  final DateTime coupleDate;
  final CoupleAccessMode accessMode;
  final bool canAnswerQuestion;
  final DailyQuestion question;
  final DailyQuestionAnswerState answerState;
}
