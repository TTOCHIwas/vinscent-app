import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/expressions/data/couple_expression.dart';
import 'package:vinscent/features/expressions/data/couple_expression_summary.dart';

void main() {
  test('parses couple expression response', () {
    final expression = CoupleExpression.fromJson({
      'id': 'expression-id',
      'couple_id': 'couple-id',
      'sender_user_id': 'user-id',
      'receiver_user_id': 'partner-id',
      'expression_type': 'feeling_down',
      'sent_at': '2026-06-05T12:00:00.000Z',
    });

    expect(expression.type, CoupleExpressionType.feelingDown);
    expect(expression.type.label, '우울해');
    expect(expression.sentAt, DateTime.parse('2026-06-05T12:00:00.000Z'));
  });

  test('parses couple expression summary response', () {
    final summary = CoupleExpressionSummary.fromJson({
      'expression_type': 'cheer_up',
      'sent_count': 42,
    });

    expect(summary.type, CoupleExpressionType.cheerUp);
    expect(summary.sentCount, 42);
  });

  test('throws when expression type is unknown', () {
    expect(
      () => CoupleExpressionType.fromJson('unknown'),
      throwsA(isA<FormatException>()),
    );
  });
}
