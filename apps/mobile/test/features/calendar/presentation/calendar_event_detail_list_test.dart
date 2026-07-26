import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/calendar/data/couple_calendar_event.dart';
import 'package:vinscent/features/calendar/presentation/widgets/calendar_event_detail_list.dart';

void main() {
  testWidgets('uses event surfaces and opens details in a modal sheet', (
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

    expect(find.byType(Divider), findsNothing);
    final firstSurface = tester.widget<Material>(
      find.byKey(const Key('calendar-event-row-surface-event-1')),
    );
    expect(firstSurface.color, const Color(0xFFF4F4F4));
    expect(firstSurface.borderRadius, BorderRadius.circular(6));
    final firstPadding = tester.widget<Padding>(
      find.byKey(const Key('calendar-event-row-padding-event-1')),
    );
    expect(firstPadding.padding, const EdgeInsets.all(12));
    expect(find.text('숙소 예약 번호를 다시 확인하기'), findsNothing);
    expect(find.text('우유와 과일 사기'), findsNothing);

    await tester.tap(find.byKey(const Key('calendar-event-open-event-1')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('calendar-event-detail-sheet-event-1')),
      findsOneWidget,
    );
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('숙소 예약 번호를 다시 확인하기'), findsOneWidget);
    expect(find.text('매년 반복'), findsOneWidget);
    expect(find.textContaining('1일 전'), findsOneWidget);
    expect(find.textContaining('알림'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('calendar-event-detail-sheet-close-event-1')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('숙소 예약 번호를 다시 확인하기'), findsNothing);

    await tester.tap(find.byKey(const Key('calendar-event-open-event-2')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('calendar-event-detail-sheet-event-2')),
      findsOneWidget,
    );
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
