import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/calendar/data/couple_calendar_event.dart';
import 'package:vinscent/features/home_widgets/data/home_widget_calendar_summary_resolver.dart';

void main() {
  const resolver = HomeWidgetCalendarSummaryResolver();
  final date = DateTime(2026, 7, 26);

  test('prioritizes a custom event with artwork and counts the remainder', () {
    final summary = resolver.resolve(
      events: [
        _event(id: 'plain', title: '장보기', date: date),
        _event(
          id: 'art',
          title: '한강 산책',
          date: date,
          artworkUrl: 'https://example.com/event.png',
        ),
      ],
      anniversaryLabels: const ['100일'],
    );

    expect(summary, isNotNull);
    expect(summary!.title, '한강 산책');
    expect(summary.additionalCount, 2);
    expect(summary.artwork?.url, 'https://example.com/event.png');
    expect(summary.artwork?.version, contains('art:3:'));
  });

  test('prioritizes a custom event without artwork over an anniversary', () {
    final summary = resolver.resolve(
      events: [_event(id: 'plain', title: '영화 보기', date: date)],
      anniversaryLabels: const ['2주년'],
    );

    expect(summary?.title, '영화 보기');
    expect(summary?.artwork, isNull);
    expect(summary?.additionalCount, 1);
  });

  test('uses the default anniversary when there is no custom event', () {
    final summary = resolver.resolve(
      events: const [],
      anniversaryLabels: const ['22일'],
    );

    expect(summary?.title, '22일');
    expect(summary?.artwork, isNull);
    expect(summary?.additionalCount, 0);
  });

  test('returns null when today has no schedule', () {
    final summary = resolver.resolve(
      events: const [],
      anniversaryLabels: const [],
    );

    expect(summary, isNull);
  });
}

CoupleCalendarEvent _event({
  required String id,
  required String title,
  required DateTime date,
  String? artworkUrl,
}) {
  final timestamp = DateTime.utc(2026, 7, 26, 1);
  return CoupleCalendarEvent(
    id: id,
    coupleId: 'couple-id',
    title: title,
    eventDate: date,
    occurrenceDate: date,
    repeatRule: CoupleCalendarEventRepeatRule.none,
    memo: null,
    artwork: artworkUrl == null
        ? null
        : CoupleCalendarEventArtwork(
            previewPath: '$id/preview.png',
            drawingDataPath: '$id/drawing.json',
            previewUrl: artworkUrl,
          ),
    revision: 3,
    createdByUserId: 'user-a',
    updatedByUserId: 'user-a',
    createdAt: timestamp,
    updatedAt: timestamp,
    reminder: const CoupleCalendarEventReminder.disabled(),
  );
}
