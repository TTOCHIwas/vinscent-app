import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/ai/data/ai_focused_question_history_entry.dart';

void main() {
  test('parses a completed focused question history entry', () {
    final entry = AiFocusedQuestionHistoryEntry.fromJson({
      'question_id': 'question-id',
      'question_key': 'foundation_question',
      'question_text': '요즘 가장 소중하게 지키고 싶은 건 뭐야?',
      'learning_domain': 'personal_values',
      'question_depth': 'light',
      'curriculum_position': 1,
      'my_answer_text': '함께 보내는 시간이야',
      'partner_answer_text': '평온한 일상이야',
    });

    expect(entry.curriculumPosition, 1);
    expect(entry.myAnswerText, '함께 보내는 시간이야');
    expect(entry.partnerAnswerText, '평온한 일상이야');
  });

  test('rejects an incomplete focused question history entry', () {
    expect(
      () => AiFocusedQuestionHistoryEntry.fromJson({
        'question_id': 'question-id',
        'question_key': 'foundation_question',
        'question_text': '질문',
        'learning_domain': 'personal_values',
        'question_depth': 'light',
        'curriculum_position': 1,
        'my_answer_text': '내 답변',
        'partner_answer_text': '',
      }),
      throwsFormatException,
    );
  });
}
