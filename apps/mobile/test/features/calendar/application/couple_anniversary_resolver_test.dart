import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/calendar/application/couple_anniversary_resolver.dart';

void main() {
  const resolver = CoupleAnniversaryResolver();

  test('counts the relationship start date as day one', () {
    final startDate = DateTime(2026, 1, 1);

    expect(
      resolver.resolve(startDate: startDate, date: startDate).single.label,
      '첫날',
    );
    expect(
      resolver
          .resolve(startDate: startDate, date: DateTime(2026, 1, 10))
          .single
          .label,
      '10일',
    );
    expect(
      resolver
          .resolve(startDate: startDate, date: DateTime(2026, 1, 22))
          .single
          .label,
      '22일',
    );
    expect(
      resolver
          .resolve(startDate: startDate, date: DateTime(2026, 2, 19))
          .single
          .label,
      '50일',
    );
    expect(
      resolver
          .resolve(startDate: startDate, date: DateTime(2026, 4, 10))
          .single
          .label,
      '100일',
    );
  });

  test('returns every hundred-day milestone', () {
    final occurrences = resolver.resolve(
      startDate: DateTime(2026, 1, 1),
      date: DateTime(2026, 7, 19),
    );

    expect(occurrences.map((value) => value.label), contains('200일'));
  });

  test('maps a February 29 anniversary to February 28 in non-leap years', () {
    final occurrences = resolver.resolve(
      startDate: DateTime(2024, 2, 29),
      date: DateTime(2025, 2, 28),
    );

    expect(occurrences.map((value) => value.label), contains('1주년'));
  });

  test('does not return an anniversary before the relationship starts', () {
    expect(
      resolver.resolve(
        startDate: DateTime(2026, 1, 1),
        date: DateTime(2025, 12, 31),
      ),
      isEmpty,
    );
  });
}
