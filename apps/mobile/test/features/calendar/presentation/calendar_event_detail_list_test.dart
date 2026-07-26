import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/calendar/data/couple_calendar_event.dart';
import 'package:vinscent/features/calendar/presentation/widgets/calendar_event_detail_list.dart';

void main() {
  testWidgets('separates events and expands one event detail at a time', (
    tester,
  ) async {
    final events = [
      _event(
        id: 'event-1',
        title: '기념 여행',
        memo: '숙소 예약 번호를 다시 확인하기',
        repeatRule: CoupleCalendarEventRepeatRule.yearly,
        reminder: const CoupleCalendarEventReminder(
          isEnabled: true,
          offsetDays: 1,
          hour: 18,
          minute: 30,
        ),
      ),
      _event(id: 'event-2', title: '함께 장보기', memo: '우유와 과일 사기'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CalendarEventDetailList(
            events: events,
            anniversaries: const [],
            canEdit: true,
            onEdit: (_) {},
            onDelete: (_) {},
          ),
        ),
      ),
    );

    expect(
      find.byKey(const Key('calendar-event-detail-surface')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('calendar-event-divider-event-1')),
      findsOneWidget,
    );
    expect(find.text('숙소 예약 번호를 다시 확인하기'), findsNothing);
    expect(find.text('우유와 과일 사기'), findsNothing);

    await tester.tap(find.byKey(const Key('calendar-event-toggle-event-1')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('calendar-event-expanded-event-1')),
      findsOneWidget,
    );
    expect(find.text('숙소 예약 번호를 다시 확인하기'), findsOneWidget);
    expect(find.text('매년 반복'), findsOneWidget);
    expect(find.textContaining('1일 전'), findsOneWidget);
    expect(find.textContaining('알림'), findsOneWidget);

    await tester.tap(find.byKey(const Key('calendar-event-toggle-event-2')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('calendar-event-expanded-event-1')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('calendar-event-expanded-event-2')),
      findsOneWidget,
    );
    expect(find.text('숙소 예약 번호를 다시 확인하기'), findsNothing);
    expect(find.text('우유와 과일 사기'), findsOneWidget);
    expect(find.text('반복 안 함'), findsOneWidget);
    expect(find.text('알림 없음'), findsOneWidget);
  });
}

CoupleCalendarEvent _event({
  required String id,
  required String title,
  required String? memo,
  CoupleCalendarEventRepeatRule repeatRule = CoupleCalendarEventRepeatRule.none,
  CoupleCalendarEventReminder reminder =
      const CoupleCalendarEventReminder.disabled(),
}) {
  final date = DateTime(2026, 7, 26);
  return CoupleCalendarEvent(
    id: id,
    coupleId: 'couple-id',
    title: title,
    eventDate: date,
    occurrenceDate: date,
    repeatRule: repeatRule,
    memo: memo,
    revision: 1,
    createdByUserId: 'user-a',
    updatedByUserId: 'user-a',
    createdAt: date,
    updatedAt: date,
    reminder: reminder,
  );
}
