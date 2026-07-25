import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/calendar/data/couple_calendar_event.dart';
import 'package:vinscent/features/calendar/data/couple_calendar_event_mapper.dart';

void main() {
  test('maps a shared calendar occurrence and the current user reminder', () {
    final event = const CoupleCalendarEventMapper().mapOccurrence(
      {
        'event_id': 'event-id',
        'couple_id': 'couple-id',
        'title': '첫 여행',
        'event_date': '2024-02-29',
        'occurrence_date': '2027-02-28',
        'repeat_rule': 'yearly',
        'memo': '준비물 챙기기',
        'artwork_preview_path': 'preview.webp',
        'artwork_data_path': 'drawing.json.gz',
        'revision': 3,
        'created_by_user_id': 'user-a',
        'updated_by_user_id': 'user-b',
        'created_at': '2026-07-26T01:00:00Z',
        'updated_at': '2026-07-26T02:00:00Z',
        'own_reminder_enabled': true,
        'own_reminder_offset_days': 3,
        'own_reminder_time': '18:30:00',
      },
      previewUrlsByPath: const {'preview.webp': 'https://signed.example/art'},
    );

    expect(event.id, 'event-id');
    expect(event.repeatRule, CoupleCalendarEventRepeatRule.yearly);
    expect(event.eventDate, DateTime(2024, 2, 29));
    expect(event.occurrenceDate, DateTime(2027, 2, 28));
    expect(event.artwork?.previewUrl, 'https://signed.example/art');
    expect(event.reminder.isEnabled, isTrue);
    expect(event.reminder.offsetDays, 3);
    expect(event.reminder.hour, 18);
    expect(event.reminder.minute, 30);
  });

  test('rejects an unknown repeat rule', () {
    expect(
      () => const CoupleCalendarEventMapper().mapOccurrence({
        'event_id': 'event-id',
        'couple_id': 'couple-id',
        'title': '일정',
        'event_date': '2026-07-26',
        'occurrence_date': '2026-07-26',
        'repeat_rule': 'monthly',
        'memo': null,
        'artwork_preview_path': null,
        'artwork_data_path': null,
        'revision': 1,
        'created_by_user_id': 'user-a',
        'updated_by_user_id': 'user-a',
        'created_at': '2026-07-26T01:00:00Z',
        'updated_at': '2026-07-26T01:00:00Z',
        'own_reminder_enabled': false,
        'own_reminder_offset_days': 0,
        'own_reminder_time': '09:00:00',
      }),
      throwsFormatException,
    );
  });
}
