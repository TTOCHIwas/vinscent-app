import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vinscent/core/drawing/app_drawing_controller.dart';
import 'package:vinscent/core/drawing/widgets/app_drawing_canvas.dart';
import 'package:vinscent/core/drawing/widgets/app_drawing_style_controls.dart';
import 'package:vinscent/core/presentation/widgets/app_back_button.dart';
import 'package:vinscent/core/theme/app_colors.dart';
import 'package:vinscent/features/calendar/data/couple_calendar_event.dart';
import 'package:vinscent/features/calendar/data/couple_calendar_event_repository.dart';
import 'package:vinscent/features/calendar/presentation/couple_calendar_event_editor_screen.dart';
import 'package:vinscent/features/calendar/presentation/widgets/couple_calendar_event_extras_form.dart';
import 'package:vinscent/features/couple/application/couple_controller.dart';

import '../../../support/couple_fixtures.dart';
import '../../../support/color_picker_test_helpers.dart';
import '../../../support/drawing_layout_test_helpers.dart';

void main() {
  for (final size in [
    const Size(320, 700),
    const Size(900, 1200),
    const Size(800, 360),
  ]) {
    testWidgets('shared drawing layout for event on $size', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _eventEditorApp(
          router: _eventEditorRouter(),
          repository: _FakeCalendarEventRepository(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('calendar-event-title-field')),
        '함께 산책',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('calendar-event-next')));
      await tester.pumpAndSettle();
      expect(find.text('꾸미기'), findsNothing);
      expectSharedDrawingLayout(
        tester,
        keyPrefix: 'calendar-event-drawing',
        canvas: find.byKey(const Key('calendar-event-drawing-canvas')),
      );
      expect(find.byKey(const Key('calendar-event-save')), findsOneWidget);
      expect(find.byKey(const Key('calendar-event-mode-memo')), findsOneWidget);
    });
  }

  testWidgets('samples event canvas without adding drawing data', (
    tester,
  ) async {
    final drawing = AppDrawingController();
    final memo = TextEditingController();
    addTearDown(drawing.dispose);
    addTearDown(memo.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListenableBuilder(
            listenable: drawing,
            builder: (context, _) => CoupleCalendarEventExtrasForm(
              memoController: memo,
              drawingController: drawing,
              mode: CalendarEventExtrasMode.drawing,
              canEdit: true,
              isSaving: false,
              onModeChanged: (_) {},
              onClearDrawing: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final sampler = await openColorPicker(
      tester,
      buttonPrefix: 'calendar-event-drawing',
    );
    await tester.tapAt(sampler.canvasRect.center);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<AppDrawingStyleControls>(find.byType(AppDrawingStyleControls))
          .selectedColor,
      AppColors.formSurface,
    );
    expect(drawing.visibleStrokes, isEmpty);
  });

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
    expect(
      find.descendant(
        of: find.byKey(const Key('calendar-event-basic-step')),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Material && widget.color == AppColors.formSurface,
        ),
      ),
      findsNothing,
    );

    final titleField = tester.widget<TextField>(
      find.byKey(const Key('calendar-event-title-field')),
    );
    final titleFocusedBorder =
        titleField.decoration?.focusedBorder as UnderlineInputBorder;
    final repeatControl = tester
        .widget<SegmentedButton<CoupleCalendarEventRepeatRule>>(
          find.byType(SegmentedButton<CoupleCalendarEventRepeatRule>),
        );
    final selectedState = {WidgetState.selected};
    final reminderToggle = tester.widget<SwitchListTile>(
      find.byKey(const Key('calendar-event-reminder-toggle')),
    );

    expect(titleField.decoration?.filled, isFalse);
    expect(
      titleFocusedBorder.borderSide,
      const BorderSide(color: AppColors.settingsDivider),
    );
    expect(titleField.decoration?.counterText, isEmpty);
    expect(
      repeatControl.style?.backgroundColor?.resolve(selectedState),
      AppColors.brandAccent,
    );
    expect(
      repeatControl.style?.foregroundColor?.resolve(selectedState),
      AppColors.onBrandAction,
    );
    expect(
      repeatControl.style?.side?.resolve(selectedState)?.color,
      AppColors.brandAccent,
    );
    expect(reminderToggle.activeTrackColor, AppColors.brandAccent);
    expect(reminderToggle.activeThumbColor, AppColors.onBrandAction);

    await tester.enterText(
      find.byKey(const Key('calendar-event-title-field')),
      '첫 여행',
    );
    await tester.pump();
    final nextButton = find.byKey(const Key('calendar-event-next'));
    expect(tester.widget<IconButton>(nextButton).onPressed, isNotNull);
    expect(
      find.descendant(
        of: nextButton,
        matching: find.byIcon(Icons.chevron_right_rounded),
      ),
      findsOneWidget,
    );
    await tester.tap(nextButton);
    await tester.pumpAndSettle();

    expect(repository.lastRequest, isNull);
    expect(find.byKey(const Key('calendar-event-basic-step')), findsNothing);
    expect(find.byKey(const Key('calendar-event-extras-step')), findsOneWidget);
    expect(
      find.byKey(const Key('calendar-event-drawing-canvas')),
      findsOneWidget,
    );
    final extrasControl = tester
        .widget<SegmentedButton<CalendarEventExtrasMode>>(
          find.byType(SegmentedButton<CalendarEventExtrasMode>),
        );
    expect(
      extrasControl.style?.backgroundColor?.resolve(selectedState),
      AppColors.brandAccent,
    );
    expect(
      extrasControl.style?.foregroundColor?.resolve(selectedState),
      AppColors.onBrandAction,
    );
    expect(
      extrasControl.style?.side?.resolve(selectedState)?.color,
      AppColors.brandAccent,
    );

    final saveButton = find.byKey(const Key('calendar-event-save'));
    expect(tester.widget<IconButton>(saveButton).onPressed, isNotNull);
    expect(
      find.descendant(
        of: saveButton,
        matching: find.byIcon(Icons.check_rounded),
      ),
      findsOneWidget,
    );
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(repository.lastRequest?.title, '첫 여행');
    expect(repository.lastRequest?.eventDate, DateTime(2026, 8, 2));
    expect(repository.lastPreviewBytes, isNull);
    expect(find.text('calendar'), findsOneWidget);
  });

  testWidgets('opens date and reminder choices in app bottom sheets', (
    tester,
  ) async {
    final repository = _FakeCalendarEventRepository();
    final router = _eventEditorRouter();

    await tester.pumpWidget(
      _eventEditorApp(router: router, repository: repository),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('calendar-event-date')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('calendar-event-date-picker-sheet')),
      findsOneWidget,
    );
    await tester.tap(find.text('완료'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('calendar-event-reminder-toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('calendar-event-reminder-offset')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('calendar-event-reminder-offset-sheet')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('calendar-event-reminder-offset-3')));
    await tester.pumpAndSettle();
    expect(find.text('3일 전'), findsOneWidget);

    final reminderTime = find.byKey(const Key('calendar-event-reminder-time'));
    await tester.ensureVisible(reminderTime);
    await tester.pumpAndSettle();
    await tester.tap(reminderTime);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('app-time-picker-sheet')), findsOneWidget);
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

  testWidgets('preserves strokes across memo mode and saves both', (
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
      '산책',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('calendar-event-next')));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(AppDrawingCanvas), const Offset(50, 20));
    await tester.pump();
    final strokes = tester
        .widget<AppDrawingCanvas>(find.byType(AppDrawingCanvas))
        .strokes;
    expect(strokes, hasLength(1));
    await tester.tap(find.byKey(const Key('calendar-event-mode-memo')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('calendar-event-memo-field')),
      '함께 걷기',
    );
    await tester.tap(find.byKey(const Key('calendar-event-mode-drawing')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<AppDrawingCanvas>(find.byType(AppDrawingCanvas)).strokes,
      strokes,
    );
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('calendar-event-save')));
      for (
        var attempt = 0;
        attempt < 100 && repository.lastRequest == null;
        attempt++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await tester.pumpAndSettle();
    expect(repository.lastRequest?.title, '산책');
    expect(repository.lastRequest?.memo, '함께 걷기');
    expect(repository.lastPreviewBytes, isNotEmpty);
    final data =
        jsonDecode(utf8.decode(gzip.decode(repository.lastDrawingDataBytes!)))
            as Map<String, dynamic>;
    expect(data['strokes'], hasLength(1));
    expect(router.routeInformationProvider.value.uri.path, '/calendar');
  });

  testWidgets('keeps reminders available for a past yearly event', (
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
              initialDate: DateTime(2026, 7, 25),
            ),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      _eventEditorApp(router: router, repository: repository),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('calendar-event-title-field')),
      '생일',
    );
    final repeatControl = tester
        .widget<SegmentedButton<CoupleCalendarEventRepeatRule>>(
          find.byType(SegmentedButton<CoupleCalendarEventRepeatRule>),
        );
    repeatControl.onSelectionChanged?.call({
      CoupleCalendarEventRepeatRule.yearly,
    });
    await tester.pump();

    final reminderToggle = tester.widget<SwitchListTile>(
      find.byKey(const Key('calendar-event-reminder-toggle')),
    );
    expect(reminderToggle.onChanged, isNotNull);
    reminderToggle.onChanged?.call(true);
    await tester.pump();

    await tester.tap(find.byKey(const Key('calendar-event-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('calendar-event-save')));
    await tester.pumpAndSettle();

    expect(
      repository.lastRequest?.repeatRule,
      CoupleCalendarEventRepeatRule.yearly,
    );
    expect(repository.lastRequest?.reminder.isEnabled, isTrue);
  });

  testWidgets('recovers after loading an event succeeds on retry', (
    tester,
  ) async {
    final event = _calendarEvent();
    final repository = _FakeCalendarEventRepository(
      fetchResults: [StateError('temporary failure'), event],
    );
    final router = GoRouter(
      initialLocation: '/calendar/event/${event.id}',
      routes: [
        GoRoute(
          path: '/calendar',
          builder: (context, state) => const Text('calendar'),
        ),
        GoRoute(
          path: '/calendar/event/:eventId',
          builder: (context, state) => Scaffold(
            body: CoupleCalendarEventEditorScreen.edit(
              eventId: state.pathParameters['eventId']!,
            ),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      _eventEditorApp(router: router, repository: repository),
    );
    await tester.pumpAndSettle();

    expect(find.text('일정을 불러오지 못했어요'), findsOneWidget);

    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();

    expect(find.text('일정을 불러오지 못했어요'), findsNothing);
    expect(find.byKey(const Key('calendar-event-basic-step')), findsOneWidget);
    expect(
      tester
          .widget<TextField>(
            find.byKey(const Key('calendar-event-title-field')),
          )
          .controller
          ?.text,
      event.title,
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
  _FakeCalendarEventRepository({List<Object?> fetchResults = const []})
    : _fetchResults = List<Object?>.of(fetchResults);

  final List<Object?> _fetchResults;
  CoupleCalendarEventSaveRequest? lastRequest;
  Uint8List? lastPreviewBytes;
  Uint8List? lastDrawingDataBytes;

  @override
  Future<void> deleteEvent({
    required String eventId,
    required int expectedRevision,
  }) async {}

  @override
  Future<CoupleCalendarEvent?> fetchEvent(String eventId) async {
    if (_fetchResults.isEmpty) {
      return null;
    }
    final result = _fetchResults.removeAt(0);
    if (result is Error) {
      throw result;
    }
    if (result is Exception) {
      throw result;
    }
    return result as CoupleCalendarEvent?;
  }

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
    lastDrawingDataBytes = drawingDataBytes;
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

CoupleCalendarEvent _calendarEvent() {
  return CoupleCalendarEvent(
    id: 'event-1',
    coupleId: 'couple-1',
    title: '함께하는 생일',
    eventDate: DateTime(2026, 5, 2),
    occurrenceDate: DateTime(2026, 5, 2),
    repeatRule: CoupleCalendarEventRepeatRule.yearly,
    memo: null,
    revision: 1,
    createdByUserId: 'user-a',
    updatedByUserId: 'user-a',
    createdAt: DateTime(2026, 5, 1),
    updatedAt: DateTime(2026, 5, 1),
    reminder: const CoupleCalendarEventReminder(
      isEnabled: true,
      offsetDays: 1,
      hour: 9,
      minute: 0,
    ),
  );
}
