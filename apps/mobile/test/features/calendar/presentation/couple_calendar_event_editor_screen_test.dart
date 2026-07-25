import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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

    expect(find.text('일정 추가'), findsOneWidget);
    expect(find.text('그림은 선택 사항이에요'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('calendar-event-title-field')),
      '첫 여행',
    );
    await tester.pump();
    final saveButton = find.byKey(const Key('calendar-event-save'));
    expect(tester.widget<TextButton>(saveButton).onPressed, isNotNull);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(repository.lastRequest?.title, '첫 여행');
    expect(repository.lastRequest?.eventDate, DateTime(2026, 8, 2));
    expect(repository.lastPreviewBytes, isNull);
    expect(find.text('calendar'), findsOneWidget);
  });
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
