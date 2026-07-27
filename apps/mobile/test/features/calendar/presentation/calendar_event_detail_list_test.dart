import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinscent/features/calendar/data/couple_calendar_event.dart';
import 'package:vinscent/features/calendar/presentation/widgets/calendar_event_artwork.dart';
import 'package:vinscent/features/calendar/presentation/widgets/calendar_event_detail_list.dart';

void main() {
  testWidgets('opens event details on the root navigator', (tester) async {
    final rootObserver = _RouteObserver();
    final branchObserver = _RouteObserver();
    final event = _event(id: 'root-event', title: '루트 모달 일정', memo: null);

    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [rootObserver],
        home: Navigator(
          observers: [branchObserver],
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (_) => Scaffold(
              body: CalendarEventDetailList(
                events: [event],
                canEdit: true,
                onEdit: (_) {},
                onDelete: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    rootObserver.pushedRoutes.clear();
    branchObserver.pushedRoutes.clear();

    await tester.tap(find.byKey(const Key('calendar-event-open-root-event')));
    await tester.pumpAndSettle();

    expect(
      rootObserver.pushedRoutes.whereType<ModalBottomSheetRoute<void>>(),
      hasLength(1),
    );
    expect(
      branchObserver.pushedRoutes.whereType<ModalBottomSheetRoute<void>>(),
      isEmpty,
    );
  });

  testWidgets('vertically centers a short event title beside the artwork', (
    tester,
  ) async {
    final event = _event(
      id: 'centered-title-event',
      title: 'Short title',
      memo: null,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CalendarEventDetailList(
            events: [event],
            canEdit: true,
            onEdit: (_) {},
            onDelete: (_) {},
          ),
        ),
      ),
    );

    await tester.tap(
      find.byKey(const Key('calendar-event-open-centered-title-event')),
    );
    await tester.pumpAndSettle();

    final sheet = find.byKey(
      const Key('calendar-event-detail-sheet-centered-title-event'),
    );
    final artwork = find.descendant(
      of: sheet,
      matching: find.byType(CalendarEventArtwork),
    );
    final title = find.descendant(
      of: sheet,
      matching: find.text('Short title'),
    );
    final artworkCenter = tester.getRect(artwork).center.dy;
    final titleCenter = tester.getRect(title).center.dy;

    expect(titleCenter, closeTo(artworkCenter, 0.5));
  });

  testWidgets('opens edit and delete actions in a compact root sheet', (
    tester,
  ) async {
    final rootObserver = _RouteObserver();
    final branchObserver = _RouteObserver();
    final event = _event(id: 'action-event', title: '메뉴를 확인할 일정', memo: null);
    CoupleCalendarEvent? editedEvent;
    CoupleCalendarEvent? deletedEvent;

    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [rootObserver],
        home: Navigator(
          observers: [branchObserver],
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (_) => Scaffold(
              body: CalendarEventDetailList(
                events: [event],
                canEdit: true,
                onEdit: (event) => editedEvent = event,
                onDelete: (event) => deletedEvent = event,
              ),
            ),
          ),
        ),
      ),
    );
    rootObserver.pushedRoutes.clear();
    branchObserver.pushedRoutes.clear();

    await tester.tap(find.byKey(const Key('calendar-event-menu-action-event')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('calendar-event-action-sheet-action-event')),
      findsOneWidget,
    );
    expect(
      rootObserver.pushedRoutes.last,
      isA<ModalBottomSheetRoute<dynamic>>(),
    );
    expect(
      branchObserver.pushedRoutes.whereType<ModalBottomSheetRoute<dynamic>>(),
      isEmpty,
    );

    await tester.tap(
      find.byKey(const Key('calendar-event-action-edit-action-event')),
    );
    await tester.pumpAndSettle();

    expect(editedEvent, same(event));
    expect(deletedEvent, isNull);
    expect(find.byType(BottomSheet), findsNothing);

    await tester.tap(find.byKey(const Key('calendar-event-menu-action-event')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('calendar-event-action-delete-action-event')),
    );
    await tester.pumpAndSettle();

    expect(deletedEvent, same(event));
    expect(find.byType(BottomSheet), findsNothing);
  });

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
    final firstSurfaceContext = tester.element(
      find.byKey(const Key('calendar-event-row-surface-event-1')),
    );
    final firstSurfaceShape = firstSurface.shape! as RoundedRectangleBorder;
    expect(firstSurface.color, Colors.transparent);
    expect(firstSurfaceShape.borderRadius, BorderRadius.circular(6));
    expect(
      firstSurfaceShape.side.color,
      Theme.of(firstSurfaceContext).colorScheme.outlineVariant,
    );
    expect(firstSurfaceShape.side.width, 1);
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
    expect(
      find.byKey(const Key('calendar-event-detail-sheet-close-event-1')),
      findsNothing,
    );

    await tester.tapAt(const Offset(8, 8));
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

class _RouteObserver extends NavigatorObserver {
  final List<Route<dynamic>> pushedRoutes = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushedRoutes.add(route);
    super.didPush(route, previousRoute);
  }
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
