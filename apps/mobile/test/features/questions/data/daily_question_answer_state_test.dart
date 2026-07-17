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
    expect(state.partnerAnswerId, isNull);
    expect(state.partnerAnswerText, isNull);
    expect(state.partnerAnswerAnsweredAt, isNull);
    expect(state.partnerAnswerUpdatedAt, isNull);
    expect(state.answerCount, 0);
    expect(state.hasMyAnswer, isFalse);
    expect(state.hasPartnerAnswer, isFalse);
    expect(state.hasBothAnswers, isFalse);
    expect(state.canRevealPartnerAnswer, isFalse);
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
      'partner_answer_id': 'partner-answer-id',
      'partner_answer_text': 'partner answer',
      'partner_answer_answered_at': '2026-05-31T13:00:00Z',
      'partner_answer_updated_at': '2026-05-31T13:30:00Z',
      'answer_count': 2,
    });

    expect(state.status, DailyQuestionStatus.completed);
    expect(state.myAnswerId, 'answer-id');
    expect(state.myAnswerText, 'my answer');
    expect(state.myAnswerAnsweredAt, DateTime.parse('2026-05-31T12:00:00Z'));
    expect(state.myAnswerUpdatedAt, DateTime.parse('2026-05-31T12:30:00Z'));
    expect(state.partnerAnswerExists, isTrue);
    expect(state.partnerAnswerId, 'partner-answer-id');
    expect(state.partnerAnswerText, 'partner answer');
    expect(
      state.partnerAnswerAnsweredAt,
      DateTime.parse('2026-05-31T13:00:00Z'),
    );
    expect(
      state.partnerAnswerUpdatedAt,
      DateTime.parse('2026-05-31T13:30:00Z'),
    );
    expect(state.answerCount, 2);
    expect(state.hasMyAnswer, isTrue);
    expect(state.hasPartnerAnswer, isTrue);
    expect(state.hasBothAnswers, isTrue);
    expect(state.canRevealPartnerAnswer, isTrue);
  });

  test('does not reveal partner answer without my answer', () {
    const state = DailyQuestionAnswerState(
      dailyQuestionId: 'daily-question-id',
      status: DailyQuestionStatus.answeredByOne,
      partnerAnswerExists: true,
      partnerAnswerId: 'partner-answer-id',
      partnerAnswerText: 'partner answer',
      answerCount: 1,
    );

    expect(state.hasMyAnswer, isFalse);
    expect(state.hasPartnerAnswer, isTrue);
    expect(state.hasBothAnswers, isFalse);
    expect(state.canRevealPartnerAnswer, isFalse);
  });
}
