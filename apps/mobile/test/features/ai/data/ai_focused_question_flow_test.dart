import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/ai/data/ai_focused_question_flow.dart';

void main() {
  test('parses an answering flow with separate member progress', () {
    final flow = AiFocusedQuestionFlow.fromJson({
      'status': 'answering',
      'progress': {
        'curriculum_version': 1,
        'my_answered_count': 5,
        'partner_answered_count': 3,
        'couple_completed_count': 2,
        'total_count': 24,
      },
      'question': {
        'question_id': 'question-id',
        'question_key': 'foundation_question',
        'question_text': '요즘 가장 소중하게 지키고 싶은 건 뭐야?',
        'learning_domain': 'personal_values',
        'question_depth': 'light',
        'curriculum_position': 6,
        'partner_answered': true,
      },
    });

    expect(flow.status, AiFocusedQuestionStatus.answering);
    expect(flow.progress.myAnsweredCount, 5);
    expect(flow.progress.partnerAnsweredCount, 3);
    expect(flow.progress.coupleCompletedCount, 2);
    expect(flow.question?.id, 'question-id');
    expect(flow.question?.partnerAnswered, true);
  });

  test('allows a waiting flow without a question', () {
    final flow = AiFocusedQuestionFlow.fromJson({
      'status': 'waiting_partner',
      'progress': {
        'curriculum_version': 1,
        'my_answered_count': 24,
        'partner_answered_count': 20,
        'couple_completed_count': 20,
        'total_count': 24,
      },
      'question': null,
    });

    expect(flow.status, AiFocusedQuestionStatus.waitingPartner);
    expect(flow.question, isNull);
  });
}
