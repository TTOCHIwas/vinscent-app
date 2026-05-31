import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/questions/data/daily_question.dart';
import 'package:vinscent/features/questions/data/daily_question_answer_state.dart';

void main() {
  test('parses answer state without my answer', () {
    final state = DailyQuestionAnswerState.fromJson({
      'daily_question_id': 'daily-question-id',
      'status': 'pending',
      'my_answer_id': null,
      'my_answer_text': null,
      'my_answer_answered_at': null,
      'my_answer_updated_at': null,
      'partner_answer_exists': false,
      'answer_count': 0,
    });

    expect(state.dailyQuestionId, 'daily-question-id');
    expect(state.status, DailyQuestionStatus.pending);
    expect(state.myAnswerId, isNull);
    expect(state.myAnswerText, isNull);
    expect(state.myAnswerAnsweredAt, isNull);
    expect(state.myAnswerUpdatedAt, isNull);
    expect(state.partnerAnswerExists, isFalse);
    expect(state.answerCount, 0);
    expect(state.hasMyAnswer, isFalse);
  });

  test('parses answer state with my answer', () {
    final state = DailyQuestionAnswerState.fromJson({
      'daily_question_id': 'daily-question-id',
      'status': 'completed',
      'my_answer_id': 'answer-id',
      'my_answer_text': 'my answer',
      'my_answer_answered_at': '2026-05-31T12:00:00Z',
      'my_answer_updated_at': '2026-05-31T12:30:00Z',
      'partner_answer_exists': true,
      'answer_count': 2,
    });

    expect(state.status, DailyQuestionStatus.completed);
    expect(state.myAnswerId, 'answer-id');
    expect(state.myAnswerText, 'my answer');
    expect(state.myAnswerAnsweredAt, DateTime.parse('2026-05-31T12:00:00Z'));
    expect(state.myAnswerUpdatedAt, DateTime.parse('2026-05-31T12:30:00Z'));
    expect(state.partnerAnswerExists, isTrue);
    expect(state.answerCount, 2);
    expect(state.hasMyAnswer, isTrue);
  });
}
