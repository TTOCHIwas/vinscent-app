import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/ai/data/ai_direct_question_history.dart';

void main() {
  test('parses private direct question history', () {
    final history = AiDirectQuestionHistory.fromJson({
      'daily_limit': 3,
      'remaining_count': 2,
      'questions': [
        {
          'id': 'question-1',
          'question_text': '우리 둘은 쉬는 날에 뭘 하면 잘 맞을까?',
          'status': 'completed',
          'answer_text': '둘 다 조용히 걷는 시간을 좋아한다고 했어',
          'failure_code': null,
          'created_at': '2026-07-24T01:00:00Z',
          'answered_at': '2026-07-24T01:00:10Z',
        },
      ],
    });

    expect(history.dailyLimit, 3);
    expect(history.remainingCount, 2);
    expect(history.questions.single.status, AiDirectQuestionStatus.completed);
    expect(
      history.questions.single.resultKind,
      AiDirectQuestionResultKind.answered,
    );
    expect(history.questions.single.answerText, isNotNull);
    expect(history.questions.single.followUp, isNull);
    expect(history.hasPendingQuestion, isFalse);
  });

  test('parses an insufficient answer with a pending shared question', () {
    final history = AiDirectQuestionHistory.fromJson({
      'daily_limit': 3,
      'remaining_count': 2,
      'questions': [
        {
          'id': 'question-1',
          'question_text': '상대는 쉬는 날에 뭘 하고 싶어 할까?',
          'status': 'completed',
          'result_kind': 'insufficient',
          'answer_text': '아직은 잘 모르겠어',
          'failure_code': null,
          'created_at': '2026-07-24T01:00:00Z',
          'answered_at': '2026-07-24T01:00:10Z',
          'follow_up': {
            'id': 'follow-up-1',
            'question_text': '쉬는 날 함께 해보고 싶은 건 뭐야?',
            'status': 'pending',
            'shared_question_id': null,
          },
        },
      ],
    });

    final question = history.questions.single;
    expect(question.resultKind, AiDirectQuestionResultKind.insufficient);
    expect(question.followUp?.id, 'follow-up-1');
    expect(question.followUp?.status, AiDirectQuestionFollowUpStatus.pending);
    expect(question.followUp?.sharedQuestionId, isNull);
  });

  test('rejects an approved follow-up without a shared question id', () {
    expect(
      () => AiDirectQuestionHistory.fromJson({
        'daily_limit': 3,
        'remaining_count': 2,
        'questions': [
          {
            'id': 'question-1',
            'question_text': '질문',
            'status': 'completed',
            'result_kind': 'insufficient',
            'answer_text': '아직은 잘 모르겠어',
            'failure_code': null,
            'created_at': '2026-07-24T01:00:00Z',
            'answered_at': '2026-07-24T01:00:10Z',
            'follow_up': {
              'id': 'follow-up-1',
              'question_text': '함께 해보고 싶은 건 뭐야?',
              'status': 'approved',
              'shared_question_id': null,
            },
          },
        ],
      }),
      throwsFormatException,
    );
  });

  test('rejects a completed question without an answer', () {
    expect(
      () => AiDirectQuestionHistory.fromJson({
        'daily_limit': 3,
        'remaining_count': 2,
        'questions': [
          {
            'id': 'question-1',
            'question_text': '질문',
            'status': 'completed',
            'answer_text': null,
            'failure_code': null,
            'created_at': '2026-07-24T01:00:00Z',
            'answered_at': null,
          },
        ],
      }),
      throwsFormatException,
    );
  });

  test('rejects a non-object history entry', () {
    expect(
      () => AiDirectQuestionHistory.fromJson({
        'daily_limit': 3,
        'remaining_count': 3,
        'questions': ['invalid'],
      }),
      throwsFormatException,
    );
  });
}
