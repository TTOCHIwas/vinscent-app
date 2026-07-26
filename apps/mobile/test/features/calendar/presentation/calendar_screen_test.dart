import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vinscent/core/date/app_date_policy.dart';
import 'package:vinscent/core/date/today_controller.dart';
import 'package:vinscent/core/presentation/widgets/app_horizontal_page_transition.dart';
import 'package:vinscent/core/theme/app_colors.dart';
import 'package:vinscent/core/theme/app_theme.dart';
import 'package:vinscent/features/ai/application/ai_question_feedback_provider.dart';
import 'package:vinscent/features/ai/data/ai_learning_dashboard.dart';
import 'package:vinscent/features/calendar/data/couple_calendar_event.dart';
import 'package:vinscent/features/calendar/data/couple_calendar_event_repository.dart';
import 'package:vinscent/features/calendar/presentation/calendar_month_layout_metrics.dart';
import 'package:vinscent/features/calendar/presentation/calendar_screen.dart';
import 'package:vinscent/features/calendar/presentation/widgets/calendar_detail_date_header.dart';
import 'package:vinscent/features/calendar/presentation/widgets/calendar_month_story_cell.dart';
import 'package:vinscent/features/calendar/presentation/widgets/calendar_story_card_stack.dart';
import 'package:vinscent/features/couple/application/couple_controller.dart';
import 'package:vinscent/features/couple/data/couple.dart';
import 'package:vinscent/features/profile/application/profile_controller.dart';
import 'package:vinscent/features/profile/data/user_profile.dart';
import 'package:vinscent/features/questions/data/daily_question.dart';
import 'package:vinscent/features/questions/data/daily_question_answer_state.dart';
import 'package:vinscent/features/questions/presentation/widgets/question_answer_prompt_row.dart';
import 'package:vinscent/features/questions/presentation/widgets/question_answer_sections.dart';
import 'package:vinscent/features/story_loops/data/story_card_scene.dart';
import 'package:vinscent/features/story_loops/data/story_loop_detail.dart';
import 'package:vinscent/features/story_loops/data/story_loop_month_summary_day.dart';
import 'package:vinscent/features/story_loops/data/story_loop_question_detail.dart';
import 'package:vinscent/features/story_loops/data/story_loop_read_repository.dart';
import 'package:vinscent/features/story_loops/data/story_loop_status.dart';
import 'package:vinscent/features/story_loops/data/today_story_loop_summary.dart';
import 'package:vinscent/features/story_loops/presentation/widgets/story_card_preview_surface.dart';

import '../../../support/couple_fixtures.dart';
import '../../../support/story_loop_fixtures.dart';
import '../../../support/text_finders.dart';

void main() {
  testWidgets('keeps the date label inside its marker when text is enlarged', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ko'),
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        supportedLocales: const [Locale('ko')],
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: Center(
          child: SizedBox(
            width: 52,
            height: 72,
            child: CalendarMonthStoryCell(
              date: DateTime(2026, 5, 10),
              textColor: AppColors.textPrimary,
              isSelected: true,
              summary: null,
            ),
          ),
        ),
      ),
    );

    final textFinder = find.text('10');
    final text = tester.widget<Text>(textFinder);
    final context = tester.element(textFinder);
    final style = DefaultTextStyle.of(context).style.merge(text.style);
    final painter = TextPainter(
      text: TextSpan(text: '10', style: style),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    addTearDown(painter.dispose);

    expect(text.style?.height, 1);
    expect(text.style?.fontSize, 12);
    expect(painter.height, lessThanOrEqualTo(16));
    expect(tester.takeException(), isNull);
  });

  testWidgets('selects today and loads its detail on entry', (tester) async {
    final repository = FakeStoryLoopReadRepository(
      details: {DateTime(2026, 5, 10): _todayPendingDetail},
    );
    await _pumpCalendar(tester, repository: repository);

    expect(find.text('2026년 05월'), findsOneWidget);
    expect(find.text('날짜를 선택해 주세요'), findsNothing);
    expect(find.text('today history question'), findsOneWidget);
    expect(repository.requestedMonths, [DateTime(2026, 5)]);
    expect(repository.requestedDetailDates, [DateTime(2026, 5, 10)]);
    expect(
      _circularDecorations(
        tester,
        find.byKey(
          const ValueKey('calendar-month-story-cell-empty-2026-05-10'),
        ),
      ).map((decoration) => decoration.color),
      contains(AppColors.actionPrimary),
    );
  });

  testWidgets('selects the date supplied by the route on entry', (
    tester,
  ) async {
    final repository = FakeStoryLoopReadRepository(
      details: {DateTime(2026, 5, 9): _todayPendingDetail},
    );
    await _pumpCalendar(
      tester,
      repository: repository,
      relationshipStartDate: DateTime(2026, 5, 1),
      initialDate: DateTime(2026, 5, 9),
    );

    expect(repository.requestedDetailDates, [DateTime(2026, 5, 9)]);
    expect(
      _circularDecorations(
        tester,
        find.byKey(
          const ValueKey('calendar-month-story-cell-empty-2026-05-09'),
        ),
      ).map((decoration) => decoration.color),
      contains(AppColors.actionPrimary),
    );
  });

  testWidgets('fills and left aligns the selected date header', (tester) async {
    await _pumpCalendar(
      tester,
      repository: FakeStoryLoopReadRepository(),
      relationshipStartDate: DateTime(2026, 5, 1),
    );

    final scrollView = find.byKey(const Key('calendar-scroll-view'));
    final header = find.byType(CalendarDetailDateHeader);
    final headerTexts = find.descendant(
      of: header,
      matching: find.byType(Text),
    );

    expect(tester.getSize(header).width, tester.getSize(scrollView).width);
    expect(
      tester.getTopLeft(headerTexts.first).dx,
      closeTo(tester.getTopLeft(scrollView).dx + 20, 0.5),
    );
    final headerRect = tester.getRect(header);
    final topGap = tester.getRect(headerTexts.first).top - headerRect.top;
    final bottomGap =
        headerRect.bottom - tester.getRect(headerTexts.last).bottom;
    expect(topGap, closeTo(bottomGap, 0.5));
  });

  testWidgets('keeps the calendar readable on a narrow enlarged-text screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpCalendar(
      tester,
      repository: FakeStoryLoopReadRepository(),
      textScaleFactor: 1.3,
      calendarEvents: [
        _calendarEvent(
          id: 'long-event',
          title: '함께 오래 기억하고 싶은 아주 긴 일정 제목',
          date: DateTime(2026, 5, 10),
        ),
      ],
    );

    expect(find.text('2026년 05월'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('swipes the selected-day detail one day at a time', (
    tester,
  ) async {
    final repository = FakeStoryLoopReadRepository();
    await _pumpCalendar(
      tester,
      repository: repository,
      relationshipStartDate: DateTime(2026, 5, 9),
    );
    final swipeRegion = find.byKey(
      const Key('calendar-detail-date-swipe-region'),
    );

    await tester.fling(swipeRegion, const Offset(300, 0), 1000);
    await tester.pumpAndSettle();

    expect(repository.requestedDetailDates, [
      DateTime(2026, 5, 10),
      DateTime(2026, 5, 9),
    ]);
    expect(
      _circularDecorations(
        tester,
        find.byKey(
          const ValueKey('calendar-month-story-cell-empty-2026-05-09'),
        ),
      ).map((decoration) => decoration.color),
      contains(AppColors.actionPrimary),
    );

    await tester.fling(swipeRegion, const Offset(300, 0), 1000);
    await tester.pumpAndSettle();
    expect(repository.requestedDetailDates, [
      DateTime(2026, 5, 10),
      DateTime(2026, 5, 9),
    ]);

    await tester.fling(swipeRegion, const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();

    expect(repository.requestedDetailDates, [
      DateTime(2026, 5, 10),
      DateTime(2026, 5, 9),
      DateTime(2026, 5, 10),
    ]);
    expect(
      _circularDecorations(
        tester,
        find.byKey(
          const ValueKey('calendar-month-story-cell-empty-2026-05-10'),
        ),
      ).map((decoration) => decoration.color),
      contains(AppColors.actionPrimary),
    );

    await tester.fling(swipeRegion, const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(repository.requestedDetailDates, [
      DateTime(2026, 5, 10),
      DateTime(2026, 5, 9),
      DateTime(2026, 5, 10),
    ]);
    expect(
      _circularDecorations(
        tester,
        find.byKey(
          const ValueKey('calendar-month-story-cell-empty-2026-05-11'),
        ),
      ).map((decoration) => decoration.color),
      contains(AppColors.actionPrimary),
    );
  });

  testWidgets('ignores a short fast date flick', (tester) async {
    final repository = FakeStoryLoopReadRepository();
    await _pumpCalendar(
      tester,
      repository: repository,
      relationshipStartDate: DateTime(2026, 5, 9),
    );

    await tester.fling(
      find.byKey(const Key('calendar-detail-date-swipe-region')),
      const Offset(64, 0),
      2000,
    );
    await tester.pumpAndSettle();

    expect(repository.requestedDetailDates, [DateTime(2026, 5, 10)]);
  });

  testWidgets('updates the visible month when a date swipe crosses a month', (
    tester,
  ) async {
    final repository = FakeStoryLoopReadRepository();
    await _pumpCalendar(
      tester,
      repository: repository,
      today: DateTime(2026, 6, 1),
    );

    await tester.fling(
      find.byKey(const Key('calendar-detail-date-swipe-region')),
      const Offset(300, 0),
      1000,
    );
    await tester.pumpAndSettle();

    expect(find.text('2026년 05월'), findsOneWidget);
    expect(repository.requestedMonths, [DateTime(2026, 6), DateTime(2026, 5)]);
    expect(repository.requestedDetailDates, [
      DateTime(2026, 6, 1),
      DateTime(2026, 5, 31),
    ]);
  });

  testWidgets(
    'moves the standard calendar one month while preserving the day',
    (tester) async {
      final repository = FakeStoryLoopReadRepository();
      await _pumpCalendar(
        tester,
        repository: repository,
        today: DateTime(2026, 6, 2),
      );

      await tester.fling(
        find.byKey(const Key('calendar-month-swipe-region')),
        const Offset(300, 0),
        1000,
      );
      await tester.pumpAndSettle();

      expect(find.text('2026년 05월'), findsOneWidget);
      expect(repository.requestedMonths, [
        DateTime(2026, 6),
        DateTime(2026, 5),
      ]);
      expect(repository.requestedDetailDates, [
        DateTime(2026, 6, 2),
        DateTime(2026, 5, 2),
      ]);
    },
  );

  testWidgets(
    'slides horizontal calendar changes while keeping weekdays fixed',
    (tester) async {
      await _pumpCalendar(tester, repository: FakeStoryLoopReadRepository());
      final swipeRegion = find.byKey(const Key('calendar-month-swipe-region'));

      await tester.fling(swipeRegion, const Offset(-300, 0), 1000);
      await tester.pump();

      expect(find.text('2026년 06월'), findsOneWidget);
      expect(find.byType(AppHorizontalPageTransition), findsWidgets);
      expect(find.byType(CalendarDetailDateHeader), findsNWidgets(2));
      expect(find.text('월'), findsOneWidget);

      await tester.pumpAndSettle();

      expect(find.byType(CalendarDetailDateHeader), findsOneWidget);
      expect(find.text('2026년 06월'), findsOneWidget);
    },
  );

  testWidgets('moves the weekly calendar by seven days', (tester) async {
    final repository = FakeStoryLoopReadRepository();
    await _pumpCalendar(
      tester,
      repository: repository,
      relationshipStartDate: DateTime(2026, 5, 1),
    );
    final scrollView = tester.widget<CustomScrollView>(
      find.byKey(const Key('calendar-scroll-view')),
    );
    final metrics = CalendarMonthLayoutMetrics.forViewport(
      tester.getSize(find.byKey(const Key('calendar-scroll-view'))).height,
    );

    await tester.drag(
      find.byKey(const Key('calendar-scroll-view')),
      const Offset(0, -1000),
    );
    await tester.pumpAndSettle();
    expect(
      scrollView.controller!.offset,
      closeTo(metrics.weeklyScrollOffset, 0.5),
    );

    await tester.fling(
      find.byKey(const Key('calendar-month-swipe-region')),
      const Offset(-300, 0),
      1000,
    );
    await tester.pumpAndSettle();

    expect(find.text('5월 17일'), findsOneWidget);
    expect(repository.requestedDetailDates, [DateTime(2026, 5, 10)]);
  });

  testWidgets('does not move before relationship start month', (tester) async {
    final repository = FakeStoryLoopReadRepository();

    await _pumpCalendar(tester, repository: repository);

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();

    expect(find.text('2026년 05월'), findsOneWidget);
    expect(find.text('2026년 04월'), findsNothing);
    expect(repository.requestedMonths, [DateTime(2026, 5)]);
    expect(repository.requestedDetailDates, [DateTime(2026, 5, 10)]);
  });

  testWidgets('centers month navigation and keeps add at the far right', (
    tester,
  ) async {
    await _pumpCalendar(
      tester,
      repository: FakeStoryLoopReadRepository(),
      relationshipStartDate: DateTime(2026, 5, 1),
    );

    final titleCenter = tester.getCenter(find.text('2026년 05월')).dx;
    final previousCenter = tester
        .getCenter(find.byKey(const Key('calendar-previous-month')))
        .dx;
    final nextCenter = tester
        .getCenter(find.byKey(const Key('calendar-next-month')))
        .dx;
    final addCenter = tester
        .getCenter(find.byKey(const Key('calendar-add-event')))
        .dx;

    expect((previousCenter + nextCenter) / 2, closeTo(titleCenter, 0.5));
    expect(
      titleCenter,
      closeTo(
        tester.view.physicalSize.width / tester.view.devicePixelRatio / 2,
        0.5,
      ),
    );
    expect(addCenter, greaterThan(nextCenter));
  });

  testWidgets('moves to previous month after relationship start month', (
    tester,
  ) async {
    final repository = FakeStoryLoopReadRepository();

    await _pumpCalendar(
      tester,
      repository: repository,
      today: DateTime(2026, 6, 2),
    );

    expect(find.text('2026년 06월'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();

    expect(find.text('2026년 05월'), findsOneWidget);
    expect(repository.requestedMonths, [DateTime(2026, 6), DateTime(2026, 5)]);
    expect(repository.requestedDetailDates, [
      DateTime(2026, 6, 2),
      DateTime(2026, 5, 2),
    ]);
  });

  testWidgets('moves to a future month for shared schedules', (tester) async {
    final repository = FakeStoryLoopReadRepository();

    await _pumpCalendar(tester, repository: repository);

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();

    expect(find.text('2026년 06월'), findsOneWidget);
    expect(find.text('2026년 05월'), findsNothing);
    expect(repository.requestedMonths, [DateTime(2026, 5)]);
    expect(repository.requestedDetailDates, [DateTime(2026, 5, 10)]);
  });

  testWidgets('uses thresholds and moves only one calendar state per gesture', (
    tester,
  ) async {
    await _pumpCalendar(tester, repository: FakeStoryLoopReadRepository());
    final scrollView = tester.widget<CustomScrollView>(
      find.byKey(const Key('calendar-scroll-view')),
    );
    final controller = scrollView.controller!;
    final metrics = CalendarMonthLayoutMetrics.forViewport(
      tester.getSize(find.byKey(const Key('calendar-scroll-view'))).height,
    );

    expect(controller.offset, closeTo(metrics.standardScrollOffset, 0.5));

    await tester.drag(
      find.byKey(const Key('calendar-scroll-view')),
      const Offset(0, 40),
    );
    await tester.pumpAndSettle();
    expect(controller.offset, closeTo(metrics.standardScrollOffset, 0.5));

    await tester.drag(
      find.byKey(const Key('calendar-scroll-view')),
      const Offset(0, 1000),
    );
    await tester.pumpAndSettle();
    expect(controller.offset, closeTo(0, 0.5));

    await tester.drag(
      find.byKey(const Key('calendar-scroll-view')),
      const Offset(0, -1000),
    );
    await tester.pumpAndSettle();
    expect(controller.offset, closeTo(metrics.standardScrollOffset, 0.5));

    await tester.drag(
      find.byKey(const Key('calendar-scroll-view')),
      const Offset(0, -1000),
    );
    await tester.pumpAndSettle();
    expect(controller.offset, closeTo(metrics.weeklyScrollOffset, 0.5));
  });

  testWidgets('resists small drags before snapping the calendar state', (
    tester,
  ) async {
    await _pumpCalendar(tester, repository: FakeStoryLoopReadRepository());
    final scrollFinder = find.byKey(const Key('calendar-scroll-view'));
    final scrollView = tester.widget<CustomScrollView>(scrollFinder);
    final controller = scrollView.controller!;
    final startOffset = controller.offset;

    final gesture = await tester.startGesture(tester.getCenter(scrollFinder));
    await gesture.moveBy(const Offset(0, -24));
    await tester.pump();
    final recognizedStartOffset = controller.offset;

    await gesture.moveBy(const Offset(0, -16));
    await tester.pump();

    expect(controller.offset, closeTo(recognizedStartOffset, 0.5));

    await gesture.moveBy(const Offset(0, -24));
    await tester.pump();

    expect(controller.offset - recognizedStartOffset, inInclusiveRange(5, 8));

    await gesture.up();
    await tester.pumpAndSettle();

    expect(controller.offset, closeTo(startOffset, 0.5));
  });

  testWidgets('does not rebuild the full screen while snapping states', (
    tester,
  ) async {
    await _pumpCalendar(tester, repository: FakeStoryLoopReadRepository());
    final rebuildMessages = <String>[];
    final previousDebugPrint = debugPrint;
    final previousDebugPrintRebuildDirtyWidgets = debugPrintRebuildDirtyWidgets;
    debugPrint = (message, {wrapWidth}) {
      if (message != null) {
        rebuildMessages.add(message);
      }
    };
    debugPrintRebuildDirtyWidgets = true;

    try {
      await tester.drag(
        find.byKey(const Key('calendar-scroll-view')),
        const Offset(0, 1000),
      );
      await tester.pumpAndSettle();
    } finally {
      debugPrint = previousDebugPrint;
      debugPrintRebuildDirtyWidgets = previousDebugPrintRebuildDirtyWidgets;
    }

    expect(
      rebuildMessages.where((message) => message.contains('CalendarScreen')),
      isEmpty,
    );
  });

  testWidgets(
    'keeps the date header pinned and hands detail scrolling off at its top',
    (tester) async {
      final repository = FakeStoryLoopReadRepository(
        details: {DateTime(2026, 5, 5): _completedDetail},
      );
      await _pumpCalendar(
        tester,
        repository: repository,
        initialDate: DateTime(2026, 5, 5),
      );
      final scrollFinder = find.byKey(const Key('calendar-scroll-view'));
      final scrollView = tester.widget<CustomScrollView>(scrollFinder);
      final controller = scrollView.controller!;
      final metrics = CalendarMonthLayoutMetrics.forViewport(
        tester.getSize(scrollFinder).height,
      );

      await tester.drag(scrollFinder, const Offset(0, -1000));
      await tester.pumpAndSettle();
      expect(controller.offset, closeTo(metrics.weeklyScrollOffset, 0.5));

      final headerTop = tester.getTopLeft(find.text('5월 5일')).dy;
      await tester.drag(scrollFinder, const Offset(0, -320));
      await tester.pumpAndSettle();
      expect(controller.offset, greaterThan(metrics.weeklyScrollOffset));
      expect(tester.getTopLeft(find.text('5월 5일')).dy, closeTo(headerTop, 0.5));

      await tester.drag(scrollFinder, const Offset(0, 1000));
      await tester.pumpAndSettle();
      expect(controller.offset, closeTo(metrics.weeklyScrollOffset, 0.5));

      await tester.drag(scrollFinder, const Offset(0, 1000));
      await tester.pumpAndSettle();
      expect(controller.offset, closeTo(metrics.standardScrollOffset, 0.5));
    },
  );

  testWidgets('opens the shared event editor with the selected date', (
    tester,
  ) async {
    await _pumpCalendar(tester, repository: FakeStoryLoopReadRepository());

    await tester.tap(find.byKey(const Key('calendar-add-event')));
    await tester.pumpAndSettle();

    expect(find.text('calendar event date 2026-05-10'), findsOneWidget);
  });

  testWidgets('shows a shared event in its cell and selected day detail', (
    tester,
  ) async {
    final event = _calendarEvent(
      id: 'event-1',
      title: '함께 여행',
      date: DateTime(2026, 5, 5),
    );
    await _pumpCalendar(
      tester,
      repository: FakeStoryLoopReadRepository(),
      calendarEvents: [event],
    );

    expect(
      find.byKey(const ValueKey('calendar-event-indicator-event-1')),
      findsOneWidget,
    );
    await tester.tap(find.text('5').first);
    await tester.pumpAndSettle();

    expect(find.text('함께 여행'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('calendar-event-menu-event-1')),
      findsOneWidget,
    );
  });

  testWidgets(
    'enlarges cardless event artwork across standard expanded and weekly states',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final events = [
        _calendarEvent(
          id: 'event-without-art',
          title: '그림 없는 일정',
          date: DateTime(2026, 5, 10),
        ),
        _calendarEvent(
          id: 'event-with-art',
          title: '그림 있는 일정',
          date: DateTime(2026, 5, 10),
          artwork: const CoupleCalendarEventArtwork(
            previewPath: 'event.webp',
            drawingDataPath: 'event.json.gz',
          ),
        ),
        _calendarEvent(
          id: 'event-with-second-art',
          title: '두 번째 그림 일정',
          date: DateTime(2026, 5, 10),
          artwork: const CoupleCalendarEventArtwork(
            previewPath: 'event-2.webp',
            drawingDataPath: 'event-2.json.gz',
          ),
        ),
      ];
      await _pumpCalendar(
        tester,
        repository: FakeStoryLoopReadRepository(),
        calendarEvents: events,
      );

      expect(
        find.byKey(const ValueKey('calendar-event-indicator-event-with-art')),
        findsOneWidget,
      );
      final firstArtwork = find.byKey(
        const ValueKey('calendar-event-indicator-event-with-art'),
      );
      final standardArtworkSize = tester.getSize(firstArtwork);
      expect(standardArtworkSize.width, greaterThan(18));
      expect(standardArtworkSize.height, greaterThan(18));
      expect(
        find.byKey(
          const ValueKey('calendar-event-indicator-event-with-second-art'),
        ),
        findsNothing,
      );
      expect(find.text('+2'), findsOneWidget);

      await tester.drag(
        find.byKey(const Key('calendar-scroll-view')),
        const Offset(0, 1000),
      );
      await tester.pumpAndSettle();

      final secondArtwork = find.byKey(
        const ValueKey('calendar-event-indicator-event-with-second-art'),
      );
      expect(secondArtwork, findsOneWidget);
      final expandedArtworkSize = tester.getSize(firstArtwork);
      expect(expandedArtworkSize.width, greaterThan(standardArtworkSize.width));
      expect(
        expandedArtworkSize.height,
        greaterThan(standardArtworkSize.height),
      );
      expect(tester.getSize(secondArtwork), expandedArtworkSize);
      expect(
        tester.getCenter(secondArtwork).dy,
        greaterThan(tester.getCenter(firstArtwork).dy),
      );
      expect(find.text('+1'), findsOneWidget);

      await tester.drag(
        find.byKey(const Key('calendar-scroll-view')),
        const Offset(0, -1000),
      );
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const Key('calendar-scroll-view')),
        const Offset(0, -1000),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const ValueKey('calendar-event-indicator-event-with-second-art'),
        ),
        findsNothing,
      );
      final weeklyArtworkSize = tester.getSize(firstArtwork);
      expect(weeklyArtworkSize.width, greaterThan(18));
      expect(weeklyArtworkSize.height, greaterThan(18));
      expect(find.text('+2'), findsOneWidget);
    },
  );

  testWidgets(
    'moves one event artwork from the date header above the expanded card',
    (tester) async {
      tester.view.physicalSize = const Size(360, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = FakeStoryLoopReadRepository(
        monthSummaries: {
          DateTime(2026, 5): [
            sampleMonthSummaryDay(
              coupleDate: DateTime(2026, 5, 5),
              cardCount: 1,
              cards: [
                samplePreviewCard(
                  id: 'event-day-card',
                  submittedAt: DateTime(2026, 5, 5, 9),
                ),
              ],
            ),
            sampleMonthSummaryDay(
              coupleDate: DateTime(2026, 5, 6),
              cardCount: 1,
              cards: [
                samplePreviewCard(
                  id: 'card-only-day-card',
                  submittedAt: DateTime(2026, 5, 6, 9),
                ),
              ],
            ),
          ],
        },
      );
      final events = [
        _calendarEvent(
          id: 'event-day-art-1',
          title: '가 일정',
          date: DateTime(2026, 5, 5),
          artwork: const CoupleCalendarEventArtwork(
            previewPath: 'event-1.webp',
            drawingDataPath: 'event-1.json.gz',
          ),
        ),
        _calendarEvent(
          id: 'event-day-art-2',
          title: '나 일정',
          date: DateTime(2026, 5, 5),
          artwork: const CoupleCalendarEventArtwork(
            previewPath: 'event-2.webp',
            drawingDataPath: 'event-2.json.gz',
          ),
        ),
        _calendarEvent(
          id: 'event-only-art',
          title: '다 일정',
          date: DateTime(2026, 5, 7),
          artwork: const CoupleCalendarEventArtwork(
            previewPath: 'event-only.webp',
            drawingDataPath: 'event-only.json.gz',
          ),
        ),
      ];

      await _pumpCalendar(
        tester,
        repository: repository,
        calendarEvents: events,
      );

      final firstArtwork = find.byKey(
        const ValueKey('calendar-event-indicator-event-day-art-1'),
      );
      final card = find.byKey(
        const ValueKey('calendar-month-story-card-event-day-card'),
      );
      final cardOnly = find.byKey(
        const ValueKey('calendar-month-story-card-card-only-day-card'),
      );
      final eventOnlyArtwork = find.byKey(
        const ValueKey('calendar-event-indicator-event-only-art'),
      );
      final mixedCell = find.byKey(
        const ValueKey('calendar-month-story-cell-single-2026-05-05'),
      );
      final dateLabel = find.descendant(
        of: mixedCell,
        matching: find.text('5'),
      );
      expect(tester.getSize(firstArtwork), const Size.square(18));
      expect(
        tester.getSize(eventOnlyArtwork).width,
        greaterThan(tester.getSize(firstArtwork).width),
      );
      expect(
        tester.getSize(card).width,
        closeTo(tester.getSize(cardOnly).width, 0.1),
      );
      expect(
        tester.getSize(card).height,
        closeTo(tester.getSize(cardOnly).height, 0.1),
      );
      expect(
        tester.getCenter(firstArtwork).dy,
        closeTo(tester.getCenter(dateLabel).dy, 0.5),
      );
      expect(
        tester.getRect(firstArtwork).bottom,
        lessThanOrEqualTo(tester.getRect(card).top),
      );

      await tester.drag(
        find.byKey(const Key('calendar-scroll-view')),
        const Offset(0, 1000),
      );
      await tester.pumpAndSettle();

      final secondArtwork = find.byKey(
        const ValueKey('calendar-event-indicator-event-day-art-2'),
      );
      expect(secondArtwork, findsNothing);
      expect(tester.getSize(firstArtwork), const Size.square(18));
      expect(
        tester.getSize(eventOnlyArtwork).width,
        greaterThan(tester.getSize(firstArtwork).width),
      );
      expect(
        tester.getSize(card).width,
        closeTo(tester.getSize(cardOnly).width, 0.1),
      );
      expect(
        tester.getSize(card).height,
        closeTo(tester.getSize(cardOnly).height, 0.1),
      );
      expect(
        tester.getCenter(firstArtwork).dy,
        greaterThan(tester.getCenter(dateLabel).dy + 10),
      );
      expect(
        tester.getRect(firstArtwork).bottom,
        lessThanOrEqualTo(tester.getRect(card).top),
      );
      expect(find.text('+1'), findsOneWidget);
    },
  );

  testWidgets('prioritizes the default anniversary label in a mixed cell', (
    tester,
  ) async {
    final repository = FakeStoryLoopReadRepository(
      monthSummaries: {
        DateTime(2026, 5): [
          sampleMonthSummaryDay(
            coupleDate: DateTime(2026, 5, 10),
            cardCount: 1,
            cards: [
              samplePreviewCard(
                id: 'anniversary-day-card',
                submittedAt: DateTime(2026, 5, 10, 9),
              ),
            ],
          ),
        ],
      },
    );
    final event = _calendarEvent(
      id: 'anniversary-day-event',
      title: '기념일 일정',
      date: DateTime(2026, 5, 10),
      artwork: const CoupleCalendarEventArtwork(
        previewPath: 'anniversary-event.webp',
        drawingDataPath: 'anniversary-event.json.gz',
      ),
    );

    await _pumpCalendar(
      tester,
      repository: repository,
      relationshipStartDate: DateTime(2026, 5, 1),
      calendarEvents: [event],
    );

    final cell = find.byKey(
      const ValueKey('calendar-month-story-cell-single-2026-05-10'),
    );
    expect(find.descendant(of: cell, matching: find.text('10일')), findsOne);
    expect(
      find.byKey(
        const ValueKey('calendar-event-indicator-anniversary-day-event'),
      ),
      findsNothing,
    );
    expect(
      find.byKey(
        const ValueKey('calendar-month-story-card-anniversary-day-card'),
      ),
      findsOneWidget,
    );

    await tester.drag(
      find.byKey(const Key('calendar-scroll-view')),
      const Offset(0, 1000),
    );
    await tester.pumpAndSettle();

    final artwork = find.byKey(
      const ValueKey('calendar-event-indicator-anniversary-day-event'),
    );
    final card = find.byKey(
      const ValueKey('calendar-month-story-card-anniversary-day-card'),
    );
    expect(artwork, findsOneWidget);
    expect(
      tester.getRect(artwork).bottom,
      lessThanOrEqualTo(tester.getRect(card).top),
    );
  });

  testWidgets('shows inclusive default anniversaries without stored events', (
    tester,
  ) async {
    await _pumpCalendar(
      tester,
      repository: FakeStoryLoopReadRepository(),
      relationshipStartDate: DateTime(2026, 5, 1),
    );

    expect(find.text('10일'), findsNWidgets(2));
  });

  testWidgets('selects a future date without requesting story history', (
    tester,
  ) async {
    final repository = FakeStoryLoopReadRepository();
    await _pumpCalendar(tester, repository: repository);

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    final futureCell = find.byKey(
      const ValueKey('calendar-month-story-cell-empty-2026-06-02'),
    );
    await tester.tap(
      find.ancestor(of: futureCell, matching: find.byType(InkWell)),
    );
    await tester.pumpAndSettle();

    expect(find.text('6월 2일'), findsOneWidget);
    expect(find.text('아직 일정이 없어요'), findsOneWidget);
    expect(repository.requestedDetailDates, [DateTime(2026, 5, 10)]);
  });

  testWidgets('deletes a shared event and refreshes the calendar immediately', (
    tester,
  ) async {
    final event = _calendarEvent(
      id: 'event-to-delete',
      title: '삭제할 일정',
      date: DateTime(2026, 5, 5),
    );
    await _pumpCalendar(
      tester,
      repository: FakeStoryLoopReadRepository(),
      calendarEvents: [event],
    );

    await tester.tap(find.text('5').first);
    await tester.pumpAndSettle();
    await _scrollCalendarUp(tester);
    await tester.tap(
      find.byKey(const ValueKey('calendar-event-menu-event-to-delete')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();

    expect(find.text('일정을 삭제했어요'), findsOneWidget);
    expect(find.text('삭제할 일정'), findsNothing);
    expect(
      find.byKey(const ValueKey('calendar-event-indicator-event-to-delete')),
      findsNothing,
    );
  });

  testWidgets(
    'renders month summary cells for empty single and stacked cards',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repository = FakeStoryLoopReadRepository(
        monthSummaries: {
          DateTime(2026, 5): [
            sampleMonthSummaryDay(
              coupleDate: DateTime(2026, 5, 5),
              cardCount: 1,
              cards: [
                samplePreviewCard(
                  id: 'month-card-1',
                  submittedAt: DateTime(2026, 5, 5, 9, 0),
                ),
              ],
            ),
            sampleMonthSummaryDay(
              coupleDate: DateTime(2026, 5, 6),
              cardCount: 2,
              cards: [
                samplePreviewCard(
                  id: 'month-card-2',
                  submittedAt: DateTime(2026, 5, 6, 9, 20),
                ),
                samplePreviewCard(
                  id: 'month-card-3',
                  authorUserId: 'user-b',
                  previewPath: 'previews/card-3.png',
                  submittedAt: DateTime(2026, 5, 6, 9, 0),
                ),
              ],
            ),
          ],
        },
      );

      await _pumpCalendar(
        tester,
        repository: repository,
        calendarEvents: [
          _calendarEvent(
            id: 'stacked-day-event-without-artwork',
            title: 'plain event',
            date: DateTime(2026, 5, 6),
          ),
        ],
      );

      expect(
        find.byKey(
          const ValueKey('calendar-month-story-cell-single-2026-05-05'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('calendar-month-story-cell-stacked-2026-05-06'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('calendar-month-story-cell-empty-2026-05-07'),
        ),
        findsOneWidget,
      );
      expect(find.byType(CalendarMonthStoryCell), findsWidgets);

      final singleCardCell = find.byKey(
        const ValueKey('calendar-month-story-cell-single-2026-05-05'),
      );
      final stackedCardCell = find.byKey(
        const ValueKey('calendar-month-story-cell-stacked-2026-05-06'),
      );
      expect(tester.getSize(singleCardCell).width, greaterThanOrEqualTo(36));
      expect(tester.getSize(singleCardCell).height, greaterThanOrEqualTo(48));

      final singleCard = find.byKey(
        const ValueKey('calendar-month-story-card-month-card-1'),
      );
      final firstStackedCard = find.byKey(
        const ValueKey('calendar-month-story-card-month-card-2'),
      );
      final secondStackedCard = find.byKey(
        const ValueKey('calendar-month-story-card-month-card-3'),
      );
      expect(singleCard, findsOneWidget);
      expect(firstStackedCard, findsOneWidget);
      expect(secondStackedCard, findsOneWidget);
      final cardSize = tester.getSize(singleCard);
      expect(tester.getSize(firstStackedCard), cardSize);
      expect(tester.getSize(secondStackedCard), cardSize);
      expect(
        tester.getCenter(firstStackedCard).dy,
        closeTo(tester.getCenter(secondStackedCard).dy, 0.5),
      );
      expect(
        cardSize.width / cardSize.height,
        closeTo(storyCardCanvasAspectRatio, 0.001),
      );

      final dateInkWell = find.ancestor(
        of: singleCardCell,
        matching: find.byType(InkWell),
      );
      expect(dateInkWell, findsOneWidget);
      expect(
        tester.widget<InkWell>(dateInkWell).child,
        isA<CalendarMonthStoryCell>(),
      );
      final singleCardDecorations = _framedDecorations(tester, singleCardCell);
      final stackedCardDecorations = _framedDecorations(
        tester,
        stackedCardCell,
      );
      expect(singleCardDecorations, hasLength(1));
      expect(stackedCardDecorations, hasLength(2));
      for (final decoration in [
        ...singleCardDecorations,
        ...stackedCardDecorations,
      ]) {
        expect(decoration.border, isNull);
        expect(decoration.boxShadow, hasLength(1));
      }

      await tester.drag(
        find.byKey(const Key('calendar-scroll-view')),
        const Offset(0, 1000),
      );
      await tester.pumpAndSettle();

      final expandedSingleSize = tester.getSize(singleCard);
      final expandedStackedSize = tester.getSize(firstStackedCard);
      expect(expandedSingleSize.width, inInclusiveRange(24, 30));
      expect(
        expandedStackedSize.width,
        greaterThan(expandedSingleSize.width * 1.2),
      );
      expect(tester.getSize(secondStackedCard), expandedStackedSize);
      final expandedStackCenterGap =
          tester.getCenter(firstStackedCard).dy -
          tester.getCenter(secondStackedCard).dy;
      expect(
        expandedStackCenterGap,
        greaterThan(expandedStackedSize.height * 0.55),
      );
      expect(
        expandedStackedSize.height + expandedStackCenterGap,
        greaterThan(tester.getSize(stackedCardCell).height * 0.5),
      );
      expect(
        tester.getCenter(singleCard).dx,
        closeTo(tester.getCenter(singleCardCell).dx, 0.5),
      );
    },
  );

  testWidgets(
    'keeps two expanded cards aligned when the date has event artwork',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = FakeStoryLoopReadRepository(
        monthSummaries: {
          DateTime(2026, 5): [
            sampleMonthSummaryDay(
              coupleDate: DateTime(2026, 5, 6),
              cardCount: 2,
              cards: [
                samplePreviewCard(
                  id: 'artwork-day-back-card',
                  submittedAt: DateTime(2026, 5, 6, 9),
                ),
                samplePreviewCard(
                  id: 'artwork-day-front-card',
                  authorUserId: 'user-b',
                  submittedAt: DateTime(2026, 5, 6, 9, 20),
                ),
              ],
            ),
          ],
        },
      );

      await _pumpCalendar(
        tester,
        repository: repository,
        calendarEvents: [
          _calendarEvent(
            id: 'stacked-day-event-with-artwork',
            title: 'artwork event',
            date: DateTime(2026, 5, 6),
            artwork: const CoupleCalendarEventArtwork(
              previewPath: 'event.webp',
              drawingDataPath: 'event.json.gz',
            ),
          ),
        ],
      );
      await tester.drag(
        find.byKey(const Key('calendar-scroll-view')),
        const Offset(0, 1000),
      );
      await tester.pumpAndSettle();

      final backCard = find.byKey(
        const ValueKey('calendar-month-story-card-artwork-day-back-card'),
      );
      final frontCard = find.byKey(
        const ValueKey('calendar-month-story-card-artwork-day-front-card'),
      );
      expect(
        tester.getCenter(backCard).dy,
        closeTo(tester.getCenter(frontCard).dy, 0.5),
      );
    },
  );

  testWidgets('caps expanded calendar cards on a tablet viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 1366);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = FakeStoryLoopReadRepository(
      monthSummaries: {
        DateTime(2026, 5): [
          sampleMonthSummaryDay(
            coupleDate: DateTime(2026, 5, 5),
            cardCount: 1,
            cards: [
              samplePreviewCard(
                id: 'tablet-card',
                submittedAt: DateTime(2026, 5, 5, 9),
              ),
            ],
          ),
          sampleMonthSummaryDay(
            coupleDate: DateTime(2026, 5, 6),
            cardCount: 2,
            cards: [
              samplePreviewCard(
                id: 'tablet-back-card',
                submittedAt: DateTime(2026, 5, 6, 9),
              ),
              samplePreviewCard(
                id: 'tablet-front-card',
                authorUserId: 'user-b',
                submittedAt: DateTime(2026, 5, 6, 9, 20),
              ),
            ],
          ),
        ],
      },
    );

    await _pumpCalendar(tester, repository: repository);
    await tester.drag(
      find.byKey(const Key('calendar-scroll-view')),
      const Offset(0, 1000),
    );
    await tester.pumpAndSettle();

    final card = find.byKey(
      const ValueKey('calendar-month-story-card-tablet-card'),
    );
    final cell = find.byKey(
      const ValueKey('calendar-month-story-cell-single-2026-05-05'),
    );
    final backCard = find.byKey(
      const ValueKey('calendar-month-story-card-tablet-back-card'),
    );
    final frontCard = find.byKey(
      const ValueKey('calendar-month-story-card-tablet-front-card'),
    );
    expect(tester.getSize(card).width, inInclusiveRange(40, 48));
    expect(tester.getCenter(card).dx, closeTo(tester.getCenter(cell).dx, 0.5));
    expect(tester.getSize(backCard).width, lessThanOrEqualTo(48));
    expect(tester.getSize(frontCard), tester.getSize(backCard));
    expect(
      tester.getCenter(frontCard).dy - tester.getCenter(backCard).dy,
      greaterThan(tester.getSize(backCard).height * 0.55),
    );
  });

  testWidgets('fetches selected past date and shows story loop detail', (
    tester,
  ) async {
    final repository = FakeStoryLoopReadRepository(
      details: {DateTime(2026, 5, 5): _completedDetail},
    );
    await _pumpCalendar(
      tester,
      repository: repository,
      aiFeedbacks: {
        'daily-question-id': AiQuestionFeedback(
          dailyQuestionId: 'daily-question-id',
          feedbackText: '둘 다 소중한 대상을 바로 떠올렸네',
          publishedAt: DateTime.utc(2026, 5, 5, 12),
        ),
      },
    );

    await tester.tap(find.text('5').first);
    await tester.pumpAndSettle();

    expect(repository.requestedDetailDates, [
      DateTime(2026, 5, 10),
      DateTime(2026, 5, 5),
    ]);
    expect(find.text('5월 5일'), findsOneWidget);
    expect(find.text('2026 · 화요일'), findsOneWidget);
    final cardStack = find.byType(CalendarStoryCardStack);
    expect(cardStack, findsOneWidget);
    expect(
      find.descendant(
        of: cardStack,
        matching: find.byType(StoryCardPreviewSurface),
      ),
      findsNWidgets(2),
    );
    expect(_framedDecorations(tester, cardStack), hasLength(2));
    final myCard = find.byKey(const ValueKey('calendar-story-card-card-2'));
    final partnerCard = find.byKey(
      const ValueKey('calendar-story-card-card-1'),
    );
    expect(myCard, findsOneWidget);
    expect(partnerCard, findsOneWidget);
    final myCardRect = tester.getRect(myCard);
    final partnerCardRect = tester.getRect(partnerCard);
    expect(myCardRect.right, lessThanOrEqualTo(partnerCardRect.left));
    expect(myCardRect.top, partnerCardRect.top);
    expect(
      find.descendant(of: cardStack, matching: find.byType(Transform)),
      findsNothing,
    );
    expect(find.byIcon(Icons.image_outlined), findsNothing);
    expect(find.byIcon(Icons.brush_outlined), findsNothing);
    expect(find.byIcon(Icons.text_fields), findsNothing);
    expect(
      _circularDecorations(
        tester,
        find.byKey(
          const ValueKey('calendar-month-story-cell-empty-2026-05-05'),
        ),
      ).map((decoration) => decoration.color),
      contains(AppColors.actionPrimary),
    );
    expect(find.text('history question'), findsOneWidget);
    expect(find.byKey(const Key('question-detail-title')), findsOneWidget);
    expect(find.byType(QuestionAnswerPromptRow), findsNothing);
    expect(find.byType(QuestionAnswerOverview), findsOneWidget);
    expect(find.text('my answer'), findsOneWidget);
    expect(find.text('partner answer'), findsOneWidget);
    expect(find.text('종합'), findsNothing);
    expect(find.text('AI의 한마디'), findsNothing);
    expect(
      find.byKey(const Key('ai-question-feedback-character')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('ai-question-feedback-prompt')),
      findsOneWidget,
    );
    expect(findTextIgnoringWordJoiners('둘 다 소중한 대상을 바로 떠올렸네'), findsOneWidget);
    expect(find.text('그 날의 표현 횟수'), findsNothing);
  });

  testWidgets('opens a selected history card in the shared detail overlay', (
    tester,
  ) async {
    final repository = FakeStoryLoopReadRepository(
      details: {DateTime(2026, 5, 5): _completedDetail},
    );
    await _pumpCalendar(tester, repository: repository);

    await tester.tap(find.text('5').first);
    await tester.pumpAndSettle();
    final card = find.byKey(const ValueKey('calendar-story-card-card-2'));
    await _scrollCalendarUp(tester);
    await tester.tap(card);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('story-card-detail-overlay')), findsOneWidget);
    expect(find.byKey(const Key('story-card-detail-card-2')), findsOneWidget);
  });

  testWidgets('shows card only detail when question has not been generated', (
    tester,
  ) async {
    final repository = FakeStoryLoopReadRepository(
      details: {DateTime(2026, 5, 5): _cardOnlyDetail},
    );

    await _pumpCalendar(tester, repository: repository);

    await tester.tap(find.text('5').first);
    await tester.pumpAndSettle();

    expect(repository.requestedDetailDates, [
      DateTime(2026, 5, 10),
      DateTime(2026, 5, 5),
    ]);
    expect(find.byType(CalendarStoryCardStack), findsOneWidget);
    expect(find.text('스토리 카드가 먼저 도착했어요'), findsOneWidget);
    expect(find.text('두 사람의 카드가 모두 올라오면 질문이 생성돼요'), findsOneWidget);
    expect(find.text('history question'), findsNothing);
    expect(find.text('09:00'), findsNothing);
  });

  testWidgets('shows a distinct message while an AI question is preparing', (
    tester,
  ) async {
    final repository = FakeStoryLoopReadRepository(
      details: {
        DateTime(2026, 5, 5): _twoCardDetail(StoryLoopStatus.questionPreparing),
      },
    );

    await _pumpCalendar(tester, repository: repository);
    await tester.tap(find.text('5').first);
    await tester.pumpAndSettle();

    expect(find.text('둘의 카드가 모두 모였어요'), findsOneWidget);
    expect(find.text('둘에게 어울릴 질문을 고르고 있어요'), findsOneWidget);
  });

  testWidgets('does not promise a question for a card-only date', (
    tester,
  ) async {
    final repository = FakeStoryLoopReadRepository(
      details: {
        DateTime(2026, 5, 5): _twoCardDetail(StoryLoopStatus.cardOnlyCompleted),
      },
    );

    await _pumpCalendar(tester, repository: repository);
    await tester.tap(find.text('5').first);
    await tester.pumpAndSettle();

    expect(find.text('이 날은 카드만 남겼어요'), findsOneWidget);
    expect(find.text('두 사람이 남긴 카드를 그대로 간직할 수 있어요'), findsOneWidget);
    expect(find.text('질문이 준비되면 이 자리에서 함께 볼 수 있어요'), findsNothing);
  });

  testWidgets('shows empty state when selected date has no loop', (
    tester,
  ) async {
    final repository = FakeStoryLoopReadRepository();
    await _pumpCalendar(tester, repository: repository);

    await tester.tap(find.text('5').first);
    await tester.pumpAndSettle();

    expect(repository.requestedDetailDates, [
      DateTime(2026, 5, 10),
      DateTime(2026, 5, 5),
    ]);
    expect(find.text('이 날의 질문 기록이 없어요'), findsOneWidget);
    expect(find.text('그 날의 표현 횟수'), findsNothing);
  });

  testWidgets('retries selected past date after detail load failure', (
    tester,
  ) async {
    final repository = _FlakyStoryLoopReadRepository(entry: _completedDetail);

    await _pumpCalendar(tester, repository: repository);

    await tester.tap(find.text('5').first);
    await tester.pumpAndSettle();

    expect(repository.requestedDetailDates, [
      DateTime(2026, 5, 10),
      DateTime(2026, 5, 5),
    ]);
    expect(find.text('기록을 불러오지 못했어요'), findsOneWidget);

    await _scrollCalendarUp(tester);
    await tester.tap(find.byKey(const Key('calendar-story-detail-retry')));
    await tester.pumpAndSettle();

    expect(repository.requestedDetailDates, [
      DateTime(2026, 5, 10),
      DateTime(2026, 5, 5),
      DateTime(2026, 5, 5),
    ]);
    expect(find.text('history question'), findsOneWidget);
  });

  testWidgets('uses history hidden copy when my answer is missing', (
    tester,
  ) async {
    final repository = FakeStoryLoopReadRepository(
      details: {DateTime(2026, 5, 5): _partnerOnlyDetail},
    );

    await _pumpCalendar(tester, repository: repository);

    await tester.tap(find.text('5').first);
    await tester.pumpAndSettle();

    expect(find.text('내 답변이 없어 상대방 답변을 확인할 수 없어요'), findsOneWidget);
    expect(find.text('partner answer'), findsNothing);
    expect(find.text('AI 한 줄 평'), findsNothing);
    expect(find.text('아직 AI 한 줄 평이 없어요'), findsNothing);
  });

  testWidgets('selects today without leaving calendar', (tester) async {
    final repository = FakeStoryLoopReadRepository(
      details: {DateTime(2026, 5, 10): _todayPendingDetail},
    );

    await _pumpCalendar(tester, repository: repository);

    await tester.tap(find.text('10'));
    await tester.pumpAndSettle();

    expect(repository.requestedDetailDates, [DateTime(2026, 5, 10)]);
    expect(find.text('calendar question route'), findsNothing);
    expect(find.text('today history question'), findsOneWidget);
  });

  testWidgets('opens edit flow for today when my answer is missing', (
    tester,
  ) async {
    final repository = FakeStoryLoopReadRepository(
      details: {DateTime(2026, 5, 10): _todayPendingDetail},
    );

    await _pumpCalendar(tester, repository: repository);

    await tester.tap(find.text('10'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('내 답변'));
    await _scrollCalendarUp(tester);
    await tester.tap(find.text('내 답변'));
    await tester.pumpAndSettle();

    expect(find.text('calendar question edit route'), findsOneWidget);
  });
}

List<BoxDecoration> _framedDecorations(WidgetTester tester, Finder scope) {
  return tester
      .widgetList<DecoratedBox>(
        find.descendant(of: scope, matching: find.byType(DecoratedBox)),
      )
      .map((widget) => widget.decoration)
      .whereType<BoxDecoration>()
      .where(
        (decoration) =>
            decoration.border != null ||
            (decoration.boxShadow?.isNotEmpty ?? false),
      )
      .toList(growable: false);
}

List<BoxDecoration> _circularDecorations(WidgetTester tester, Finder scope) {
  return tester
      .widgetList<DecoratedBox>(
        find.descendant(of: scope, matching: find.byType(DecoratedBox)),
      )
      .map((widget) => widget.decoration)
      .whereType<BoxDecoration>()
      .where((decoration) => decoration.shape == BoxShape.circle)
      .toList(growable: false);
}

Future<void> _pumpCalendar(
  WidgetTester tester, {
  required StoryLoopReadRepository repository,
  DateTime? today,
  DateTime? relationshipStartDate,
  DateTime? initialDate,
  Map<String, AiQuestionFeedback> aiFeedbacks = const {},
  List<CoupleCalendarEvent> calendarEvents = const [],
  double textScaleFactor = 1,
}) async {
  final calendarEventRepository = _FakeCalendarEventRepository(
    events: calendarEvents,
  );
  final router = GoRouter(
    initialLocation: '/calendar',
    routes: [
      GoRoute(
        path: '/calendar',
        builder: (context, state) =>
            Scaffold(body: CalendarScreen(initialDate: initialDate)),
      ),
      GoRoute(
        path: '/calendar/question',
        builder: (context, state) =>
            const Scaffold(body: Text('calendar question route')),
      ),
      GoRoute(
        path: '/home/question/edit',
        builder: (context, state) =>
            const Scaffold(body: Text('calendar question edit route')),
      ),
      GoRoute(
        path: '/calendar/event/new',
        builder: (context, state) => Scaffold(
          body: Text(
            'calendar event date ${state.uri.queryParameters['date']}',
          ),
        ),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        todayControllerProvider.overrideWithBuild(
          (ref, notifier) => today ?? DateTime(2026, 5, 10),
        ),
        coupleControllerProvider.overrideWithBuild(
          (ref, notifier) async => _activeCouple(
            relationshipStartDate: relationshipStartDate,
            currentDate: today ?? DateTime(2026, 5, 10),
          ),
        ),
        profileControllerProvider.overrideWithBuild(
          (ref, notifier) async => _profile,
        ),
        aiQuestionFeedbackProvider.overrideWith((ref, dailyQuestionId) {
          final feedback = aiFeedbacks[dailyQuestionId];
          return Stream.value(
            feedback == null
                ? const AiQuestionFeedbackDisabled()
                : AiQuestionFeedbackPublished(feedback),
          );
        }),
        storyLoopReadRepositoryProvider.overrideWithValue(repository),
        coupleCalendarEventRepositoryProvider.overrideWithValue(
          calendarEventRepository,
        ),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScaleFactor)),
          child: child!,
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();
}

Future<void> _scrollCalendarUp(WidgetTester tester) async {
  await tester.drag(
    find.byKey(const Key('calendar-scroll-view')),
    const Offset(0, -600),
  );
  await tester.pumpAndSettle();
}

class _FakeCalendarEventRepository implements CoupleCalendarEventRepository {
  _FakeCalendarEventRepository({required List<CoupleCalendarEvent> events})
    : events = List.of(events);

  final List<CoupleCalendarEvent> events;

  @override
  Future<void> deleteEvent({
    required String eventId,
    required int expectedRevision,
  }) async {
    events.removeWhere((event) => event.id == eventId);
  }

  @override
  Future<CoupleCalendarEvent?> fetchEvent(String eventId) async {
    return events.where((event) => event.id == eventId).firstOrNull;
  }

  @override
  Future<Uint8List> fetchArtworkDrawingData(String drawingDataPath) async {
    return Uint8List(0);
  }

  @override
  Future<List<CoupleCalendarEvent>> fetchOccurrences({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    return events
        .where(
          (event) =>
              !event.occurrenceDate.isBefore(startDate) &&
              !event.occurrenceDate.isAfter(endDate),
        )
        .toList(growable: false);
  }

  @override
  Future<CoupleCalendarEvent> saveEvent({
    required String coupleId,
    required CoupleCalendarEventSaveRequest request,
    Uint8List? previewBytes,
    Uint8List? drawingDataBytes,
  }) {
    throw UnimplementedError();
  }
}

CoupleCalendarEvent _calendarEvent({
  required String id,
  required String title,
  required DateTime date,
  CoupleCalendarEventArtwork? artwork,
}) {
  return CoupleCalendarEvent(
    id: id,
    coupleId: 'couple-id',
    title: title,
    eventDate: date,
    occurrenceDate: date,
    repeatRule: CoupleCalendarEventRepeatRule.none,
    memo: null,
    revision: 1,
    createdByUserId: 'user-id',
    updatedByUserId: 'user-id',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    reminder: const CoupleCalendarEventReminder.disabled(),
    artwork: artwork,
  );
}

class _FlakyStoryLoopReadRepository implements StoryLoopReadRepository {
  _FlakyStoryLoopReadRepository({required this.entry});

  final StoryLoopDetail entry;
  final requestedDetailDates = <DateTime>[];
  var _shouldFail = true;

  @override
  Future<StoryLoopDetail?> fetchDetail(DateTime date) async {
    final normalizedDate = calendarDateOnly(date);
    requestedDetailDates.add(normalizedDate);

    if (normalizedDate != calendarDateOnly(entry.coupleDate)) {
      return null;
    }

    if (_shouldFail) {
      _shouldFail = false;
      throw Exception('detail unavailable');
    }

    return entry;
  }

  @override
  Future<List<StoryLoopMonthSummaryDay>> fetchMonthSummary(
    DateTime month,
  ) async {
    return const [];
  }

  @override
  Future<TodayStoryLoopSummary?> fetchTodaySummary() async {
    return null;
  }
}

Couple _activeCouple({DateTime? relationshipStartDate, DateTime? currentDate}) {
  return activeCouple(
    relationshipStartDate: relationshipStartDate ?? DateTime(2026, 5, 1),
    currentDate: currentDate ?? DateTime(2026, 5, 10),
  );
}

final _historyQuestion = DailyQuestion(
  dailyQuestionId: 'daily-question-id',
  coupleId: 'couple-id',
  questionId: 'question-id',
  questionText: 'history question',
  questionSource: QuestionSource.curated,
  questionCategory: 'daily',
  questionMood: 'warm',
  assignedDate: DateTime(2026, 5, 5),
  status: DailyQuestionStatus.completed,
);

final _profile = UserProfile(
  id: 'user-b',
  displayName: 'current user',
  birthDate: DateTime(2000),
  onboardingCompletedAt: DateTime(2026),
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

final _completedDetail = sampleStoryLoopDetail(
  coupleDate: DateTime(2026, 5, 5),
  loopStatus: StoryLoopStatus.completed,
  canEditStory: false,
  canAnswerQuestion: false,
  cards: [
    sampleDetailCard(id: 'card-1', submittedAt: DateTime(2026, 5, 5, 9, 0)),
    sampleDetailCard(
      id: 'card-2',
      authorUserId: 'user-b',
      previewPath: 'previews/card-2.png',
      sceneDataPath: 'scenes/card-2.json',
      submittedAt: DateTime(2026, 5, 5, 9, 10),
    ),
  ],
  question: StoryLoopQuestionDetail(
    question: _historyQuestion,
    answerState: const DailyQuestionAnswerState(
      dailyQuestionId: 'daily-question-id',
      status: DailyQuestionStatus.completed,
      myAnswerId: 'my-answer-id',
      myAnswerText: 'my answer',
      partnerAnswerExists: true,
      partnerAnswerId: 'partner-answer-id',
      partnerAnswerText: 'partner answer',
      answerCount: 2,
    ),
  ),
);

final _cardOnlyDetail = StoryLoopDetail(
  coupleId: 'couple-id',
  coupleDate: DateTime(2026, 5, 5),
  accessMode: CoupleAccessMode.active,
  loopId: 'loop-id',
  loopStatus: StoryLoopStatus.waitingPartnerCard,
  storyEditLocked: false,
  canEditStory: false,
  canAnswerQuestion: false,
  cardCount: 1,
  cards: [
    sampleDetailCard(id: 'card-1', submittedAt: DateTime(2026, 5, 5, 9, 0)),
  ],
  question: null,
);

StoryLoopDetail _twoCardDetail(StoryLoopStatus status) {
  return StoryLoopDetail(
    coupleId: 'couple-id',
    coupleDate: DateTime(2026, 5, 5),
    accessMode: CoupleAccessMode.active,
    loopId: 'loop-id',
    loopStatus: status,
    storyEditLocked: true,
    canEditStory: false,
    canAnswerQuestion: false,
    cardCount: 2,
    cards: [
      sampleDetailCard(id: 'card-1', submittedAt: DateTime(2026, 5, 5, 9)),
      sampleDetailCard(
        id: 'card-2',
        authorUserId: 'partner-id',
        submittedAt: DateTime(2026, 5, 5, 9, 10),
      ),
    ],
    question: null,
  );
}

final _partnerOnlyDetail = sampleStoryLoopDetail(
  coupleDate: DateTime(2026, 5, 5),
  loopStatus: StoryLoopStatus.answeredByOne,
  canEditStory: false,
  canAnswerQuestion: false,
  question: StoryLoopQuestionDetail(
    question: _historyQuestion,
    answerState: const DailyQuestionAnswerState(
      dailyQuestionId: 'daily-question-id',
      status: DailyQuestionStatus.answeredByOne,
      partnerAnswerExists: true,
      answerCount: 1,
    ),
  ),
);

final _todayPendingDetail = sampleStoryLoopDetail(
  coupleDate: DateTime(2026, 5, 10),
  loopStatus: StoryLoopStatus.questionGenerated,
  canEditStory: false,
  canAnswerQuestion: true,
  question: StoryLoopQuestionDetail(
    question: DailyQuestion(
      dailyQuestionId: 'today-daily-question-id',
      coupleId: 'couple-id',
      questionId: 'today-question-id',
      questionText: 'today history question',
      questionSource: QuestionSource.curated,
      questionCategory: 'daily',
      questionMood: 'warm',
      assignedDate: DateTime(2026, 5, 10),
      status: DailyQuestionStatus.pending,
    ),
    answerState: const DailyQuestionAnswerState(
      dailyQuestionId: 'today-daily-question-id',
      status: DailyQuestionStatus.pending,
      partnerAnswerExists: false,
      answerCount: 0,
    ),
  ),
);
