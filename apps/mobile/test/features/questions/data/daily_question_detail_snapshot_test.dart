import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/questions/data/daily_question_detail_snapshot.dart';

void main() {
  test('maps a direct daily-question detail response', () {
    final snapshot = DailyQuestionDetailSnapshot.fromJson({
      'couple_id': 'couple-id',
      'couple_date': '2026-09-09',
      'access_mode': 'active',
      'can_answer_question': true,
      'daily_question_id': 'daily-question-id',
      'question_id': 'question-id',
      'question_text': '오늘 가장 먼저 떠오른 건 뭐야?',
      'question_source': 'curated',
      'question_category': 'daily_life',
      'question_mood': null,
      'question_status': 'pending',
      'my_answer_id': null,
      'my_answer_text': null,
      'my_answer_answered_at': null,
      'my_answer_updated_at': null,
      'partner_answer_exists': false,
      'partner_answer_id': null,
      'partner_answer_text': null,
      'partner_answer_answered_at': null,
      'partner_answer_updated_at': null,
      'answer_count': 0,
    });

    expect(snapshot.question.dailyQuestionId, 'daily-question-id');
    expect(snapshot.question.assignedDate, DateTime(2026, 9, 9));
    expect(snapshot.answerState.answerCount, 0);
    expect(snapshot.canAnswerQuestion, isTrue);
  });
}
