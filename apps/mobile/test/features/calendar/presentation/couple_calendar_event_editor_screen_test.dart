import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vinscent/core/presentation/widgets/app_back_button.dart';
import 'package:vinscent/features/calendar/data/couple_calendar_event.dart';
import 'package:vinscent/features/calendar/data/couple_calendar_event_repository.dart';
import 'package:vinscent/features/calendar/presentation/couple_calendar_event_editor_screen.dart';
import 'package:vinscent/features/couple/application/couple_controller.dart';

import '../../../support/couple_fixtures.dart';

void main() {
  testWidgets('creates a shared event without requiring a drawing', (
    tester,
  ) async {
    final repository = _FakeCalendarEventRepository();
    final router = GoRouter(
      initialLocation: '/calendar/event/new',
      routes: [
        GoRoute(
          path: '/calendar',
          builder: (context, state) => const Text('calendar'),
        ),
        GoRoute(
          path: '/calendar/event/new',
          builder: (context, state) => Scaffold(
            body: CoupleCalendarEventEditorScreen.create(
              initialDate: DateTime(2026, 8, 2),
            ),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          coupleControllerProvider.overrideWithBuild(
            (ref, notifier) async => activeCouple(
              relationshipStartDate: DateTime(2026, 5, 1),
              currentDate: DateTime(2026, 7, 26),
            ),
          ),
          coupleCalendarEventRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('calendar-event-basic-step')), findsOneWidget);
    expect(find.byKey(const Key('calendar-event-extras-step')), findsNothing);
    expect(
      find.byKey(const Key('calendar-event-drawing-canvas')),
      findsNothing,
    );

    await tester.enterText(
      find.byKey(const Key('calendar-event-title-field')),
      '첫 여행',
    );
    await tester.pump();
    final nextButton = find.byKey(const Key('calendar-event-next'));
    expect(tester.widget<TextButton>(nextButton).onPressed, isNotNull);
    await tester.tap(nextButton);
    await tester.pumpAndSettle();

    expect(repository.lastRequest, isNull);
    expect(find.byKey(const Key('calendar-event-basic-step')), findsNothing);
    expect(find.byKey(const Key('calendar-event-extras-step')), findsOneWidget);
    expect(
      find.byKey(const Key('calendar-event-drawing-canvas')),
      findsOneWidget,
    );

    final saveButton = find.byKey(const Key('calendar-event-save'));
    expect(tester.widget<TextButton>(saveButton).onPressed, isNotNull);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(repository.lastRequest?.title, '첫 여행');
    expect(repository.lastRequest?.eventDate, DateTime(2026, 8, 2));
    expect(repository.lastPreviewBytes, isNull);
    expect(find.text('calendar'), findsOneWidget);
  });

  testWidgets('preserves basic and optional values when returning a step', (
    tester,
  ) async {
    final repository = _FakeCalendarEventRepository();
    final router = _eventEditorRouter();

    await tester.pumpWidget(
      _eventEditorApp(router: router, repository: repository),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('calendar-event-title-field')),
      '여름 휴가',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('calendar-event-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('calendar-event-mode-memo')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('calendar-event-memo-field')),
      '바다 근처에서 쉬기',
    );

    await tester.tap(find.byType(AppBackButton));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('calendar-event-basic-step')), findsOneWidget);
    expect(
      tester
          .widget<TextField>(
            find.byKey(const Key('calendar-event-title-field')),
          )
          .controller
          ?.text,
      '여름 휴가',
    );
    expect(repository.lastRequest, isNull);

    await tester.tap(find.byKey(const Key('calendar-event-next')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('calendar-event-memo-field')), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('calendar-event-memo-field')))
          .controller
          ?.text,
      '바다 근처에서 쉬기',
    );
  });
}

GoRouter _eventEditorRouter() {
  return GoRouter(
    initialLocation: '/calendar/event/new',
    routes: [
      GoRoute(
        path: '/calendar',
        builder: (context, state) => const Text('calendar'),
      ),
      GoRoute(
        path: '/calendar/event/new',
        builder: (context, state) => Scaffold(
          body: CoupleCalendarEventEditorScreen.create(
            initialDate: DateTime(2026, 8, 2),
          ),
        ),
      ),
    ],
  );
}

Widget _eventEditorApp({
  required GoRouter router,
  required CoupleCalendarEventRepository repository,
}) {
  return ProviderScope(
    overrides: [
      coupleControllerProvider.overrideWithBuild(
        (ref, notifier) async => activeCouple(
          relationshipStartDate: DateTime(2026, 5, 1),
          currentDate: DateTime(2026, 7, 26),
        ),
      ),
      coupleCalendarEventRepositoryProvider.overrideWithValue(repository),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

class _FakeCalendarEventRepository implements CoupleCalendarEventRepository {
  CoupleCalendarEventSaveRequest? lastRequest;
  Uint8List? lastPreviewBytes;

  @override
  Future<void> deleteEvent({
    required String eventId,
    required int expectedRevision,
  }) async {}

  @override
  Future<CoupleCalendarEvent?> fetchEvent(String eventId) async => null;

  @override
  Future<Uint8List> fetchArtworkDrawingData(String drawingDataPath) async {
    return Uint8List(0);
  }

  @override
  Future<List<CoupleCalendarEvent>> fetchOccurrences({
    required DateTime startDate,
    required DateTime endDate,
  }) async => const [];

  @override
  Future<CoupleCalendarEvent> saveEvent({
    required String coupleId,
    required CoupleCalendarEventSaveRequest request,
    Uint8List? previewBytes,
    Uint8List? drawingDataBytes,
  }) async {
    lastRequest = request;
    lastPreviewBytes = previewBytes;
    return CoupleCalendarEvent(
      id: request.eventId,
      coupleId: coupleId,
      title: request.title,
      eventDate: request.eventDate,
      occurrenceDate: request.eventDate,
      repeatRule: request.repeatRule,
      memo: request.memo,
      revision: 1,
      createdByUserId: 'user-a',
      updatedByUserId: 'user-a',
      createdAt: DateTime(2026, 7, 26),
      updatedAt: DateTime(2026, 7, 26),
      reminder: request.reminder,
    );
  }
}
