import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/couple/data/question_delivery_time.dart';

void main() {
  test('parses the database time format and preserves hour and minute', () {
    final time = QuestionDeliveryTime.fromDatabase('21:35:00');

    expect(time.hour, 21);
    expect(time.minute, 35);
    expect(time.toDatabase(), '21:35:00');
    expect(time.label, '오후 9:35');
  });

  test('rejects an invalid delivery time', () {
    expect(
      () => QuestionDeliveryTime.fromDatabase('24:00:00'),
      throwsFormatException,
    );
    expect(
      () => QuestionDeliveryTime.checked(hour: 9, minute: 60),
      throwsRangeError,
    );
  });
}
