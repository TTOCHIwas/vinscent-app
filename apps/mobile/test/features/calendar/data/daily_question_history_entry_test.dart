import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/calendar/data/daily_question_history_entry.dart';
import 'package:vinscent/features/questions/data/daily_question.dart';

void main() {
  test('parses question and answer state from one RPC row', () {
    final entry = DailyQuestionHistoryEntry.fromJson({
      'daily_question_id': 'daily-question-id',
      'couple_id': 'couple-id',
      'question_id': 'question-id',
      'question_text': 'history question',
      'question_source': 'curated',
      'question_category': 'daily',
      'question_mood': 'warm',
      'assigned_date': '2026-05-05',
      'status': 'completed',
      'my_answer_id': 'my-answer-id',
      'my_answer_text': 'my answer',
      'my_answer_answered_at': '2026-05-05T00:01:00Z',
      'my_answer_updated_at': '2026-05-05T00:02:00Z',
      'partner_answer_exists': true,
      'partner_answer_id': 'partner-answer-id',
      'partner_answer_text': 'partner answer',
      'partner_answer_answered_at': '2026-05-05T00:03:00Z',
      'partner_answer_updated_at': '2026-05-05T00:04:00Z',
      'answer_count': 2,
    });

    expect(entry.question.questionText, 'history question');
    expect(entry.question.assignedDate, DateTime(2026, 5, 5));
    expect(entry.question.status, DailyQuestionStatus.completed);
    expect(entry.answerState.myAnswerText, 'my answer');
    expect(entry.answerState.partnerAnswerText, 'partner answer');
    expect(entry.answerState.answerCount, 2);
  });
}
