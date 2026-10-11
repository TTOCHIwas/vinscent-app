import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/monthly_retrospective/data/monthly_retrospective.dart';

void main() {
  test('distinguishes incomplete card counts from a complete zero', () {
    final incomplete = MonthlyRetrospective.fromJson(_row(null, false));
    final complete = MonthlyRetrospective.fromJson(_row(0, true));
    expect(incomplete.cardCount, isNull);
    expect(incomplete.cardCountComplete, isFalse);
    expect(complete.cardCount, 0);
    expect(complete.cardCountComplete, isTrue);
  });

  test('preserves the original shared answers and fixed reflection question', () {
    final data = MonthlyRetrospective.fromJson({
      ..._row(3, true),
      'conversation': {'date': '2026-09-14', 'question': '뭐가 좋았어?', 'my_answer': '  커피\n산책  ', 'partner_answer': '같이 쉬기', 'partner_answer_id': 'a2'},
      'reflection': {'id': 'r1', 'question': '다시 하고 싶은 일은?', 'source': 'basic', 'my_answer': '산책', 'partner_answer': null, 'partner_answer_exists': true, 'version': 1},
    });
    expect(data.conversation!.myAnswer, '  커피\n산책  ');
    expect(data.reflection!.question, '다시 하고 싶은 일은?');
    expect(data.reflection!.partnerAnswer, isNull);
  });
}

Map<String, Object?> _row(int? count, bool complete) => {
  'couple_id': 'c1', 'month': '2026-09-01', 'available_until': '2026-11-01T00:00:00Z',
  'recorded_days': 2, 'card_count': count, 'card_count_complete': complete,
  'completed_questions': 0, 'has_records': true, 'ai_enabled': false,
  'title': '우리의 9월', 'summary': null, 'content_status': 'basic', 'moments': [],
  'conversation': null, 'reflection': null,
};
